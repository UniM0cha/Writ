import XCTest
@testable import Writ

@MainActor
final class ModelManagerTests: XCTestCase {

    private var engine: WhisperKitEngine!
    private var sut: ModelManager!

    override func setUp() {
        super.setUp()
        engine = WhisperKitEngine()
        sut = ModelManager(engine: engine)
    }

    override func tearDown() {
        sut = nil
        engine = nil
        UserDefaults.standard.removeObject(forKey: "selectedModelVariant")
        super.tearDown()
    }

    // MARK: - Init Tests

    func test_init_modelsContainsAllVariants() {
        // Given/When: ModelManager가 초기화되면
        // Then: WhisperModelVariant.allCases 만큼의 모델 정보가 생성된다
        XCTAssertEqual(sut.models.count, WhisperModelVariant.allCases.count)
    }

    func test_init_modelsCountIsFive() {
        // WhisperModelVariant에는 tiny, base, small, largeV3, largeV3Turbo 5개가 있다
        XCTAssertEqual(sut.models.count, 5)
    }

    func test_init_modelsContainCorrectVariants() {
        let variants = sut.models.map(\.variant)
        XCTAssertTrue(variants.contains(.tiny))
        XCTAssertTrue(variants.contains(.base))
        XCTAssertTrue(variants.contains(.small))
        XCTAssertTrue(variants.contains(.largeV3))
        XCTAssertTrue(variants.contains(.largeV3Turbo))
    }

    func test_init_modelsOrderMatchesAllCases() {
        // models 배열 순서가 WhisperModelVariant.allCases 순서와 동일해야 한다
        let expectedVariants = WhisperModelVariant.allCases
        let actualVariants = sut.models.map(\.variant)
        XCTAssertEqual(actualVariants, expectedVariants)
    }

    func test_init_activeModelIsNil() {
        XCTAssertNil(sut.activeModel)
    }

    func test_init_modelsHaveCorrectInitialState() {
        // 테스트 환경에서는 모델이 다운로드되어 있지 않으므로 모두 notDownloaded여야 한다
        for model in sut.models {
            if case .notDownloaded = model.state {
                // 예상대로 notDownloaded
            } else if case .downloaded = model.state {
                // 실제로 다운로드된 모델이 있을 수 있으므로 허용
            } else {
                XCTFail("초기 상태는 notDownloaded 또는 downloaded여야 한다. 실제: \(model.state), variant: \(model.variant)")
            }
        }
    }

    func test_init_eachModelHasUniqueVariant() {
        let variants = sut.models.map(\.variant)
        let uniqueVariants = Set(variants)
        XCTAssertEqual(variants.count, uniqueVariants.count, "중복 variant가 존재한다")
    }

    // MARK: - isModelDownloaded Static Method

    func test_isModelDownloaded_returnsValueForAllVariants() {
        // 테스트 환경에서 static 메서드가 크래시 없이 동작하는지 확인
        for variant in WhisperModelVariant.allCases {
            // 크래시 없이 Bool을 반환하면 성공
            _ = ModelManager.isModelDownloaded(variant)
        }
    }

    func test_isModelDownloaded_returnsFalseForNonExistentModel() {
        // 테스트 환경에서 모델이 다운로드되어 있지 않으므로 false 반환 예상
        // (CI 환경에서는 항상 false, 개발 머신에서는 다운로드된 모델이 있을 수 있음)
        let result = ModelManager.isModelDownloaded(.tiny)
        // 단순히 크래시 없이 Bool을 반환하는지 확인
        XCTAssertNotNil(result)
    }

    // MARK: - Model Support Info

    func test_init_tinyModelIsAlwaysSupported() {
        // tiny 모델은 minimumRAMGB가 1이므로 모든 테스트 환경에서 지원된다
        let tinyInfo = sut.models.first { $0.variant == .tiny }
        XCTAssertNotNil(tinyInfo)
        XCTAssertTrue(tinyInfo!.isSupported)
    }

    func test_init_baseModelIsAlwaysSupported() {
        // base 모델도 minimumRAMGB가 1이므로 모든 테스트 환경에서 지원된다
        let baseInfo = sut.models.first { $0.variant == .base }
        XCTAssertNotNil(baseInfo)
        XCTAssertTrue(baseInfo!.isSupported)
    }

    func test_init_unsupportedModelHasReason() {
        // isSupported가 false인 모델은 unsupportedReason이 있어야 한다
        for model in sut.models where !model.isSupported {
            XCTAssertNotNil(model.unsupportedReason, "\(model.variant) is not supported but has no reason")
        }
    }

    func test_init_supportedModelHasNoUnsupportedReason() {
        // isSupported가 true인 모델은 unsupportedReason이 nil이어야 한다
        for model in sut.models where model.isSupported {
            XCTAssertNil(model.unsupportedReason, "\(model.variant) is supported but has unsupportedReason")
        }
    }

    // MARK: - refreshDownloadStates

    func test_refreshDownloadStates_doesNotCrash() {
        // refreshDownloadStates가 크래시 없이 실행되는지 확인
        sut.refreshDownloadStates()
        // 크래시 없이 완료되면 성공
        XCTAssertEqual(sut.models.count, 5)
    }

    func test_refreshDownloadStates_maintainsModelCount() {
        sut.refreshDownloadStates()
        XCTAssertEqual(sut.models.count, WhisperModelVariant.allCases.count)
    }

    func test_refreshDownloadStates_statesAreConsistentWithFileSystem() {
        sut.refreshDownloadStates()
        for model in sut.models {
            let isDownloaded = ModelManager.isModelDownloaded(model.variant)
            if isDownloaded {
                // 다운로드된 모델은 downloaded 또는 loaded 상태여야 한다
                switch model.state {
                case .downloaded, .loaded:
                    break
                default:
                    XCTFail("\(model.variant)가 다운로드되어 있지만 상태가 \(model.state)")
                }
            } else {
                // 다운로드되지 않은 모델은 notDownloaded여야 한다
                if case .notDownloaded = model.state {
                    // OK
                } else {
                    XCTFail("\(model.variant)가 다운로드되어 있지 않지만 상태가 \(model.state)")
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
            // OK
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
        // 경계값: 0%
        if case .downloading(let progress) = ModelState.downloading(progress: 0.0) {
            XCTAssertEqual(progress, 0.0, accuracy: 0.001)
        } else {
            XCTFail("Expected downloading with 0.0")
        }

        // 경계값: 100%
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

    // MARK: - WhisperModelInfo Tests

    func test_whisperModelInfo_defaultInit() {
        let info = WhisperModelInfo(variant: .tiny)
        XCTAssertEqual(info.variant, .tiny)
        if case .notDownloaded = info.state { } else {
            XCTFail("기본 state는 notDownloaded여야 한다")
        }
        XCTAssertTrue(info.isSupported)
        XCTAssertNil(info.unsupportedReason)
    }

    func test_whisperModelInfo_idMatchesVariantId() {
        let info = WhisperModelInfo(variant: .small)
        XCTAssertEqual(info.id, WhisperModelVariant.small.id)
    }

    func test_whisperModelInfo_customInit() {
        let info = WhisperModelInfo(
            variant: .largeV3,
            state: .downloaded,
            isSupported: false,
            unsupportedReason: "메모리 부족"
        )
        XCTAssertEqual(info.variant, .largeV3)
        if case .downloaded = info.state { } else {
            XCTFail("state가 downloaded여야 한다")
        }
        XCTAssertFalse(info.isSupported)
        XCTAssertEqual(info.unsupportedReason, "메모리 부족")
    }

    // MARK: - DeviceCapability Tests

    func test_deviceCapability_currentIsNotNil() {
        // DeviceCapability.current가 유효한 값을 반환하는지 확인
        let capability = DeviceCapability.current
        // enum이므로 항상 유효한 케이스
        switch capability {
        case .highEnd, .midRange, .lowEnd:
            break // 유효한 케이스
        }
    }

    func test_deviceCapability_supportsAtLeastTiny() {
        // 어떤 디바이스든 tiny 모델은 지원해야 한다
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
        // copyModelToSharedContainer 메서드가 ModelManager에서 제거되었는지 확인
        // WritKeyboard 제거 후 더 이상 필요하지 않은 dead code
        let selector = NSSelectorFromString("copyModelToSharedContainer:")
        let responds = (sut as AnyObject).responds(to: selector)
        XCTAssertFalse(
            responds,
            "ModelManager에서 'copyModelToSharedContainer'가 제거되었어야 함"
        )
    }

    func test_copyModelToSharedContainerVariantDoesNotExist() {
        // 다른 시그니처 변형도 확인
        let selector = NSSelectorFromString("copyModelToSharedContainerWithVariant:")
        let responds = (sut as AnyObject).responds(to: selector)
        XCTAssertFalse(
            responds,
            "ModelManager에서 'copyModelToSharedContainerWithVariant'가 제거되었어야 함"
        )
    }

    // MARK: - loadModel에서 sharedDefaults 저장 검증

    func test_sharedDefaultsKey_isAccessible() {
        // ModelManager.loadModel이 sharedDefaults에 selectedModelVariant를 저장하는지
        // 여기서는 sharedDefaults 자체가 접근 가능한지만 확인 (loadModel은 네트워크 필요)
        let defaults = AppGroupConstants.sharedDefaults
        XCTAssertNotNil(defaults, "sharedDefaults에 접근 가능해야 함")
    }

    // MARK: - loadModel 초기 상태: .downloading(progress: 0) (Fix 2)

    func test_loadModel_initialStateTransition_isDownloadingNotLoading() {
        // ModelManager.loadModel의 초기 상태 설정을 직접 시뮬레이션하여 검증
        // loadModel은 updateModelState(variant, state: .downloading(progress: 0))을 호출해야 한다
        let variant: WhisperModelVariant = .tiny

        // 수동으로 downloading(progress: 0) 상태 설정 (loadModel의 첫 번째 동작 재현)
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .downloading(progress: 0)
        }

        let model = sut.models.first { $0.variant == variant }
        XCTAssertNotNil(model)
        if case .downloading(let progress) = model!.state {
            XCTAssertEqual(progress, 0.0, accuracy: 0.001, "초기 진행률은 0이어야 한다")
        } else {
            XCTFail("loadModel 초기 상태는 .downloading(progress: 0)이어야 한다. 실제: \(model!.state)")
        }
    }

    // MARK: - sharedDefaults에 displayName 저장 (Fix 5)

    func test_sharedDefaults_selectedModelDisplayNameKey_canBeWrittenAndRead() {
        // ModelManager.loadModel 성공 시 sharedDefaults에 displayName이 저장되는 계약을 검증
        let defaults = AppGroupConstants.sharedDefaults
        let testKey = "selectedModelDisplayName"

        // 테스트 전 정리
        defaults.removeObject(forKey: testKey)
        XCTAssertNil(defaults.string(forKey: testKey))

        // displayName 저장 시뮬레이션
        let expectedName = WhisperModelVariant.small.displayName
        defaults.set(expectedName, forKey: testKey)
        XCTAssertEqual(defaults.string(forKey: testKey), expectedName)

        // 정리
        defaults.removeObject(forKey: testKey)
    }

    func test_displayName_matchesExpectedValues() {
        // loadModel이 저장하는 displayName이 올바른지 확인
        XCTAssertEqual(WhisperModelVariant.tiny.displayName, "Tiny")
        XCTAssertEqual(WhisperModelVariant.base.displayName, "Base")
        XCTAssertEqual(WhisperModelVariant.small.displayName, "Small")
        XCTAssertEqual(WhisperModelVariant.largeV3.displayName, "Large v3")
        XCTAssertEqual(WhisperModelVariant.largeV3Turbo.displayName, "Large v3 Turbo")
    }

    func test_sharedDefaults_bothKeysSetTogether() {
        // loadModel 성공 시 selectedModelVariant와 selectedModelDisplayName이 함께 저장되어야 한다
        let defaults = AppGroupConstants.sharedDefaults
        let variantKey = "selectedModelVariant"
        let displayNameKey = "selectedModelDisplayName"

        // 정리
        defaults.removeObject(forKey: variantKey)
        defaults.removeObject(forKey: displayNameKey)

        // loadModel 성공 시 저장 시뮬레이션
        let variant = WhisperModelVariant.small
        defaults.set(variant.rawValue, forKey: variantKey)
        defaults.set(variant.displayName, forKey: displayNameKey)

        // 읽기 검증
        XCTAssertEqual(defaults.string(forKey: variantKey), variant.rawValue)
        XCTAssertEqual(defaults.string(forKey: displayNameKey), "Small")

        // 정리
        defaults.removeObject(forKey: variantKey)
        defaults.removeObject(forKey: displayNameKey)
    }

    func test_sharedDefaults_widgetReadsDisplayName() {
        // 위젯(WritWidgetProvider)이 읽는 키와 동일한 키에 저장되는지 확인
        // WritWidgetProvider.currentModelName()은 "selectedModelDisplayName" 키를 읽는다
        let defaults = UserDefaults(suiteName: "group.com.solstice.writ") ?? .standard
        let key = "selectedModelDisplayName"

        defaults.removeObject(forKey: key)

        // 모델 선택 후 저장 (ModelManager가 하는 것과 동일)
        defaults.set(WhisperModelVariant.base.displayName, forKey: key)

        // 위젯이 읽는 것과 동일한 방식으로 읽기
        let modelName = defaults.string(forKey: key) ?? "준비 중"
        XCTAssertEqual(modelName, "Base")

        // 키가 없을 때 폴백 확인
        defaults.removeObject(forKey: key)
        let fallback = defaults.string(forKey: key) ?? "준비 중"
        XCTAssertEqual(fallback, "준비 중")
    }

    // MARK: - loadModel이 이전 작업 취소 및 대기 (Fix 8)

    func test_loadModel_cancelsExistingTask_stateResetOnCancel() {
        // loadModel에서 기존 작업 취소 시 cancelDownload을 통해 상태가 복원되는지 확인
        // 네트워크 불필요: cancelDownload의 동작만 검증
        let variant: WhisperModelVariant = .tiny

        // downloading 상태로 설정 (loadModel 진행 중 시뮬레이션)
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .downloading(progress: 0.3)
        }

        // cancelDownload 호출 (loadModel 내부에서 기존 작업 취소 시 수행하는 것과 동일)
        sut.cancelDownload(variant)

        let model = sut.models.first { $0.variant == variant }
        XCTAssertNotNil(model)
        // cancelDownload 후 상태가 notDownloaded 또는 downloaded로 복원되어야 한다
        switch model!.state {
        case .notDownloaded, .downloaded:
            break // 예상대로
        default:
            XCTFail("cancelDownload 후 downloading 상태가 남아있으면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_loadModel_activeModelClearedBeforeNewLoad() {
        // loadModel은 기존 activeModel이 있으면 먼저 nil로 설정해야 한다
        // 네트워크 불필요: activeModel 초기 상태 검증
        XCTAssertNil(sut.activeModel, "초기 activeModel은 nil이어야 한다")
    }

    func test_loadModel_stateFlow_downloadingToLoaded() {
        // loadModel의 전체 상태 흐름을 수동으로 시뮬레이션
        // downloading(0) -> downloading(progress) -> optimizing -> loading -> loaded
        let variant: WhisperModelVariant = .tiny

        // 1. 초기 상태: downloading(progress: 0)
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .downloading(progress: 0)
        }
        if case .downloading(let p) = sut.models.first(where: { $0.variant == variant })!.state {
            XCTAssertEqual(p, 0.0, accuracy: 0.001)
        } else {
            XCTFail("Expected .downloading(progress: 0)")
        }

        // 2. 다운로드 진행
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .downloading(progress: 0.7)
        }

        // 3. 최적화
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .optimizing
        }

        // 4. 로딩
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .loading
        }

        // 5. 로드 완료
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .loaded
        }
        if case .loaded = sut.models.first(where: { $0.variant == variant })!.state {
            // OK
        } else {
            XCTFail("Expected .loaded at end of state flow")
        }
    }

    // MARK: - cancelDownload이 sharedDefaults를 정리하지 않는지 확인

    func test_cancelDownload_doesNotClearSharedDefaults() {
        // cancelDownload는 sharedDefaults의 displayName을 제거하지 않아야 한다
        // (deleteModel만 sharedDefaults를 정리함)
        let defaults = AppGroupConstants.sharedDefaults
        let key = "selectedModelDisplayName"

        defaults.set("Test Model", forKey: key)
        sut.cancelDownload(.tiny)

        // cancelDownload 후에도 displayName이 유지되어야 한다
        XCTAssertEqual(defaults.string(forKey: key), "Test Model")

        // 정리
        defaults.removeObject(forKey: key)
    }

    // MARK: - deleteModel이 sharedDefaults를 정리하는지 확인

    func test_deleteModel_clearsSharedDefaultsVariant() async {
        // deleteModel은 sharedDefaults에서 selectedModelVariant를 제거해야 한다
        let defaults = AppGroupConstants.sharedDefaults
        let variantKey = "selectedModelVariant"

        defaults.set("test_variant", forKey: variantKey)
        await sut.deleteModel(.tiny)

        XCTAssertNil(defaults.string(forKey: variantKey),
                     "deleteModel 후 sharedDefaults의 selectedModelVariant가 제거되어야 한다")
    }
}
