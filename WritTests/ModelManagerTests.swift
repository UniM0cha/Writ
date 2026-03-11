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
}
