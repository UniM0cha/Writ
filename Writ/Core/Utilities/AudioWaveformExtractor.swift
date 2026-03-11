import AVFoundation

enum AudioWaveformExtractor {
    /// 오디오 파일에서 파형 데이터 추출 (0.0~1.0 범위의 Float 배열)
    static func extractWaveform(from url: URL, barCount: Int) async -> [Float] {
        guard barCount > 0 else { return [] }

        do {
            let audioFile = try AVAudioFile(forReading: url)
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard frameCount > 0 else { return [] }

            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: audioFile.fileFormat.sampleRate,
                channels: 1,
                interleaved: false
            ) else { return [] }

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return []
            }
            try audioFile.read(into: buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return [] }
            let totalSamples = Int(buffer.frameLength)

            let samplesPerBar = totalSamples / barCount
            guard samplesPerBar > 0 else { return [] }

            // 각 구간의 RMS 계산
            var rmsValues: [Float] = []
            rmsValues.reserveCapacity(barCount)

            for i in 0..<barCount {
                let start = i * samplesPerBar
                let end = min(start + samplesPerBar, totalSamples)

                var sumSquares: Float = 0
                for j in start..<end {
                    let sample = channelData[j]
                    sumSquares += sample * sample
                }
                let rms = sqrtf(sumSquares / Float(end - start))
                rmsValues.append(rms)
            }

            // 정규화
            let maxRMS = rmsValues.max() ?? 1.0
            guard maxRMS > 0 else { return Array(repeating: 0, count: barCount) }

            return rmsValues.map { value in
                let normalized = value / maxRMS
                // power curve로 작은 소리도 가시적으로
                return powf(normalized, 0.5)
            }
        } catch {
            return []
        }
    }
}
