#if os(iOS) || os(macOS)
import Foundation
import os
import CoreML
import AudioCommon

private let logger = Logger(subsystem: AppGroupConstants.logSubsystem, category: "Qwen3ASR")

/// Qwen3-ASR CoreML 기반 전사 엔진. GPU-free — ANE+CPU에서 실행되어 백그라운드 전사 가능.
final class Qwen3ASREngine: TranscriptionEngine, @unchecked Sendable {
    private var inference: Qwen3CoreMLInference?
    private var _currentModel: ModelIdentifier?
    private let lock = NSLock()

    var currentModel: ModelIdentifier? {
        lock.withLock { _currentModel }
    }

    init() {}

    /// 프로토콜 준수용 (statusCallback 없이 호출)
    func loadModel(
        _ model: ModelIdentifier,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws {
        try await loadModel(model, progressCallback: progressCallback, statusCallback: nil)
    }

    /// ModelManager 전용: CoreML ASR 모델 다운로드/로드를 통합 진행도로 보고
    func loadModel(
        _ model: ModelIdentifier,
        progressCallback: (@Sendable (Float) -> Void)?,
        statusCallback: (@Sendable (String) -> Void)?
    ) async throws {
        logger.debug("loadModel: \(model.variantKey)")

        statusCallback?("모델 다운로드 중")
        let loaded = try await Qwen3CoreMLInference.fromPretrained(
            modelId: model.variantKey,
            progressHandler: { progress, status in
                logger.debug("loadModel progress: \(progress) - \(status)")
                progressCallback?(Float(progress))
                statusCallback?(status)
            }
        )

        try Task.checkCancellation()

        lock.withLock {
            self.inference = loaded
            self._currentModel = model
        }
    }

    func unloadModel() async {
        lock.withLock {
            self.inference = nil
            self._currentModel = nil
        }
    }

    func transcribe(
        audioURL: URL,
        language: String?,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws -> TranscriptionOutput {
        logger.debug("transcribe: audioURL = \(audioURL.path)")

        guard let inference = lock.withLock({ self.inference }) else {
            throw Qwen3ASREngineError.modelNotLoaded
        }

        let samples = try AudioSampleLoader.load(url: audioURL)
        progressCallback?(0.2)

        let text = try inference.transcribe(
            audio: samples,
            sampleRate: 16000,
            language: language,
            maxTokens: 448
        )
        progressCallback?(1.0)

        return TranscriptionOutput(
            text: text,
            segments: [],
            language: language
        )
    }

    func supportedModels() -> [ModelIdentifier] {
        ModelIdentifier.allModels(for: .qwen3ASR)
            .filter { DeviceCapability.current.supports($0) }
    }
}

enum Qwen3ASREngineError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: "Qwen3-ASR 모델이 로드되지 않았습니다."
        }
    }
}
#endif
