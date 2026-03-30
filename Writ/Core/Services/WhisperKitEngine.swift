import Foundation
import os
import WhisperKit

private let logger = Logger(subsystem: AppGroupConstants.logSubsystem, category: "Engine")

/// 모델 로드 단계 (UI 피드백용)
enum ModelLoadPhase: Sendable {
    case optimizing
    case loading
}

/// WhisperKit 기반 전사 엔진 구현체
final class WhisperKitEngine: TranscriptionEngine, @unchecked Sendable {
    private var whisperKit: WhisperKit?
    private var _currentModel: WhisperModelVariant?
    private let lock = NSLock()

    var currentModel: ModelIdentifier? {
        lock.withLock { _currentModel?.modelIdentifier }
    }

    init() {}

    /// 프로토콜 준수용 (phaseCallback 없이 호출)
    func loadModel(
        _ model: ModelIdentifier,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws {
        try await loadModel(model, progressCallback: progressCallback, phaseCallback: nil)
    }

    /// ModelManager 전용: 모델 로드 단계(optimizing/loading) 콜백 포함
    func loadModel(
        _ model: ModelIdentifier,
        progressCallback: (@Sendable (Float) -> Void)?,
        phaseCallback: (@Sendable (ModelLoadPhase) -> Void)?
    ) async throws {
        guard let variant = model.whisperVariant else {
            throw WhisperKitEngineError.modelNotLoaded
        }

        // 1. 다운로드 (이미 로컬에 있으면 스킵됨, 없으면 진행률 콜백 호출)
        let modelURL = try await WhisperKit.download(
            variant: variant.rawValue,
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { progress in
                progressCallback?(Float(progress.fractionCompleted))
            }
        )

        try Task.checkCancellation()

        // 2. 인스턴스 생성 (로드/다운로드 안 함)
        let config = WhisperKitConfig(
            modelFolder: modelURL.path,
            computeOptions: ModelComputeOptions(melCompute: .cpuAndNeuralEngine),
            prewarm: false,
            load: false,
            download: false
        )
        let kit = try await WhisperKit(config)

        try Task.checkCancellation()

        // 3. Prewarm (기기 최적화 — CoreML specialization 캐시 생성)
        phaseCallback?(.optimizing)
        try await kit.prewarmModels()

        try Task.checkCancellation()

        // 4. 모델 로드
        phaseCallback?(.loading)
        try await kit.loadModels()

        lock.withLock {
            self.whisperKit = kit
            self._currentModel = variant
        }
    }

    func unloadModel() async {
        let kit = lock.withLock { () -> WhisperKit? in
            let k = self.whisperKit
            self.whisperKit = nil
            self._currentModel = nil
            return k
        }
        await kit?.unloadModels()
    }

    func transcribe(
        audioURL: URL,
        language: String?,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws -> TranscriptionOutput {
        logger.debug("transcribe: audioURL = \(audioURL.path)")
        logger.debug("transcribe: file exists = \(FileManager.default.fileExists(atPath: audioURL.path))")

        guard let kit = lock.withLock({ self.whisperKit }) else {
            logger.error("transcribe: whisperKit is nil (model not loaded)")
            throw WhisperKitEngineError.modelNotLoaded
        }

        logger.debug("transcribe: calling kit.transcribe()...")
        let options = DecodingOptions(language: language, skipSpecialTokens: true)

        // WhisperKit TranscriptionCallback 연결
        // kit.progress (Foundation Progress)의 fractionCompleted로 0~1 진행률 산출
        var transcriptionCallback: TranscriptionCallback = nil
        if let progressCallback {
            let kitProgress = kit.progress
            transcriptionCallback = { _ -> Bool? in
                let fraction = Float(kitProgress.fractionCompleted)
                progressCallback(fraction)
                return nil // continue
            }
        }

        let results = try await kit.transcribe(
            audioPath: audioURL.path(),
            decodeOptions: options,
            callback: transcriptionCallback
        )
        logger.debug("transcribe: got \(results.count) result(s)")

        guard let result = results.first else {
            logger.error("transcribe: no results returned")
            throw WhisperKitEngineError.noResult
        }

        let segments = result.segments.map { segment in
            SegmentOutput(
                text: stripSpecialTokens(segment.text),
                startTime: TimeInterval(segment.start),
                endTime: TimeInterval(segment.end)
            )
        }

        return TranscriptionOutput(
            text: stripSpecialTokens(result.text),
            segments: segments,
            language: result.language
        )
    }

    func supportedModels() -> [ModelIdentifier] {
        WhisperModelVariant.allCases
            .filter { DeviceCapability.current.supports($0) }
            .map(\.modelIdentifier)
    }

    // MARK: - Private

    /// `<|...|>` 형태의 특수 토큰을 제거한다.
    private func stripSpecialTokens(_ text: String) -> String {
        text.replacing(/<\|[^|]*\|>/, with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

enum WhisperKitEngineError: LocalizedError {
    case modelNotLoaded
    case noResult

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: "모델이 로드되지 않았습니다."
        case .noResult: "전사 결과가 없습니다."
        }
    }
}
