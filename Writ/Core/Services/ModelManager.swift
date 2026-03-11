import Foundation

/// 모델 다운로드, 로드, 선택, 삭제 관리
@MainActor
final class ModelManager: ObservableObject {
    @Published var models: [WhisperModelInfo] = []
    @Published var activeModel: WhisperModelVariant?

    private let engine: WhisperKitEngine
    private let capability = DeviceCapability.current

    /// WhisperKit 모델 저장 기본 경로 (런타임 에러 로그에서 확인된 실제 경로)
    private static var modelsBaseURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
    }

    /// 잘못된 경로 (이전에 사용하던 -- 구분자 경로)
    private static var legacyModelsBaseURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface/models/argmaxinc--whisperkit-coreml")
    }

    init(engine: WhisperKitEngine) {
        self.engine = engine
        self.models = WhisperModelVariant.allCases.map { variant in
            WhisperModelInfo(
                variant: variant,
                state: Self.isModelDownloaded(variant) ? .downloaded : .notDownloaded,
                isSupported: capability.supports(variant),
                unsupportedReason: capability.supports(variant) ? nil : "이 기기에서는 메모리가 부족합니다"
            )
        }
    }

    /// 로컬에 다운로드된 모델인지 확인 (양쪽 경로 모두 확인)
    static func isModelDownloaded(_ variant: WhisperModelVariant) -> Bool {
        let paths = [
            modelsBaseURL.appendingPathComponent(variant.rawValue),
            legacyModelsBaseURL.appendingPathComponent(variant.rawValue)
        ]
        return paths.contains { path in
            let encoderPath = path.appendingPathComponent("AudioEncoder.mlmodelc")
            return FileManager.default.fileExists(atPath: encoderPath.path)
        }
    }

    /// 앱 시작 시 다운로드 상태 갱신 + 레거시 경로 정리
    func refreshDownloadStates() {
        cleanupLegacyModels()
        for i in models.indices {
            let variant = models[i].variant
            if Self.isModelDownloaded(variant) {
                if case .notDownloaded = models[i].state {
                    models[i].state = .downloaded
                }
            } else {
                if case .downloaded = models[i].state {
                    models[i].state = .notDownloaded
                }
                if case .loaded = models[i].state {
                    models[i].state = .notDownloaded
                }
            }
        }
    }

    /// 잘못된 경로(--구분자)에 남아있는 모델 파일 정리
    private func cleanupLegacyModels() {
        let legacyPath = Self.legacyModelsBaseURL
        if FileManager.default.fileExists(atPath: legacyPath.path) {
            try? FileManager.default.removeItem(at: legacyPath)
        }
    }

    /// 최초 실행 시 기본 모델 자동 로드
    func loadDefaultModelIfNeeded() async {
        refreshDownloadStates()
        guard activeModel == nil else { return }

        // 저장된 선택 모델이 있으면 그것을 로드
        if let savedRaw = UserDefaults.standard.string(forKey: "selectedModelVariant"),
           let saved = WhisperModelVariant(rawValue: savedRaw),
           capability.supports(saved) {
            do {
                try await loadModel(saved)
                return
            } catch { }
        }

        let defaultModel = capability.defaultModel
        do {
            try await loadModel(defaultModel)
        } catch {
            if defaultModel != .tiny {
                try? await loadModel(.tiny)
            }
        }
    }

    /// 모델 다운로드 및 로드 (선택)
    func loadModel(_ variant: WhisperModelVariant) async throws {
        updateModelState(variant, state: .loading)
        do {
            try await engine.loadModel(variant) { [weak self] progress in
                Task { @MainActor in
                    self?.updateModelState(variant, state: .downloading(progress: progress))
                }
            }
            updateModelState(variant, state: .loaded)
            activeModel = variant
            UserDefaults.standard.set(variant.rawValue, forKey: "selectedModelVariant")
        } catch {
            let message: String
            if error.localizedDescription.contains("No space left on device") {
                message = "저장 공간이 부족합니다. 불필요한 파일을 삭제한 후 다시 시도해주세요."
            } else {
                message = error.localizedDescription
            }
            updateModelState(variant, state: .error(message))
            throw error
        }
    }

    /// 모델 삭제
    func deleteModel(_ variant: WhisperModelVariant) async {
        // 활성 모델이면 먼저 언로드
        if activeModel == variant {
            await engine.unloadModel()
            activeModel = nil
            UserDefaults.standard.removeObject(forKey: "selectedModelVariant")
        }

        // 양쪽 경로 모두 삭제
        let paths = [
            Self.modelsBaseURL.appendingPathComponent(variant.rawValue),
            Self.legacyModelsBaseURL.appendingPathComponent(variant.rawValue)
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path.path) {
                try? FileManager.default.removeItem(at: path)
            }
        }
        updateModelState(variant, state: .notDownloaded)
    }

    /// 전사 실행. large 모델 실패 시 기본 모델로 폴백.
    func transcribe(
        audioURL: URL,
        language: String?,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws -> TranscriptionOutput {
        do {
            return try await engine.transcribe(audioURL: audioURL, language: language, progressCallback: progressCallback)
        } catch {
            if let current = activeModel,
               (current == .largeV3 || current == .largeV3Turbo) {
                let fallback = capability.defaultModel
                try await loadModel(fallback)
                return try await engine.transcribe(audioURL: audioURL, language: language, progressCallback: progressCallback)
            }
            throw error
        }
    }

    private func updateModelState(_ variant: WhisperModelVariant, state: ModelState) {
        if let index = models.firstIndex(where: { $0.variant == variant }) {
            models[index].state = state
        }
    }
}
