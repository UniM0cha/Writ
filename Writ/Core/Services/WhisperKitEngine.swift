import Foundation
import WhisperKit

/// WhisperKit 기반 전사 엔진 구현체
final class WhisperKitEngine: TranscriptionEngine, @unchecked Sendable {
    private var whisperKit: WhisperKit?
    private var _currentModel: WhisperModelVariant?
    private let lock = NSLock()

    var currentModel: WhisperModelVariant? {
        lock.withLock { _currentModel }
    }

    init() {}

    func loadModel(
        _ model: WhisperModelVariant,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws {
        let config = WhisperKitConfig(model: model.rawValue)
        let kit = try await WhisperKit(config)
        lock.withLock {
            self.whisperKit = kit
            self._currentModel = model
        }
    }

    func unloadModel() async {
        lock.withLock {
            self.whisperKit = nil
            self._currentModel = nil
        }
    }

    func transcribe(
        audioURL: URL,
        language: String?,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws -> TranscriptionOutput {
        guard let kit = lock.withLock({ self.whisperKit }) else {
            throw WhisperKitEngineError.modelNotLoaded
        }

        let options = DecodingOptions(language: language)
        let results = try await kit.transcribe(audioPath: audioURL.path(), decodeOptions: options)

        guard let result = results.first else {
            throw WhisperKitEngineError.noResult
        }

        let segments = result.segments.map { segment in
            SegmentOutput(
                text: segment.text,
                startTime: TimeInterval(segment.start),
                endTime: TimeInterval(segment.end)
            )
        }

        return TranscriptionOutput(
            text: result.text,
            segments: segments,
            language: result.language
        )
    }

    func supportedModels() -> [WhisperModelVariant] {
        WhisperModelVariant.allCases.filter { DeviceCapability.current.supports($0) }
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
