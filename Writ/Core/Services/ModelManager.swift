import Foundation
import os

private let logger = Logger(subsystem: AppGroupConstants.logSubsystem, category: "Model")

/// 모델 다운로드, 로드, 선택, 삭제 관리. WhisperKit과 Qwen3-ASR 양쪽 엔진 지원.
@MainActor
final class ModelManager: ObservableObject {
    @Published var models: [ModelInfo] = []
    @Published var activeModel: ModelIdentifier?
    @Published var selectedEngine: EngineType = .whisperKit

    let whisperEngine: WhisperKitEngine
    #if os(iOS)
    private var qwenEngine: Qwen3ASREngine?
    #endif
    private let capability = DeviceCapability.current
    private var activeLoadTask: Task<Void, any Error>?

    /// 현재 선택된 엔진의 모델만 필터
    var currentEngineModels: [ModelInfo] {
        models.filter { $0.identifier.engine == selectedEngine }
    }

    /// WhisperKit 모델 저장 기본 경로
    private static var whisperModelsBaseURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
    }

    /// 잘못된 경로 (이전에 사용하던 -- 구분자 경로)
    private static var whisperLegacyModelsBaseURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface/models/argmaxinc--whisperkit-coreml")
    }

    init(whisperEngine: WhisperKitEngine) {
        self.whisperEngine = whisperEngine

        let whisperModels = WhisperModelVariant.allCases.map { variant in
            let id = variant.modelIdentifier
            return ModelInfo(
                identifier: id,
                state: Self.isWhisperModelDownloaded(variant) ? .downloaded : .notDownloaded,
                isSupported: capability.supports(id),
                unsupportedReason: capability.supports(id) ? nil : "이 기기에서는 메모리가 부족합니다"
            )
        }
        #if os(iOS)
        let qwenModels = ModelIdentifier.allModels(for: .qwen3ASR).map { id in
            let supported = capability.supports(id)
            return ModelInfo(
                identifier: id,
                state: .notDownloaded,
                isSupported: supported,
                unsupportedReason: supported ? nil : "이 기기에서는 메모리가 부족합니다"
            )
        }
        self.models = whisperModels + qwenModels
        #else
        self.models = whisperModels
        #endif
    }

    // MARK: - 엔진 디스패치

    private func engine(for identifier: ModelIdentifier) -> any TranscriptionEngine {
        switch identifier.engine {
        case .whisperKit:
            return whisperEngine
        case .qwen3ASR:
            #if os(iOS)
            if qwenEngine == nil { qwenEngine = Qwen3ASREngine() }
            return qwenEngine!
            #else
            fatalError("Qwen3ASR is not available on this platform")
            #endif
        }
    }

    // MARK: - 다운로드 상태 확인

    /// WhisperKit 모델이 로컬에 다운로드되었는지 확인
    static func isWhisperModelDownloaded(_ variant: WhisperModelVariant) -> Bool {
        let paths = [
            whisperModelsBaseURL.appendingPathComponent(variant.rawValue),
            whisperLegacyModelsBaseURL.appendingPathComponent(variant.rawValue)
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
            let model = models[i]
            guard model.identifier.engine == .whisperKit,
                  let variant = model.identifier.whisperVariant else { continue }

            let isDownloaded = Self.isWhisperModelDownloaded(variant)
            if isDownloaded {
                if case .notDownloaded = model.state {
                    models[i].state = .downloaded
                }
            } else {
                if case .downloaded = model.state { models[i].state = .notDownloaded }
                if case .loaded = model.state { models[i].state = .notDownloaded }
            }
        }
    }

    /// 잘못된 경로(--구분자)에 남아있는 모델 파일 정리
    private func cleanupLegacyModels() {
        let legacyPath = Self.whisperLegacyModelsBaseURL
        if FileManager.default.fileExists(atPath: legacyPath.path) {
            try? FileManager.default.removeItem(at: legacyPath)
        }
    }

    // MARK: - 모델 로드

    /// 최초 실행 시 기본 모델 자동 로드
    func loadDefaultModelIfNeeded() async {
        refreshDownloadStates()
        guard activeModel == nil else { return }

        // 1. 새 포맷 (engineType + variant) 시도
        if let engineRaw = UserDefaults.standard.string(forKey: "selectedEngineType"),
           let engine = EngineType(rawValue: engineRaw),
           engine.isAvailableOnCurrentPlatform,
           let variantKey = UserDefaults.standard.string(forKey: "selectedModelVariant"),
           let identifier = ModelIdentifier.find(engine: engine, variantKey: variantKey),
           capability.supports(identifier) {
            selectedEngine = engine
            do {
                try await loadModel(identifier)
                return
            } catch { }
        }

        // 2. 기존 포맷 (variant만, engineType 없음) → whisperKit으로 간주
        if let savedRaw = UserDefaults.standard.string(forKey: "selectedModelVariant"),
           let saved = WhisperModelVariant(rawValue: savedRaw),
           capability.supports(saved) {
            selectedEngine = .whisperKit
            do {
                try await loadModel(saved.modelIdentifier)
                return
            } catch { }
        }

        // 3. 기본 모델 fallback
        selectedEngine = .whisperKit
        let defaultModel = capability.defaultModel.modelIdentifier
        do {
            try await loadModel(defaultModel)
        } catch {
            if capability.defaultModel != .tiny {
                try? await loadModel(WhisperModelVariant.tiny.modelIdentifier)
            }
        }
    }

    /// 다운로드/로드 취소
    func cancelDownload(_ identifier: ModelIdentifier) {
        activeLoadTask?.cancel()
        activeLoadTask = nil
        let isDownloaded: Bool
        if let variant = identifier.whisperVariant {
            isDownloaded = Self.isWhisperModelDownloaded(variant)
        } else {
            isDownloaded = false
        }
        updateModelState(identifier, state: isDownloaded ? .downloaded : .notDownloaded)
    }

    /// 모델 다운로드 및 로드
    func loadModel(_ identifier: ModelIdentifier) async throws {
        // 기존 모델 메모리 해제
        if let current = activeModel {
            let eng = engine(for: current)
            await eng.unloadModel()
            activeModel = nil
        }

        // 진행 중인 작업 취소 및 완료 대기
        if let existingTask = activeLoadTask {
            existingTask.cancel()
            try? await existingTask.value
        }

        updateModelState(identifier, state: .downloading(progress: 0))

        let task = Task { [weak self] in
            guard let self else { return }
            try Task.checkCancellation()

            let eng = engine(for: identifier)

            if identifier.engine == .whisperKit {
                // WhisperKitEngine에는 phaseCallback이 있으므로 직접 호출
                try await whisperEngine.loadModel(
                    identifier,
                    progressCallback: { [weak self] progress in
                        guard let self else { return }
                        Task { @MainActor [weak self] in
                            self?.updateModelState(identifier, state: .downloading(progress: progress))
                        }
                    },
                    phaseCallback: { [weak self] phase in
                        Task { @MainActor [weak self] in
                            switch phase {
                            case .optimizing:
                                self?.updateModelState(identifier, state: .optimizing)
                            case .loading:
                                self?.updateModelState(identifier, state: .loading)
                            }
                        }
                    }
                )
            } else {
                try await eng.loadModel(
                    identifier,
                    progressCallback: { [weak self] progress in
                        guard let self else { return }
                        Task { @MainActor [weak self] in
                            self?.updateModelState(identifier, state: .downloading(progress: progress))
                        }
                    }
                )
            }
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
            updateModelState(identifier, state: .loaded)
            activeModel = identifier
            persistSelection(identifier)
        } catch is CancellationError {
            activeLoadTask = nil
        } catch {
            activeLoadTask = nil
            let message: String
            if error.localizedDescription.contains("No space left on device") {
                message = "저장 공간이 부족합니다. 불필요한 파일을 삭제한 후 다시 시도해주세요."
            } else {
                message = error.localizedDescription
            }
            updateModelState(identifier, state: .error(message))
            throw error
        }
    }

    // MARK: - 모델 삭제

    func deleteModel(_ identifier: ModelIdentifier) async {
        // 활성 모델이면 먼저 언로드
        if activeModel == identifier {
            let eng = engine(for: identifier)
            await eng.unloadModel()
            activeModel = nil
            UserDefaults.standard.removeObject(forKey: "selectedModelVariant")
            UserDefaults.standard.removeObject(forKey: "selectedEngineType")
            AppGroupConstants.sharedDefaults.removeObject(forKey: "selectedModelVariant")
            AppGroupConstants.sharedDefaults.removeObject(forKey: "selectedEngineType")
        }

        if identifier.engine == .whisperKit, let variant = identifier.whisperVariant {
            let paths = [
                Self.whisperModelsBaseURL.appendingPathComponent(variant.rawValue),
                Self.whisperLegacyModelsBaseURL.appendingPathComponent(variant.rawValue)
            ]
            for path in paths {
                if FileManager.default.fileExists(atPath: path.path) {
                    try? FileManager.default.removeItem(at: path)
                }
            }
        }
        // TODO: Qwen3-ASR 모델 디스크 삭제 (HuggingFace Hub 캐시 정리)

        updateModelState(identifier, state: .notDownloaded)
    }

    // MARK: - 전사

    func transcribe(
        audioURL: URL,
        language: String?,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws -> TranscriptionOutput {
        logger.debug("transcribe: audioURL = \(audioURL.path), activeModel = \(String(describing: self.activeModel)), language = \(String(describing: language))")

        guard let active = activeModel else {
            logger.error("transcribe: no active model")
            throw WhisperKitEngineError.modelNotLoaded
        }

        let eng = engine(for: active)

        do {
            let result = try await eng.transcribe(audioURL: audioURL, language: language, progressCallback: progressCallback)
            logger.debug("transcribe: success, text length = \(result.text.count)")
            return result
        } catch {
            logger.error("transcribe: engine.transcribe failed: \(error)")
            // WhisperKit large 모델 실패 시 기본 모델로 폴백
            if active.engine == .whisperKit,
               let variant = active.whisperVariant,
               (variant == .largeV3 || variant == .largeV3Turbo) {
                let fallback = capability.defaultModel.modelIdentifier
                logger.info("transcribe: falling back to \(fallback.displayName)")
                try await loadModel(fallback)
                return try await engine(for: fallback).transcribe(audioURL: audioURL, language: language, progressCallback: progressCallback)
            }
            throw error
        }
    }

    // MARK: - Private

    private func updateModelState(_ identifier: ModelIdentifier, state: ModelState) {
        if let index = models.firstIndex(where: { $0.identifier == identifier }) {
            models[index].state = state
        }
    }

    private func persistSelection(_ identifier: ModelIdentifier) {
        UserDefaults.standard.set(identifier.engine.rawValue, forKey: "selectedEngineType")
        UserDefaults.standard.set(identifier.variantKey, forKey: "selectedModelVariant")
        AppGroupConstants.sharedDefaults.set(identifier.engine.rawValue, forKey: "selectedEngineType")
        AppGroupConstants.sharedDefaults.set(identifier.variantKey, forKey: "selectedModelVariant")
        AppGroupConstants.sharedDefaults.set(identifier.displayName, forKey: "selectedModelDisplayName")
    }
}
