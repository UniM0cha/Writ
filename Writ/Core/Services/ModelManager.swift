import Foundation
import os

private let logger = Logger(subsystem: AppGroupConstants.logSubsystem, category: "Model")

/// 모델 다운로드, 로드, 선택, 삭제 관리
@MainActor
final class ModelManager: ObservableObject {
    @Published var models: [WhisperModelInfo] = []
    @Published var activeModel: WhisperModelVariant?

    private let engine: WhisperKitEngine
    private let capability = DeviceCapability.current
    private var activeLoadTask: Task<Void, any Error>?

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

    /// 다운로드/로드 취소
    func cancelDownload(_ variant: WhisperModelVariant) {
        activeLoadTask?.cancel()
        activeLoadTask = nil
        updateModelState(variant, state: Self.isModelDownloaded(variant) ? .downloaded : .notDownloaded)
    }

    /// 모델 다운로드 및 로드 (선택)
    func loadModel(_ variant: WhisperModelVariant) async throws {
        // 기존 모델 메모리 해제 (CoreML 모델은 수백MB~1GB 차지)
        if activeModel != nil {
            await engine.unloadModel()
            activeModel = nil
        }

        // 진행 중인 작업 취소 및 완료 대기
        if let existingTask = activeLoadTask {
            existingTask.cancel()
            try? await existingTask.value
        }

        updateModelState(variant, state: .downloading(progress: 0))

        let task = Task { [weak self] in
            guard let self else { return }
            try Task.checkCancellation()
            try await engine.loadModel(
                variant,
                progressCallback: { [weak self] progress in
                    guard let self else { return }
                    Task { @MainActor [weak self] in
                        self?.updateModelState(variant, state: .downloading(progress: progress))
                    }
                },
                phaseCallback: { [weak self] phase in
                    Task { @MainActor [weak self] in
                        switch phase {
                        case .optimizing:
                            self?.updateModelState(variant, state: .optimizing)
                        case .loading:
                            self?.updateModelState(variant, state: .loading)
                        }
                    }
                }
            )
        }
        activeLoadTask = task

        do {
            try await task.value
            activeLoadTask = nil

            // 기존 loaded 모델을 downloaded로 변경
            for i in models.indices {
                if case .loaded = models[i].state {
                    models[i].state = .downloaded
                }
            }
            updateModelState(variant, state: .loaded)
            activeModel = variant
            UserDefaults.standard.set(variant.rawValue, forKey: "selectedModelVariant")
            AppGroupConstants.sharedDefaults.set(variant.rawValue, forKey: "selectedModelVariant")
            AppGroupConstants.sharedDefaults.set(variant.displayName, forKey: "selectedModelDisplayName")
        } catch is CancellationError {
            activeLoadTask = nil
            // 취소는 cancelDownload()에서 상태 처리함
        } catch {
            activeLoadTask = nil
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

        // 모든 경로에서 삭제 (기본, 레거시)
        let paths = [
            Self.modelsBaseURL.appendingPathComponent(variant.rawValue),
            Self.legacyModelsBaseURL.appendingPathComponent(variant.rawValue)
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path.path) {
                try? FileManager.default.removeItem(at: path)
            }
        }
        AppGroupConstants.sharedDefaults.removeObject(forKey: "selectedModelVariant")
        updateModelState(variant, state: .notDownloaded)
    }

    /// 전사 실행. large 모델 실패 시 기본 모델로 폴백.
    func transcribe(
        audioURL: URL,
        language: String?,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws -> TranscriptionOutput {
        logger.debug("transcribe: audioURL = \(audioURL.path), activeModel = \(String(describing: self.activeModel)), language = \(String(describing: language))")

        guard activeModel != nil else {
            logger.error("transcribe: no active model")
            throw WhisperKitEngineError.modelNotLoaded
        }

        do {
            let result = try await engine.transcribe(audioURL: audioURL, language: language, progressCallback: progressCallback)
            logger.debug("transcribe: success, text length = \(result.text.count)")
            return result
        } catch {
            logger.error("transcribe: engine.transcribe failed: \(error)")
            if let current = activeModel,
               (current == .largeV3 || current == .largeV3Turbo) {
                let fallback = capability.defaultModel
                logger.info("transcribe: falling back to \(fallback.rawValue)")
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
