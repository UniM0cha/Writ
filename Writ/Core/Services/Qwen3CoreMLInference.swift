#if os(iOS) || os(macOS)
import CoreML
import Foundation
import Accelerate
import os
import Qwen3ASR
import AudioCommon

private let logger = Logger(subsystem: AppGroupConstants.logSubsystem, category: "Qwen3CoreML")

/// GPU-free Qwen3-ASR CoreML 전사.
/// iOS: MLX를 사용하지 않아 백그라운드에서도 Metal 크래시 없이 동작.
/// macOS: GPU를 활용하여 인코더/디코더 모두 빠르게 실행.
final class Qwen3CoreMLInference {

    // MARK: - Properties

    private let encoderModel: MLModel
    private let decoder: CoreMLTextDecoder
    private var tokenizer: Qwen3Tokenizer?

    // WhisperFeatureExtractor 매개변수 (MLX 의존 회피를 위해 상수로 정의)
    private let sampleRate = 16000
    private let nMels = 128
    private let nFFT = 400
    private let hopLength = 160

    /// 인코더 입력에 사용할 열거형 mel 길이 (EnumeratedShapes)
    private let enumeratedMelLengths = [100, 200, 400, 600, 800, 1000, 1500, 2000, 3000]

    init(encoderModel: MLModel, decoder: CoreMLTextDecoder) {
        self.encoderModel = encoderModel
        self.decoder = decoder
    }

    // MARK: - Compute Unit Selection

    /// 인코더 최적 compute unit.
    /// - macOS: GPU가 안정적이고 ANE 컴파일 오버헤드 없음
    /// - iOS: ANE가 병렬 연산에 적합, 백그라운드에서 GPU 사용 불가
    static func encoderComputeUnits() -> MLComputeUnits {
        #if os(macOS)
        .cpuAndGPU
        #else
        .cpuAndNeuralEngine
        #endif
    }

    /// 디코더 최적 compute unit.
    /// - macOS: GPU가 순차 디코딩에서 ANE보다 10배 빠름
    /// - iOS: MLState KV 캐시가 ANE 미호환 + 백그라운드에서 GPU 사용 불가
    static func decoderComputeUnits() -> MLComputeUnits {
        #if os(macOS)
        .cpuAndGPU
        #else
        .cpuOnly
        #endif
    }

    // MARK: - Model Loading

    /// HuggingFace에서 모델 다운로드 + 로드.
    static func fromPretrained(
        modelId: String = "aufklarer/Qwen3-ASR-CoreML",
        tokenizerModelId: String = "aufklarer/Qwen3-ASR-0.6B-MLX-4bit",
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> Qwen3CoreMLInference {
        let cacheDir = try HuggingFaceDownloader.getCacheDirectory(for: modelId)

        // 모델 파일 다운로드
        progressHandler?(0.0, "모델 다운로드 중")
        try await HuggingFaceDownloader.downloadWeights(
            modelId: modelId,
            to: cacheDir,
            additionalFiles: [
                "encoder.mlmodelc/**",
                "embedding.mlmodelc/**",
                "decoder.mlmodelc/**",
                "config.json"
            ]
        ) { fraction in
            progressHandler?(fraction * 0.5, "모델 다운로드 중")
        }

        progressHandler?(0.5, "인코더 로드 중")

        // 인코더: 플랫폼 최적 compute unit 시도 → CPU 폴백
        let encoderURL = cacheDir.appendingPathComponent("encoder.mlmodelc", isDirectory: true)
        let encoderModel: MLModel
        let encUnits = encoderComputeUnits()
        do {
            let config = MLModelConfiguration()
            config.computeUnits = encUnits
            encoderModel = try await MLModel.load(contentsOf: encoderURL, configuration: config)
        } catch {
            logger.warning("인코더 로드 실패, CPU 폴백: \(error)")
            let config = MLModelConfiguration()
            config.computeUnits = .cpuOnly
            encoderModel = try await MLModel.load(contentsOf: encoderURL, configuration: config)
        }

        progressHandler?(0.65, "디코더 로드 중")

        // 디코더: 플랫폼 최적 compute unit 시도 → CPU 폴백
        // iOS: .cpuOnly (MLState KV 캐시 ANE 미호환 + 백그라운드 GPU 불가)
        // macOS: .cpuAndGPU (GPU가 순차 디코딩에서 10배 빠름)
        let decoder: CoreMLTextDecoder
        do {
            decoder = try CoreMLTextDecoder.load(from: cacheDir, computeUnits: decoderComputeUnits())
        } catch {
            logger.warning("디코더 로드 실패, CPU 폴백: \(error)")
            decoder = try CoreMLTextDecoder.load(from: cacheDir, computeUnits: .cpuOnly)
        }

        progressHandler?(0.8, "토크나이저 로드 중")

        // 토크나이저 다운로드 (vocab.json은 MLX 모델 디렉토리에 있음)
        let tokenizerDir = try HuggingFaceDownloader.getCacheDirectory(for: tokenizerModelId)
        try await HuggingFaceDownloader.downloadWeights(
            modelId: tokenizerModelId,
            to: tokenizerDir,
            additionalFiles: ["vocab.json", "merges.txt", "tokenizer_config.json"]
        )

        let inference = Qwen3CoreMLInference(encoderModel: encoderModel, decoder: decoder)

        let vocabPath = tokenizerDir.appendingPathComponent("vocab.json")
        if FileManager.default.fileExists(atPath: vocabPath.path) {
            let tokenizer = Qwen3Tokenizer()
            try tokenizer.load(from: vocabPath)
            inference.tokenizer = tokenizer
        }

        progressHandler?(0.9, "모델 최적화 중")
        try inference.warmUp()

        progressHandler?(1.0, "준비 완료")
        return inference
    }

    /// 인코더 + 디코더 워밍업
    func warmUp() throws {
        // 인코더 워밍업
        let minT = enumeratedMelLengths.first ?? 100
        let dummy = try MLMultiArray(shape: [1, 128, minT as NSNumber], dataType: .float32)
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "mel": MLFeatureValue(multiArray: dummy),
        ])
        _ = try encoderModel.prediction(from: input)

        // 디코더 워밍업
        try decoder.warmUp()
    }

    // MARK: - Transcription

    /// 오디오를 텍스트로 전사. MLX/Metal을 일절 사용하지 않음.
    func transcribe(
        audio: [Float],
        sampleRate: Int = 16000,
        language: String? = nil,
        maxTokens: Int = 448
    ) throws -> String {

        // 1. Mel 추출 (Accelerate CPU) → MLMultiArray로 직접 변환
        let (melArray, _) = try extractMelAsMLMultiArray(audio: audio, sampleRate: sampleRate)

        // 2. 인코더 추론 (CoreML — ANE/CPU)
        let audioEmbeddings = try encodeAudio(mel: melArray)
        let numAudioTokens = audioEmbeddings.shape[1].intValue

        // 3. 디코더 KV 캐시 리셋
        decoder.resetCache()

        // 4. 토큰 시퀀스 구성
        let imStartId: Int32 = 151644
        let imEndId: Int32 = 151645
        let audioStartId: Int32 = 151669
        let audioEndId: Int32 = 151670
        let asrTextId: Int32 = 151704
        let newlineId: Int32 = 198
        let systemId: Int32 = 8948
        let userId: Int32 = 872
        let assistantId: Int32 = 77091

        var prefixTokens: [Int32] = [imStartId, systemId, newlineId, imEndId, newlineId]
        prefixTokens += [imStartId, userId, newlineId, audioStartId]

        var suffixTokens: [Int32] = [audioEndId, imEndId, newlineId, imStartId, assistantId, newlineId]

        if let lang = language, let tokenizer = tokenizer {
            let langPrefix = "language \(lang)"
            let langTokens = tokenizer.encode(langPrefix)
            suffixTokens += langTokens.map { Int32($0) }
        }
        suffixTokens.append(asrTextId)

        // 5. Prefill — prefix 토큰
        var lastLogits: MLMultiArray?
        for token in prefixTokens {
            let embedding = try decoder.embed(tokenId: token)
            lastLogits = try decoder.decoderStep(embedding: embedding)
        }

        // 6. Prefill — 오디오 임베딩 (MLMultiArray에서 직접 슬라이스)
        let hiddenSize = audioEmbeddings.shape[2].intValue
        for i in 0..<numAudioTokens {
            let audioEmbed = try audioEmbeddingSlice(from: audioEmbeddings, at: i, hiddenSize: hiddenSize)
            lastLogits = try decoder.decoderStep(embedding: audioEmbed)
        }

        // 7. Prefill — suffix 토큰
        for token in suffixTokens {
            let embedding = try decoder.embed(tokenId: token)
            lastLogits = try decoder.decoderStep(embedding: embedding)
        }

        // 8. 자기회귀 생성
        guard var logits = lastLogits else {
            return ""
        }

        var generatedTokens: [Int32] = []
        var nextToken = decoder.argmax(logits: logits)
        generatedTokens.append(nextToken)

        for _ in 1..<maxTokens {
            if nextToken == imEndId { break }
            let embedding = try decoder.embed(tokenId: nextToken)
            logits = try decoder.decoderStep(embedding: embedding)
            nextToken = decoder.argmax(logits: logits)
            generatedTokens.append(nextToken)
        }

        // 9. 토큰 디코딩
        if let tokenizer = tokenizer {
            let rawText = tokenizer.decode(tokens: generatedTokens.map { Int($0) })
            if let range = rawText.range(of: "<asr_text>") {
                return String(rawText[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            return rawText
        } else {
            return generatedTokens.map { String($0) }.joined(separator: " ")
        }
    }

    // MARK: - Private: Mel Extraction (GPU-free)

    /// WhisperFeatureExtractor의 extractFeatures() 결과를 MLXArray 없이 MLMultiArray로 변환.
    /// 내부적으로 featureExtractor의 Accelerate 기반 FFT/mel 추출은 CPU에서 실행.
    /// 마지막 MLXArray 래핑(301-302행) 대신 직접 transpose하여 MLMultiArray로 생성.
    private func extractMelAsMLMultiArray(
        audio: [Float],
        sampleRate inputSampleRate: Int = 16000
    ) throws -> (MLMultiArray, Int) {
        var processedAudio = audio
        if inputSampleRate != sampleRate {
            processedAudio = AudioFileLoader.resample(audio, from: inputSampleRate, to: sampleRate)
        }

        let melResult = extractMelSpectrogram(processedAudio)
        let frames = melResult.count / nMels

        // 인코더 EnumeratedShapes에 맞는 targetLength 선택
        guard let targetLength = enumeratedMelLengths.first(where: { $0 >= frames }) else {
            throw NSError(domain: "Qwen3CoreML", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "오디오가 너무 깁니다: \(frames) 프레임"])
        }

        // MLMultiArray [1, nMels, targetLength] 생성 (transpose + padding)
        let melArray = try MLMultiArray(
            shape: [1, nMels as NSNumber, targetLength as NSNumber],
            dataType: .float32
        )
        let ptr = melArray.dataPointer.assumingMemoryBound(to: Float.self)

        // melResult: [frames, nMels] → transpose to [nMels, targetLength]
        for bin in 0..<nMels {
            let dstOffset = bin * targetLength
            for t in 0..<frames {
                ptr[dstOffset + t] = melResult[t * nMels + bin]
            }
            // 나머지 zero-pad
            for t in frames..<targetLength {
                ptr[dstOffset + t] = 0
            }
        }

        return (melArray, frames)
    }

    /// Accelerate 기반 mel spectrogram 추출 (WhisperFeatureExtractor.extractFeatures 로직 재구현).
    /// 반환: [Float] shape [frames, nMels], MLXArray 미사용.
    private func extractMelSpectrogram(_ audio: [Float]) -> [Float] {
        let paddedFFT = 512  // nFFT=400을 power-of-2로
        let nBins = paddedFFT / 2 + 1  // 257
        let halfPadded = paddedFFT / 2  // 256
        let log2PaddedFFT = vDSP_Length(log2(Double(paddedFFT)))

        // FFT 설정
        guard let fftSetup = vDSP_create_fftsetup(log2PaddedFFT, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // 주기적(periodic) Hann 윈도우 — 원본과 동일 (vDSP_HANN_NORM은 대칭이라 다름)
        var hannWindow = [Float](repeating: 0, count: nFFT)
        for i in 0..<nFFT {
            hannWindow[i] = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(nFFT)))
        }

        // Mel filterbank 생성
        let melFilterbank = buildMelFilterbank(nMels: nMels, nBins: nBins, sampleRate: sampleRate, nFFT: paddedFFT)

        // Reflect padding
        let padLength = nFFT / 2
        var paddedAudio = [Float](repeating: 0, count: padLength + audio.count + padLength)
        for i in 0..<padLength {
            let srcIdx = min(padLength - i, audio.count - 1)
            paddedAudio[i] = audio[max(0, srcIdx)]
        }
        for i in 0..<audio.count {
            paddedAudio[padLength + i] = audio[i]
        }
        for i in 0..<padLength {
            let srcIdx = audio.count - 2 - i
            paddedAudio[padLength + audio.count + i] = audio[max(0, srcIdx)]
        }

        let nFrames = (paddedAudio.count - nFFT) / hopLength + 1

        // STFT
        var splitReal = [Float](repeating: 0, count: halfPadded)
        var splitImag = [Float](repeating: 0, count: halfPadded)
        var paddedFrame = [Float](repeating: 0, count: paddedFFT)
        var magnitude = [Float](repeating: 0, count: nFrames * nBins)

        for frame in 0..<nFrames {
            let start = frame * hopLength
            paddedAudio.withUnsafeBufferPointer { buf in
                vDSP_vmul(buf.baseAddress! + start, 1, hannWindow, 1, &paddedFrame, 1, vDSP_Length(nFFT))
            }
            for i in nFFT..<paddedFFT { paddedFrame[i] = 0 }

            for i in 0..<halfPadded {
                splitReal[i] = paddedFrame[2 * i]
                splitImag[i] = paddedFrame[2 * i + 1]
            }

            splitReal.withUnsafeMutableBufferPointer { realBuf in
                splitImag.withUnsafeMutableBufferPointer { imagBuf in
                    var splitComplex = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2PaddedFFT, FFTDirection(kFFTDirection_Forward))
                }
            }

            let baseIdx = frame * nBins
            magnitude[baseIdx] = splitReal[0] * splitReal[0]
            magnitude[baseIdx + halfPadded] = splitImag[0] * splitImag[0]
            for k in 1..<halfPadded {
                magnitude[baseIdx + k] = splitReal[k] * splitReal[k] + splitImag[k] * splitImag[k]
            }
        }

        // Mel filterbank 적용
        // melFilterbank: [nMels, nBins] → filterbankT: [nBins, nMels]로 transpose
        var melSpec = [Float](repeating: 0, count: nFrames * nMels)
        var filterbankT = [Float](repeating: 0, count: nBins * nMels)
        vDSP_mtrans(melFilterbank, 1, &filterbankT, 1, vDSP_Length(nBins), vDSP_Length(nMels))
        // C[nFrames, nMels] = A[nFrames, nBins] * B[nBins, nMels]
        vDSP_mmul(magnitude, 1, filterbankT, 1, &melSpec, 1,
                  vDSP_Length(nFrames), vDSP_Length(nMels), vDSP_Length(nBins))

        // Log + normalization
        let count = melSpec.count
        var countN = Int32(count)
        var epsilon: Float = 1e-10
        vDSP_vclip(melSpec, 1, &epsilon, [Float.greatestFiniteMagnitude], &melSpec, 1, vDSP_Length(count))
        vvlog10f(&melSpec, melSpec, &countN)

        var maxVal: Float = -Float.infinity
        vDSP_maxv(melSpec, 1, &maxVal, vDSP_Length(count))
        var minClamp = maxVal - 8.0
        var maxClamp = Float.greatestFiniteMagnitude
        vDSP_vclip(melSpec, 1, &minClamp, &maxClamp, &melSpec, 1, vDSP_Length(count))

        var scale: Float = 0.25
        var offset: Float = 1.0
        vDSP_vsmsa(melSpec, 1, &scale, &offset, &melSpec, 1, vDSP_Length(count))

        // HuggingFace: 마지막 프레임 제거
        let trimmedFrames = nFrames - 1
        let trimmedMelSpec = Array(melSpec.prefix(trimmedFrames * nMels))

        // 최대 길이 제한
        let maxFrames = 1200 * sampleRate / hopLength
        if trimmedFrames > maxFrames {
            return Array(trimmedMelSpec.prefix(maxFrames * nMels))
        }
        return trimmedMelSpec
    }

    /// Mel filterbank 생성 — Slaney mel 스케일 (원본 WhisperFeatureExtractor.setupMelFilterbank과 동일)
    private func buildMelFilterbank(nMels: Int, nBins: Int, sampleRate: Int, nFFT: Int) -> [Float] {
        // Slaney piecewise mel scale (HuggingFace style)
        let minLogHertz: Float = 1000.0
        let minLogMel: Float = 15.0
        let logstepHzToMel: Float = 27.0 / log(6.4)
        let logstepMelToHz: Float = log(6.4) / 27.0

        func hzToMel(_ hz: Float) -> Float {
            hz < minLogHertz ? 3.0 * hz / 200.0 : minLogMel + log(hz / minLogHertz) * logstepHzToMel
        }
        func melToHz(_ mel: Float) -> Float {
            mel < minLogMel ? 200.0 * mel / 3.0 : minLogHertz * exp((mel - minLogMel) * logstepMelToHz)
        }

        let fMin: Float = 0
        let fMax = Float(sampleRate) / 2.0
        let melMin = hzToMel(fMin)
        let melMax = hzToMel(fMax)

        let nMelPoints = nMels + 2
        var melPoints = [Float](repeating: 0, count: nMelPoints)
        for i in 0..<nMelPoints {
            melPoints[i] = melMin + Float(i) * (melMax - melMin) / Float(nMelPoints - 1)
        }
        let filterFreqs = melPoints.map { melToHz($0) }

        var filterDiff = [Float](repeating: 0, count: nMelPoints - 1)
        for i in 0..<(nMelPoints - 1) {
            filterDiff[i] = filterFreqs[i + 1] - filterFreqs[i]
        }

        let fftFreqs = (0..<nBins).map { Float($0) * Float(sampleRate) / Float(nFFT) }

        // filterbank [nBins, nMels] 구성 — 원본과 동일한 레이아웃
        var filterbank = [Float](repeating: 0, count: nBins * nMels)
        for bin in 0..<nBins {
            let fftFreq = fftFreqs[bin]
            for mel in 0..<nMels {
                let downSlope = (fftFreq - filterFreqs[mel]) / filterDiff[mel]
                let upSlope = (filterFreqs[mel + 2] - fftFreq) / filterDiff[mel + 1]
                filterbank[bin * nMels + mel] = max(0.0, min(downSlope, upSlope))
            }
        }

        // Slaney normalization
        for mel in 0..<nMels {
            let enorm = 2.0 / (filterFreqs[mel + 2] - filterFreqs[mel])
            for bin in 0..<nBins {
                filterbank[bin * nMels + mel] *= enorm
            }
        }

        // [nBins, nMels] → [nMels, nBins]로 transpose
        var filterbankTransposed = [Float](repeating: 0, count: nMels * nBins)
        for mel in 0..<nMels {
            for bin in 0..<nBins {
                filterbankTransposed[mel * nBins + bin] = filterbank[bin * nMels + mel]
            }
        }
        return filterbankTransposed
    }

    // MARK: - Private: Encoder (GPU-free)

    /// MLModel 직접 호출로 인코더 추론. MLXArray 미사용.
    private func encodeAudio(mel: MLMultiArray) throws -> MLMultiArray {
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "mel": MLFeatureValue(multiArray: mel),
        ])
        let output = try encoderModel.prediction(from: input)

        guard let embeddings = output.featureValue(for: "audio_embeddings")?.multiArrayValue else {
            throw NSError(domain: "Qwen3CoreML", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "인코더 출력에 audio_embeddings 없음"])
        }
        return embeddings
    }

    // MARK: - Private: Audio Embedding Slice (GPU-free)

    /// MLMultiArray [1, T, hidden]에서 index번째 토큰 [1, 1, hidden] 추출.
    /// MLXArray 슬라이싱 대신 포인터 복사.
    private func audioEmbeddingSlice(
        from embeddings: MLMultiArray,
        at index: Int,
        hiddenSize: Int
    ) throws -> MLMultiArray {
        let result = try MLMultiArray(shape: [1, 1, hiddenSize as NSNumber], dataType: .float32)
        let dstPtr = result.dataPointer.assumingMemoryBound(to: Float.self)

        switch embeddings.dataType {
        case .float16:
            let srcPtr = embeddings.dataPointer.assumingMemoryBound(to: Float16.self)
            let offset = index * hiddenSize
            for i in 0..<hiddenSize {
                dstPtr[i] = Float(srcPtr[offset + i])
            }
        case .float32:
            let srcPtr = embeddings.dataPointer.assumingMemoryBound(to: Float.self)
            let offset = index * hiddenSize
            memcpy(dstPtr, srcPtr.advanced(by: offset), hiddenSize * MemoryLayout<Float>.size)
        default:
            let srcPtr = embeddings.dataPointer.assumingMemoryBound(to: Float.self)
            let offset = index * hiddenSize
            memcpy(dstPtr, srcPtr.advanced(by: offset), hiddenSize * MemoryLayout<Float>.size)
        }

        return result
    }
}
#endif
