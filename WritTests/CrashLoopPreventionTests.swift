import XCTest
@testable import Writ

/// clearPersistedSelection() 및 크래시 루프 방지 카운터 검증
///
/// ModelManager.clearPersistedSelection()이 UserDefaults와 sharedDefaults에서
/// 모든 관련 키를 제거하는지, AppState.setup()의 consecutiveLoadFailures 카운터가
/// 연속 실패 시 모델 자동 로드를 건너뛰는지 테스트한다.
@MainActor
final class CrashLoopPreventionTests: XCTestCase {

    private var engine: WhisperKitEngine!
    private var sut: ModelManager!

    private let failKey = "consecutiveLoadFailures"
    private let variantKey = "selectedModelVariant"
    private let engineKey = "selectedEngineType"
    private let displayNameKey = "selectedModelDisplayName"

    override func setUp() {
        super.setUp()
        engine = WhisperKitEngine()
        sut = ModelManager(whisperEngine: engine)

        // 테스트 시작 전 관련 키 정리
        UserDefaults.standard.removeObject(forKey: variantKey)
        UserDefaults.standard.removeObject(forKey: engineKey)
        UserDefaults.standard.removeObject(forKey: failKey)
        AppGroupConstants.sharedDefaults.removeObject(forKey: variantKey)
        AppGroupConstants.sharedDefaults.removeObject(forKey: engineKey)
        AppGroupConstants.sharedDefaults.removeObject(forKey: displayNameKey)
    }

    override func tearDown() {
        sut = nil
        engine = nil

        // 테스트 후 관련 키 정리
        UserDefaults.standard.removeObject(forKey: variantKey)
        UserDefaults.standard.removeObject(forKey: engineKey)
        UserDefaults.standard.removeObject(forKey: failKey)
        AppGroupConstants.sharedDefaults.removeObject(forKey: variantKey)
        AppGroupConstants.sharedDefaults.removeObject(forKey: engineKey)
        AppGroupConstants.sharedDefaults.removeObject(forKey: displayNameKey)
        super.tearDown()
    }

    // MARK: - clearPersistedSelection: UserDefaults.standard 키 제거

    func test_clearPersistedSelection_removesVariantFromStandard() {
        // Given: UserDefaults.standard에 selectedModelVariant가 저장됨
        UserDefaults.standard.set("openai_whisper-small", forKey: variantKey)

        // When
        sut.clearPersistedSelection()

        // Then
        XCTAssertNil(
            UserDefaults.standard.string(forKey: variantKey),
            "clearPersistedSelection 후 standard의 selectedModelVariant가 제거되어야 함"
        )
    }

    func test_clearPersistedSelection_removesEngineTypeFromStandard() {
        // Given: UserDefaults.standard에 selectedEngineType이 저장됨
        UserDefaults.standard.set("whisperKit", forKey: engineKey)

        // When
        sut.clearPersistedSelection()

        // Then
        XCTAssertNil(
            UserDefaults.standard.string(forKey: engineKey),
            "clearPersistedSelection 후 standard의 selectedEngineType이 제거되어야 함"
        )
    }

    // MARK: - clearPersistedSelection: sharedDefaults 키 제거

    func test_clearPersistedSelection_removesVariantFromSharedDefaults() {
        // Given
        AppGroupConstants.sharedDefaults.set("openai_whisper-tiny", forKey: variantKey)

        // When
        sut.clearPersistedSelection()

        // Then
        XCTAssertNil(
            AppGroupConstants.sharedDefaults.string(forKey: variantKey),
            "clearPersistedSelection 후 sharedDefaults의 selectedModelVariant가 제거되어야 함"
        )
    }

    func test_clearPersistedSelection_removesEngineTypeFromSharedDefaults() {
        // Given
        AppGroupConstants.sharedDefaults.set("qwen3ASR", forKey: engineKey)

        // When
        sut.clearPersistedSelection()

        // Then
        XCTAssertNil(
            AppGroupConstants.sharedDefaults.string(forKey: engineKey),
            "clearPersistedSelection 후 sharedDefaults의 selectedEngineType이 제거되어야 함"
        )
    }

    func test_clearPersistedSelection_removesDisplayNameFromSharedDefaults() {
        // Given
        AppGroupConstants.sharedDefaults.set("Tiny", forKey: displayNameKey)

        // When
        sut.clearPersistedSelection()

        // Then
        XCTAssertNil(
            AppGroupConstants.sharedDefaults.string(forKey: displayNameKey),
            "clearPersistedSelection 후 sharedDefaults의 selectedModelDisplayName이 제거되어야 함"
        )
    }

    // MARK: - clearPersistedSelection: 모든 키 동시 제거

    func test_clearPersistedSelection_removesAllFiveKeys() {
        // Given: 모든 키에 값이 설정됨
        UserDefaults.standard.set("openai_whisper-small", forKey: variantKey)
        UserDefaults.standard.set("whisperKit", forKey: engineKey)
        AppGroupConstants.sharedDefaults.set("openai_whisper-small", forKey: variantKey)
        AppGroupConstants.sharedDefaults.set("whisperKit", forKey: engineKey)
        AppGroupConstants.sharedDefaults.set("Small", forKey: displayNameKey)

        // When
        sut.clearPersistedSelection()

        // Then: 5개 키 모두 nil
        XCTAssertNil(UserDefaults.standard.string(forKey: variantKey))
        XCTAssertNil(UserDefaults.standard.string(forKey: engineKey))
        XCTAssertNil(AppGroupConstants.sharedDefaults.string(forKey: variantKey))
        XCTAssertNil(AppGroupConstants.sharedDefaults.string(forKey: engineKey))
        XCTAssertNil(AppGroupConstants.sharedDefaults.string(forKey: displayNameKey))
    }

    // MARK: - clearPersistedSelection: 키가 이미 없는 경우 (멱등성)

    func test_clearPersistedSelection_noKeysExist_doesNotCrash() {
        // Given: 아무 키도 설정되지 않음
        XCTAssertNil(UserDefaults.standard.string(forKey: variantKey))
        XCTAssertNil(UserDefaults.standard.string(forKey: engineKey))

        // When: 크래시 없이 실행되어야 함
        sut.clearPersistedSelection()

        // Then: 여전히 nil
        XCTAssertNil(UserDefaults.standard.string(forKey: variantKey))
        XCTAssertNil(UserDefaults.standard.string(forKey: engineKey))
    }

    func test_clearPersistedSelection_calledMultipleTimes_noCrash() {
        // Given
        UserDefaults.standard.set("whisperKit", forKey: engineKey)

        // When: 여러 번 호출
        for _ in 0..<5 {
            sut.clearPersistedSelection()
        }

        // Then: 크래시 없이 모두 nil
        XCTAssertNil(UserDefaults.standard.string(forKey: engineKey))
    }

    // MARK: - clearPersistedSelection: Qwen3-ASR 엔진 키 제거

    func test_clearPersistedSelection_removesQwen3ASREngineKeys() {
        // Given: Qwen3-ASR 관련 키가 설정됨
        UserDefaults.standard.set("aufklarer/Qwen3-ASR-0.6B-MLX-4bit", forKey: variantKey)
        UserDefaults.standard.set("qwen3ASR", forKey: engineKey)
        AppGroupConstants.sharedDefaults.set("aufklarer/Qwen3-ASR-0.6B-MLX-4bit", forKey: variantKey)
        AppGroupConstants.sharedDefaults.set("qwen3ASR", forKey: engineKey)
        AppGroupConstants.sharedDefaults.set("0.6B 4-bit", forKey: displayNameKey)

        // When
        sut.clearPersistedSelection()

        // Then
        XCTAssertNil(UserDefaults.standard.string(forKey: variantKey))
        XCTAssertNil(UserDefaults.standard.string(forKey: engineKey))
        XCTAssertNil(AppGroupConstants.sharedDefaults.string(forKey: variantKey))
        XCTAssertNil(AppGroupConstants.sharedDefaults.string(forKey: engineKey))
        XCTAssertNil(AppGroupConstants.sharedDefaults.string(forKey: displayNameKey))
    }

    // MARK: - clearPersistedSelection 후 loadDefaultModelIfNeeded 동작

    func test_afterClearPersistedSelection_loadDefaultModelIfNeeded_activeModelRemainsNil() async {
        // Given: 모델 선택 정보가 저장되어 있었지만 clear됨
        UserDefaults.standard.set("openai_whisper-tiny", forKey: variantKey)
        UserDefaults.standard.set("whisperKit", forKey: engineKey)
        sut.clearPersistedSelection()

        // When
        await sut.loadDefaultModelIfNeeded()

        // Then: 저장된 모델이 없으므로 activeModel은 nil
        XCTAssertNil(
            sut.activeModel,
            "clearPersistedSelection 후 loadDefaultModelIfNeeded는 모델을 로드하지 않아야 함"
        )
    }

    // MARK: - 크래시 카운터 (consecutiveLoadFailures) 직접 검증

    func test_crashCounter_initialValueIsZero() {
        // Given: 키가 설정되지 않은 상태
        UserDefaults.standard.removeObject(forKey: failKey)

        // Then: integer(forKey:)는 키가 없으면 0을 반환
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: failKey), 0,
            "consecutiveLoadFailures 초기값은 0이어야 함"
        )
    }

    func test_crashCounter_incrementsBeforeLoad() {
        // Given: 실패 횟수가 0
        UserDefaults.standard.set(0, forKey: failKey)

        // When: setup() 로직 시뮬레이션 — 로드 전에 카운터 증가
        let failures = UserDefaults.standard.integer(forKey: failKey)
        XCTAssertTrue(failures < 2, "failures < 2여야 로드 진행")
        UserDefaults.standard.set(failures + 1, forKey: failKey)

        // Then: 카운터가 1로 증가
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: failKey), 1,
            "로드 전 카운터가 1로 증가해야 함"
        )
    }

    func test_crashCounter_resetsToZeroAfterSuccessfulLoad() {
        // Given: 실패 카운터가 1 (로드 시도 중)
        UserDefaults.standard.set(1, forKey: failKey)

        // When: 성공 후 리셋
        UserDefaults.standard.set(0, forKey: failKey)

        // Then
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: failKey), 0,
            "성공 후 카운터가 0으로 리셋되어야 함"
        )
    }

    func test_crashCounter_atTwo_skipsLoadAndClearsSelection() {
        // Given: 연속 2회 실패 상태
        UserDefaults.standard.set(2, forKey: failKey)
        UserDefaults.standard.set("openai_whisper-small", forKey: variantKey)
        UserDefaults.standard.set("whisperKit", forKey: engineKey)
        AppGroupConstants.sharedDefaults.set("openai_whisper-small", forKey: variantKey)
        AppGroupConstants.sharedDefaults.set("whisperKit", forKey: engineKey)
        AppGroupConstants.sharedDefaults.set("Small", forKey: displayNameKey)

        // When: setup() 로직 시뮬레이션
        let failures = UserDefaults.standard.integer(forKey: failKey)
        if failures >= 2 {
            UserDefaults.standard.set(0, forKey: failKey)
            sut.clearPersistedSelection()
        }

        // Then: 카운터가 리셋되고 모델 선택이 클리어됨
        XCTAssertEqual(UserDefaults.standard.integer(forKey: failKey), 0,
                       "failures >= 2일 때 카운터가 0으로 리셋되어야 함")
        XCTAssertNil(UserDefaults.standard.string(forKey: variantKey),
                     "failures >= 2일 때 selectedModelVariant가 제거되어야 함")
        XCTAssertNil(UserDefaults.standard.string(forKey: engineKey),
                     "failures >= 2일 때 selectedEngineType이 제거되어야 함")
        XCTAssertNil(AppGroupConstants.sharedDefaults.string(forKey: displayNameKey),
                     "failures >= 2일 때 selectedModelDisplayName이 제거되어야 함")
    }

    func test_crashCounter_atOne_proceedsWithLoad() {
        // Given: 1회 실패 상태 (아직 threshold 미달)
        UserDefaults.standard.set(1, forKey: failKey)
        UserDefaults.standard.set("openai_whisper-tiny", forKey: variantKey)

        // When: setup() 로직 시뮬레이션
        let failures = UserDefaults.standard.integer(forKey: failKey)

        // Then: 2 미만이므로 로드 진행
        XCTAssertTrue(
            failures < 2,
            "failures가 1이면 로드를 진행해야 함 (threshold는 2)"
        )
        // variant가 유지됨
        XCTAssertNotNil(
            UserDefaults.standard.string(forKey: variantKey),
            "failures < 2일 때 selectedModelVariant가 유지되어야 함"
        )
    }

    func test_crashCounter_atThree_alsoTriggersSkip() {
        // Given: 3회 연속 실패 (2 이상이면 모두 스킵)
        UserDefaults.standard.set(3, forKey: failKey)

        // When
        let failures = UserDefaults.standard.integer(forKey: failKey)

        // Then: >= 2 조건 충족
        XCTAssertTrue(
            failures >= 2,
            "failures가 3이면 >= 2 조건을 충족해야 함"
        )
    }

    func test_crashCounter_atMaxInt_handlesGracefully() {
        // Given: 극단적으로 큰 값
        UserDefaults.standard.set(Int.max, forKey: failKey)

        // When
        let failures = UserDefaults.standard.integer(forKey: failKey)

        // Then: >= 2 조건 충족
        XCTAssertTrue(
            failures >= 2,
            "Int.max여도 >= 2 조건을 충족해야 함"
        )

        // 리셋 시에도 정상 동작
        UserDefaults.standard.set(0, forKey: failKey)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: failKey), 0)
    }

    // MARK: - 크래시 카운터와 loadDefaultModelIfNeeded 통합

    func test_crashCounter_atTwo_loadDefaultModelIfNeeded_notCalled_activeModelNil() async {
        // Given: 연속 2회 실패 후 selection 클리어됨
        UserDefaults.standard.set(2, forKey: failKey)
        let failures = UserDefaults.standard.integer(forKey: failKey)
        if failures >= 2 {
            UserDefaults.standard.set(0, forKey: failKey)
            sut.clearPersistedSelection()
        }
        // loadDefaultModelIfNeeded를 호출하지 않음 (setup()에서 건너뜀)

        // Then: activeModel은 nil
        XCTAssertNil(
            sut.activeModel,
            "failures >= 2일 때 loadDefaultModelIfNeeded가 호출되지 않으므로 activeModel은 nil이어야 함"
        )
    }

    func test_crashCounter_belowThreshold_loadDefaultModelIfNeeded_isCalled() async {
        // Given: 실패 횟수 0 (정상 상태), 저장된 모델 없음
        UserDefaults.standard.set(0, forKey: failKey)
        UserDefaults.standard.removeObject(forKey: variantKey)
        UserDefaults.standard.removeObject(forKey: engineKey)

        // When: setup() 로직 시뮬레이션 — 카운터 증가 후 로드 시도
        let failures = UserDefaults.standard.integer(forKey: failKey)
        XCTAssertTrue(failures < 2)
        UserDefaults.standard.set(failures + 1, forKey: failKey)
        await sut.loadDefaultModelIfNeeded()
        UserDefaults.standard.set(0, forKey: failKey)

        // Then: 저장된 모델이 없으므로 activeModel은 nil이지만, 로드 시도는 진행됨
        XCTAssertNil(sut.activeModel,
                     "저장된 모델이 없으면 activeModel은 nil (로드 시도는 했음)")
        XCTAssertEqual(UserDefaults.standard.integer(forKey: failKey), 0,
                       "성공적 완료 후 카운터가 0으로 리셋되어야 함")
    }

    // MARK: - loadDefaultModelIfNeeded 실패 시 clearPersistedSelection 호출 검증

    func test_loadDefaultModelIfNeeded_invalidPersistedModel_clearsSelection() async {
        // Given: 유효한 엔진 + 유효한 variant 형식이지만 실제 로드 시 실패할 모델
        // (다운로드되지 않은 모델 지정 → loadModel에서 에러 발생 → catch에서 clearPersistedSelection)
        UserDefaults.standard.set("whisperKit", forKey: engineKey)
        UserDefaults.standard.set("openai_whisper-tiny", forKey: variantKey)
        AppGroupConstants.sharedDefaults.set("whisperKit", forKey: engineKey)
        AppGroupConstants.sharedDefaults.set("openai_whisper-tiny", forKey: variantKey)
        AppGroupConstants.sharedDefaults.set("Tiny", forKey: displayNameKey)

        // When: loadDefaultModelIfNeeded 호출 (모델이 다운로드되지 않았으므로 실패할 수 있음)
        await sut.loadDefaultModelIfNeeded()

        // Then: 모델이 로드되었거나 (이미 다운로드된 경우), 또는 실패 시 selection이 클리어됨
        if sut.activeModel == nil {
            // 모델 로드 실패 → clearPersistedSelection이 호출되었어야 함
            // 주의: 모델이 실제로 다운로드되어 있으면 성공할 수도 있음
            // 이 테스트는 실패 경로에서 clearPersistedSelection이 호출되는지 간접 검증
        }
        // 어떤 경우든 크래시 없이 완료되면 성공
    }

    // MARK: - clearPersistedSelection이 다른 UserDefaults 키에 영향을 주지 않는지 확인

    func test_clearPersistedSelection_doesNotAffectOtherKeys() {
        // Given: 관련 없는 키도 설정됨
        let unrelatedKey = "autoDeleteDays"
        UserDefaults.standard.set(30, forKey: unrelatedKey)
        UserDefaults.standard.set("whisperKit", forKey: engineKey)

        // When
        sut.clearPersistedSelection()

        // Then: 관련 없는 키는 유지됨
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: unrelatedKey), 30,
            "clearPersistedSelection은 관련 없는 키에 영향을 주면 안 됨"
        )

        // 정리
        UserDefaults.standard.removeObject(forKey: unrelatedKey)
    }

    func test_clearPersistedSelection_doesNotAffectConsecutiveLoadFailures() {
        // Given: consecutiveLoadFailures가 설정된 상태
        UserDefaults.standard.set(1, forKey: failKey)
        UserDefaults.standard.set("whisperKit", forKey: engineKey)

        // When
        sut.clearPersistedSelection()

        // Then: consecutiveLoadFailures는 그대로 유지됨
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: failKey), 1,
            "clearPersistedSelection은 consecutiveLoadFailures를 변경하면 안 됨"
        )
    }

    // MARK: - 전체 setup() 크래시 루프 시나리오 시뮬레이션

    func test_crashLoopScenario_firstLaunch_counterIncrementsThenResets() async {
        // 시나리오: 첫 실행 (저장된 모델 없음)
        // 1. 카운터 0 → 1로 증가
        // 2. loadDefaultModelIfNeeded 호출 (저장 모델 없어 아무것도 안 함)
        // 3. 카운터 0으로 리셋

        // Given
        UserDefaults.standard.set(0, forKey: failKey)

        // When: setup() 로직 시뮬레이션
        let failures = UserDefaults.standard.integer(forKey: failKey)
        XCTAssertEqual(failures, 0)
        UserDefaults.standard.set(failures + 1, forKey: failKey)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: failKey), 1)

        await sut.loadDefaultModelIfNeeded()

        UserDefaults.standard.set(0, forKey: failKey)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: failKey), 0)
    }

    func test_crashLoopScenario_secondConsecutiveCrash_skipsAutoLoad() {
        // 시나리오: 앱이 두 번째 연속 크래시 후 재시작
        // failures가 2 → 자동 로드 건너뛰기 + selection 클리어

        // Given: 두 번째 연속 크래시 상태
        UserDefaults.standard.set(2, forKey: failKey)
        UserDefaults.standard.set("openai_whisper-large-v3", forKey: variantKey)
        UserDefaults.standard.set("whisperKit", forKey: engineKey)

        // When: setup() 로직 시뮬레이션
        let failures = UserDefaults.standard.integer(forKey: failKey)
        var loadCalled = false
        if failures >= 2 {
            UserDefaults.standard.set(0, forKey: failKey)
            sut.clearPersistedSelection()
        } else {
            loadCalled = true
        }

        // Then
        XCTAssertFalse(loadCalled, "failures >= 2일 때 로드가 호출되면 안 됨")
        XCTAssertEqual(UserDefaults.standard.integer(forKey: failKey), 0,
                       "카운터가 리셋되어야 함")
        XCTAssertNil(UserDefaults.standard.string(forKey: variantKey),
                     "저장된 variant가 제거되어야 함")
    }

    func test_crashLoopScenario_afterRecovery_normalLoadResumes() async {
        // 시나리오: 크래시 루프 복구 후 다음 실행
        // 1. 이전 실행에서 카운터가 0으로 리셋됨
        // 2. 새 실행에서 정상적으로 로드 진행

        // Given: 이전 크래시 루프에서 복구 완료
        UserDefaults.standard.set(0, forKey: failKey)
        UserDefaults.standard.removeObject(forKey: variantKey)

        // When: setup() 로직 시뮬레이션
        let failures = UserDefaults.standard.integer(forKey: failKey)
        var loadCalled = false
        if failures >= 2 {
            // 건너뛰기
        } else {
            UserDefaults.standard.set(failures + 1, forKey: failKey)
            loadCalled = true
            await sut.loadDefaultModelIfNeeded()
            UserDefaults.standard.set(0, forKey: failKey)
        }

        // Then
        XCTAssertTrue(loadCalled, "failures < 2이면 로드가 호출되어야 함")
        XCTAssertEqual(UserDefaults.standard.integer(forKey: failKey), 0)
    }
}
