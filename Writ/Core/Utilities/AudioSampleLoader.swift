import AVFoundation

/// 오디오 파일을 Float 샘플 배열로 로드하는 유틸리티.
/// Qwen3-ASR은 [Float] 입력이 필요하므로 URL → Float 배열 변환을 수행한다.
enum AudioSampleLoader {
    /// 오디오 파일을 지정된 샘플레이트의 mono Float 배열로 변환
    static func load(url: URL, targetSampleRate: Int = 16000) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(targetSampleRate),
            channels: 1,
            interleaved: false
        )!

        let sourceFormat = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            throw AudioSampleLoaderError.bufferCreationFailed
        }
        try audioFile.read(into: sourceBuffer)

        // 이미 목표 포맷(16kHz mono Float32)이면 직접 반환
        if sourceFormat.sampleRate == Double(targetSampleRate)
            && sourceFormat.channelCount == 1
            && sourceFormat.commonFormat == .pcmFormatFloat32 {
            return Array(UnsafeBufferPointer(
                start: sourceBuffer.floatChannelData![0],
                count: Int(sourceBuffer.frameLength)
            ))
        }

        // 변환 필요: 리샘플링, 채널 변환, 포맷 변환 모두 한 번에 처리
        return try convertBuffer(sourceBuffer, to: targetFormat, originalFrameCount: frameCount, targetSampleRate: targetSampleRate)
    }

    // MARK: - Private

    private static func convertBuffer(
        _ sourceBuffer: AVAudioPCMBuffer,
        to targetFormat: AVAudioFormat,
        originalFrameCount: AVAudioFrameCount,
        targetSampleRate: Int
    ) throws -> [Float] {
        guard let converter = AVAudioConverter(from: sourceBuffer.format, to: targetFormat) else {
            throw AudioSampleLoaderError.converterCreationFailed
        }

        let ratio = Double(targetSampleRate) / sourceBuffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(originalFrameCount) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            throw AudioSampleLoaderError.bufferCreationFailed
        }

        var hasProvidedData = false
        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if hasProvidedData {
                outStatus.pointee = .endOfStream
                return nil
            }
            hasProvidedData = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let conversionError {
            throw AudioSampleLoaderError.conversionFailed(conversionError.localizedDescription)
        }

        return Array(UnsafeBufferPointer(
            start: outputBuffer.floatChannelData![0],
            count: Int(outputBuffer.frameLength)
        ))
    }
}

enum AudioSampleLoaderError: LocalizedError {
    case bufferCreationFailed
    case converterCreationFailed
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed: "오디오 버퍼 생성에 실패했습니다."
        case .converterCreationFailed: "오디오 변환기 생성에 실패했습니다."
        case .conversionFailed(let message): "오디오 변환 실패: \(message)"
        }
    }
}
