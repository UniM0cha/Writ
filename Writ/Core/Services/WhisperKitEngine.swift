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
        // 1. 다운로드 (이미 로컬에 있으면 스킵됨, 없으면 진행률 콜백 호출)
        let modelURL = try await WhisperKit.download(
            variant: model.rawValue,
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { progress in
                progressCallback?(Float(progress.fractionCompleted))
            }
        )

        // 2. 로컬 모델에서 로드만 수행 (다운로드 스킵)
        let config = WhisperKitConfig(
            modelFolder: modelURL.path,
            load: true,
            download: false
        )
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
        print("[Writ] WhisperKitEngine.transcribe: audioURL = \(audioURL.path)")
        print("[Writ] WhisperKitEngine.transcribe: file exists = \(FileManager.default.fileExists(atPath: audioURL.path))")

        guard let kit = lock.withLock({ self.whisperKit }) else {
            print("[Writ] WhisperKitEngine.transcribe: ERROR - whisperKit is nil (model not loaded)")
            throw WhisperKitEngineError.modelNotLoaded
        }

        print("[Writ] WhisperKitEngine.transcribe: calling kit.transcribe()...")
        let options = DecodingOptions(language: language, skipSpecialTokens: true)
        let results = try await kit.transcribe(audioPath: audioURL.path(), decodeOptions: options)
        print("[Writ] WhisperKitEngine.transcribe: got \(results.count) result(s)")

        guard let result = results.first else {
            print("[Writ] WhisperKitEngine.transcribe: ERROR - no results returned")
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

    func supportedModels() -> [WhisperModelVariant] {
        WhisperModelVariant.allCases.filter { DeviceCapability.current.supports($0) }
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
