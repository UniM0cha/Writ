import XCTest
@testable import Writ

@MainActor
final class ModelManagerTests: XCTestCase {

    private var engine: WhisperKitEngine!
    private var sut: ModelManager!

    /// Whisper + Qwen3-ASR 모델 합계
    private let totalModelCount = WhisperModelVariant.allCases.count + ModelIdentifier.allModels(for: .qwen3ASR).count

    override func setUp() {
        super.setUp()
        engine = WhisperKitEngine()
        sut = ModelManager(whisperEngine: engine)
    }

    override func tearDown() {
        sut = nil
        engine = nil
        UserDefaults.standard.removeObject(forKey: "selectedModelVariant")
        UserDefaults.standard.removeObject(forKey: "selectedEngineType")
        super.tearDown()
    }

    // MARK: - Init Tests

    func test_init_modelsContainsAllEngineVariants() {
        XCTAssertEqual(sut.models.count, totalModelCount)
    }

    func test_init_whisperModelsCountIsFive() {
        let whisperModels = sut.models.filter { $0.identifier.engine == .whisperKit }
        XCTAssertEqual(whisperModels.count, 5)
    }

    func test_init_qwenModelsCountIsFour() {
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        XCTAssertEqual(qwenModels.count, 4)
    }

    func test_init_modelsContainCorrectWhisperVariants() {
        let whisperIds = sut.models
            .filter { $0.identifier.engine == .whisperKit }
            .compactMap { $0.identifier.whisperVariant }
        XCTAssertTrue(whisperIds.contains(.tiny))
        XCTAssertTrue(whisperIds.contains(.base))
        XCTAssertTrue(whisperIds.contains(.small))
        XCTAssertTrue(whisperIds.contains(.largeV3))
        XCTAssertTrue(whisperIds.contains(.largeV3Turbo))
    }

    func test_init_activeModelIsNil() {
        XCTAssertNil(sut.activeModel)
    }

    func test_init_selectedEngineIsWhisperKit() {
        XCTAssertEqual(sut.selectedEngine, .whisperKit)
    }

    func test_init_modelsHaveCorrectInitialState() {
        for model in sut.models {
            if case .notDownloaded = model.state {
            } else if case .downloaded = model.state {
            } else {
                XCTFail("초기 상태는 notDownloaded 또는 downloaded여야 한다. 실제: \(model.state), id: \(model.identifier.displayName)")
            }
        }
    }

    func test_init_eachModelHasUniqueIdentifier() {
        let ids = sut.models.map(\.identifier)
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "중복 identifier가 존재한다")
    }

    // MARK: - currentEngineModels

    func test_currentEngineModels_filtersBySelectedEngine() {
        sut.selectedEngine = .whisperKit
        XCTAssertEqual(sut.currentEngineModels.count, WhisperModelVariant.allCases.count)

        sut.selectedEngine = .qwen3ASR
        XCTAssertEqual(sut.currentEngineModels.count, ModelIdentifier.allModels(for: .qwen3ASR).count)
    }

    // MARK: - isWhisperModelDownloaded Static Method

    func test_isWhisperModelDownloaded_returnsValueForAllVariants() {
        for variant in WhisperModelVariant.allCases {
            _ = ModelManager.isWhisperModelDownloaded(variant)
        }
    }

    func test_isWhisperModelDownloaded_returnsFalseForNonExistentModel() {
        let result = ModelManager.isWhisperModelDownloaded(.tiny)
        XCTAssertNotNil(result)
    }

    // MARK: - Model Support Info

    func test_init_tinyModelIsAlwaysSupported() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        let tinyInfo = sut.models.first { $0.identifier == tinyId }
        XCTAssertNotNil(tinyInfo)
        XCTAssertTrue(tinyInfo!.isSupported)
    }

    func test_init_baseModelIsAlwaysSupported() {
        let baseId = WhisperModelVariant.base.modelIdentifier
        let baseInfo = sut.models.first { $0.identifier == baseId }
        XCTAssertNotNil(baseInfo)
        XCTAssertTrue(baseInfo!.isSupported)
    }

    func test_init_unsupportedModelHasReason() {
        for model in sut.models where !model.isSupported {
            XCTAssertNotNil(model.unsupportedReason, "\(model.identifier.displayName) is not supported but has no reason")
        }
    }

    func test_init_supportedModelHasNoUnsupportedReason() {
        for model in sut.models where model.isSupported {
            XCTAssertNil(model.unsupportedReason, "\(model.identifier.displayName) is supported but has unsupportedReason")
        }
    }

    // MARK: - refreshDownloadStates

    func test_refreshDownloadStates_doesNotCrash() {
        sut.refreshDownloadStates()
        XCTAssertEqual(sut.models.count, totalModelCount)
    }

    func test_refreshDownloadStates_maintainsModelCount() {
        sut.refreshDownloadStates()
        XCTAssertEqual(sut.models.count, totalModelCount)
    }

    func test_refreshDownloadStates_whisperStatesAreConsistentWithFileSystem() {
        sut.refreshDownloadStates()
        for model in sut.models where model.identifier.engine == .whisperKit {
            guard let variant = model.identifier.whisperVariant else { continue }
            let isDownloaded = ModelManager.isWhisperModelDownloaded(variant)
            if isDownloaded {
                switch model.state {
                case .downloaded, .loaded:
                    break
                default:
                    XCTFail("\(variant)가 다운로드되어 있지만 상태가 \(model.state)")
                }
            } else {
                if case .notDownloaded = model.state {
                } else {
                    XCTFail("\(variant)가 다운로드되어 있지 않지만 상태가 \(model.state)")
                }
            }
        }
    }

    // MARK: - WhisperModelVariant Tests

    func test_whisperModelVariant_allCasesHasFiveElements() {
        XCTAssertEqual(WhisperModelVariant.allCases.count, 5)
    }

    func test_whisperModelVariant_rawValuesAreCorrect() {
        XCTAssertEqual(WhisperModelVariant.tiny.rawValue, "openai_whisper-tiny")
        XCTAssertEqual(WhisperModelVariant.base.rawValue, "openai_whisper-base")
        XCTAssertEqual(WhisperModelVariant.small.rawValue, "openai_whisper-small")
        XCTAssertEqual(WhisperModelVariant.largeV3.rawValue, "openai_whisper-large-v3")
        XCTAssertEqual(WhisperModelVariant.largeV3Turbo.rawValue, "openai_whisper-large-v3_turbo")
    }

    func test_whisperModelVariant_displayNamesAreNotEmpty() {
        for variant in WhisperModelVariant.allCases {
            XCTAssertFalse(variant.displayName.isEmpty, "\(variant) displayName이 비어있다")
        }
    }

    func test_whisperModelVariant_diskSizesArePositive() {
        for variant in WhisperModelVariant.allCases {
            XCTAssertGreaterThan(variant.diskSizeMB, 0, "\(variant) diskSizeMB가 0 이하이다")
        }
    }

    func test_whisperModelVariant_minimumRAMIsPositive() {
        for variant in WhisperModelVariant.allCases {
            XCTAssertGreaterThan(variant.minimumRAMGB, 0, "\(variant) minimumRAMGB가 0 이하이다")
        }
    }

    func test_whisperModelVariant_diskSizeIncreasesWithModelSize() {
        XCTAssertLessThan(WhisperModelVariant.tiny.diskSizeMB, WhisperModelVariant.base.diskSizeMB)
        XCTAssertLessThan(WhisperModelVariant.base.diskSizeMB, WhisperModelVariant.small.diskSizeMB)
        XCTAssertLessThan(WhisperModelVariant.small.diskSizeMB, WhisperModelVariant.largeV3.diskSizeMB)
    }

    func test_whisperModelVariant_idEqualsRawValue() {
        for variant in WhisperModelVariant.allCases {
            XCTAssertEqual(variant.id, variant.rawValue)
        }
    }

    // MARK: - ModelState Tests

    func test_modelState_notDownloaded() {
        let state: ModelState = .notDownloaded
        if case .notDownloaded = state {
        } else {
            XCTFail("Expected notDownloaded")
        }
    }

    func test_modelState_downloading() {
        let state: ModelState = .downloading(progress: 0.5)
        if case .downloading(let progress) = state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.001)
        } else {
            XCTFail("Expected downloading")
        }
    }

    func test_modelState_downloadingBoundaryValues() {
        if case .downloading(let progress) = ModelState.downloading(progress: 0.0) {
            XCTAssertEqual(progress, 0.0, accuracy: 0.001)
        } else {
            XCTFail("Expected downloading with 0.0")
        }

        if case .downloading(let progress) = ModelState.downloading(progress: 1.0) {
            XCTAssertEqual(progress, 1.0, accuracy: 0.001)
        } else {
            XCTFail("Expected downloading with 1.0")
        }
    }

    func test_modelState_error() {
        let errorMessage = "저장 공간이 부족합니다"
        let state: ModelState = .error(errorMessage)
        if case .error(let message) = state {
            XCTAssertEqual(message, errorMessage)
        } else {
            XCTFail("Expected error state")
        }
    }

    // MARK: - DeviceCapability Tests

    func test_deviceCapability_currentIsNotNil() {
        let capability = DeviceCapability.current
        switch capability {
        case .highEnd, .midRange, .lowEnd:
            break
        }
    }

    func test_deviceCapability_supportsAtLeastTiny() {
        let capability = DeviceCapability.current
        XCTAssertTrue(capability.supports(.tiny))
    }

    func test_deviceCapability_defaultModelIsSupported() {
        let capability = DeviceCapability.current
        XCTAssertTrue(capability.supports(capability.defaultModel))
    }

    func test_deviceCapability_maxSupportedModelIsSupported() {
        let capability = DeviceCapability.current
        XCTAssertTrue(capability.supports(capability.maxSupportedModel))
    }

    // MARK: - 제거된 메서드 확인

    func test_copyModelToSharedContainerDoesNotExist() {
        let selector = NSSelectorFromString("copyModelToSharedContainer:")
        let responds = (sut as AnyObject).responds(to: selector)
        XCTAssertFalse(responds)
    }

    // MARK: - loadModel 관련

    func test_sharedDefaultsKey_isAccessible() {
        let defaults = AppGroupConstants.sharedDefaults
        XCTAssertNotNil(defaults, "sharedDefaults에 접근 가능해야 함")
    }

    func test_loadModel_initialStateTransition_isDownloadingNotLoading() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        if let index = sut.models.firstIndex(where: { $0.identifier == tinyId }) {
            sut.models[index].state = .downloading(progress: 0)
        }
        let model = sut.models.first { $0.identifier == tinyId }
        XCTAssertNotNil(model)
        if case .downloading(let progress) = model!.state {
            XCTAssertEqual(progress, 0.0, accuracy: 0.001)
        } else {
            XCTFail("loadModel 초기 상태는 .downloading(progress: 0)이어야 한다. 실제: \(model!.state)")
        }
    }

    // MARK: - sharedDefaults에 displayName 저장

    func test_sharedDefaults_selectedModelDisplayNameKey_canBeWrittenAndRead() {
        let defaults = AppGroupConstants.sharedDefaults
        let testKey = "selectedModelDisplayName"
        defaults.removeObject(forKey: testKey)
        XCTAssertNil(defaults.string(forKey: testKey))
        let expectedName = WhisperModelVariant.small.displayName
        defaults.set(expectedName, forKey: testKey)
        XCTAssertEqual(defaults.string(forKey: testKey), expectedName)
        defaults.removeObject(forKey: testKey)
    }

    func test_displayName_matchesExpectedValues() {
        XCTAssertEqual(WhisperModelVariant.tiny.displayName, "Tiny")
        XCTAssertEqual(WhisperModelVariant.base.displayName, "Base")
        XCTAssertEqual(WhisperModelVariant.small.displayName, "Small")
        XCTAssertEqual(WhisperModelVariant.largeV3.displayName, "Large v3")
        XCTAssertEqual(WhisperModelVariant.largeV3Turbo.displayName, "Large v3 Turbo")
    }

    // MARK: - cancelDownload

    func test_loadModel_cancelsExistingTask_stateResetOnCancel() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        if let index = sut.models.firstIndex(where: { $0.identifier == tinyId }) {
            sut.models[index].state = .downloading(progress: 0.3)
        }
        sut.cancelDownload(tinyId)
        let model = sut.models.first { $0.identifier == tinyId }
        XCTAssertNotNil(model)
        switch model!.state {
        case .notDownloaded, .downloaded:
            break
        default:
            XCTFail("cancelDownload 후 downloading 상태가 남아있으면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_loadModel_activeModelClearedBeforeNewLoad() {
        XCTAssertNil(sut.activeModel, "초기 activeModel은 nil이어야 한다")
    }

    func test_loadModel_stateFlow_downloadingToLoaded() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        if let index = sut.models.firstIndex(where: { $0.identifier == tinyId }) {
            sut.models[index].state = .downloading(progress: 0)
        }
        if let index = sut.models.firstIndex(where: { $0.identifier == tinyId }) {
            sut.models[index].state = .downloading(progress: 0.7)
        }
        if let index = sut.models.firstIndex(where: { $0.identifier == tinyId }) {
            sut.models[index].state = .optimizing
        }
        if let index = sut.models.firstIndex(where: { $0.identifier == tinyId }) {
            sut.models[index].state = .loading
        }
        if let index = sut.models.firstIndex(where: { $0.identifier == tinyId }) {
            sut.models[index].state = .loaded
        }
        if case .loaded = sut.models.first(where: { $0.identifier == tinyId })!.state {
        } else {
            XCTFail("Expected .loaded at end of state flow")
        }
    }

    func test_cancelDownload_doesNotClearSharedDefaults() {
        let defaults = AppGroupConstants.sharedDefaults
        let key = "selectedModelDisplayName"
        defaults.set("Test Model", forKey: key)
        sut.cancelDownload(WhisperModelVariant.tiny.modelIdentifier)
        XCTAssertEqual(defaults.string(forKey: key), "Test Model")
        defaults.removeObject(forKey: key)
    }

    func test_deleteModel_clearsSharedDefaultsVariant() async {
        let defaults = AppGroupConstants.sharedDefaults
        let variantKey = "selectedModelVariant"
        defaults.set("test_variant", forKey: variantKey)
        await sut.deleteModel(WhisperModelVariant.tiny.modelIdentifier)
        XCTAssertNil(defaults.string(forKey: variantKey),
                     "deleteModel 후 sharedDefaults의 selectedModelVariant가 제거되어야 한다")
    }

    // MARK: - ModelIdentifier Bridge Tests

    func test_whisperVariant_modelIdentifier_roundTrip() {
        for variant in WhisperModelVariant.allCases {
            let id = variant.modelIdentifier
            XCTAssertEqual(id.whisperVariant, variant)
            XCTAssertEqual(id.engine, .whisperKit)
        }
    }

    func test_qwenModelIdentifier_whisperVariant_isNil() {
        let qwenId = ModelIdentifier.qwen3_1_7B_8bit
        XCTAssertNil(qwenId.whisperVariant)
    }

    func test_allModels_whisperKit_count() {
        let models = ModelIdentifier.allModels(for: .whisperKit)
        XCTAssertEqual(models.count, WhisperModelVariant.allCases.count)
    }

    func test_allModels_qwen3ASR_count() {
        let models = ModelIdentifier.allModels(for: .qwen3ASR)
        XCTAssertEqual(models.count, 4)
    }
}
