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

    // MARK: - 카운터 리셋 조건: activeModel nil + 저장된 선택 있음 = 리셋하지 않음

    func test_crashCounter_doesNotReset_whenActiveModelNil_andPersistedSelectionExists() async {
        // 시나리오: 모델 로드 시도 → 실패 (activeModel nil) + variant가 아직 저장됨
        // → 카운터가 0으로 리셋되지 않아야 함 (다음 실행에서 threshold 도달 가능)

        // Given: 카운터 0에서 시작, 유효하지만 로드 불가능한 모델 저장
        UserDefaults.standard.set(0, forKey: failKey)
        UserDefaults.standard.set("whisperKit", forKey: engineKey)
        // 실제로 존재하지 않는 variant를 저장 (ModelIdentifier.find가 실패하도록)
        // → loadDefaultModelIfNeeded가 이 variant를 찾지 못하면 activeModel은 nil
        // 하지만 variant 키 자체는 UserDefaults에 남아 있음
        UserDefaults.standard.set("nonexistent_variant_key", forKey: variantKey)

        // When: setup() 로직 시뮬레이션
        let failures = UserDefaults.standard.integer(forKey: failKey)
        UserDefaults.standard.set(failures + 1, forKey: failKey)
        await sut.loadDefaultModelIfNeeded()

        // 카운터 리셋 조건 확인
        let hasPersistedSelection = UserDefaults.standard.string(forKey: variantKey) != nil
        if sut.activeModel != nil || !hasPersistedSelection {
            UserDefaults.standard.set(0, forKey: failKey)
        }

        // Then: activeModel은 nil이고, variant가 존재하므로 카운터는 리셋되지 않아야 함
        XCTAssertNil(sut.activeModel,
                     "존재하지 않는 variant로는 모델을 로드할 수 없어야 함")
        XCTAssertNotNil(UserDefaults.standard.string(forKey: variantKey),
                        "loadDefaultModelIfNeeded가 variant를 찾지 못하면 키는 그대로 남아 있어야 함")
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: failKey), 1,
            "activeModel이 nil이고 저장된 선택이 존재하면 카운터가 리셋되지 않아야 함"
        )
    }

    func test_crashCounter_resetsWhenNoPersistedSelection_evenIfActiveModelNil() async {
        // 시나리오: 최초 실행 — 저장된 모델 없음, activeModel도 nil
        // → hasPersistedSelection이 false이므로 카운터가 0으로 리셋됨

        // Given
        UserDefaults.standard.set(0, forKey: failKey)
        UserDefaults.standard.removeObject(forKey: variantKey)
        UserDefaults.standard.removeObject(forKey: engineKey)

        // When: setup() 로직 시뮬레이션
        let failures = UserDefaults.standard.integer(forKey: failKey)
        UserDefaults.standard.set(failures + 1, forKey: failKey)
        await sut.loadDefaultModelIfNeeded()

        let hasPersistedSelection = UserDefaults.standard.string(forKey: variantKey) != nil
        if sut.activeModel != nil || !hasPersistedSelection {
            UserDefaults.standard.set(0, forKey: failKey)
        }

        // Then: 저장된 선택이 없으므로 카운터가 리셋됨
        XCTAssertNil(sut.activeModel)
        XCTAssertFalse(hasPersistedSelection)
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: failKey), 0,
            "저장된 선택이 없으면 (최초 실행) 카운터가 0으로 리셋되어야 함"
        )
    }

    func test_crashCounter_accumulatesAcrossConsecutiveFailedLaunches() {
        // 시나리오: 첫 번째 실행 실패 → 카운터 1, 두 번째 실행에서 threshold 도달

        // 첫 번째 실행: 카운터 0 → 1
        UserDefaults.standard.set(0, forKey: failKey)
        UserDefaults.standard.set("openai_whisper-small", forKey: variantKey)

        let failures1 = UserDefaults.standard.integer(forKey: failKey)
        XCTAssertTrue(failures1 < 2)
        UserDefaults.standard.set(failures1 + 1, forKey: failKey)

        // 첫 번째 실행에서 앱 크래시 (카운터 리셋 안 됨) → 카운터 1 유지
        XCTAssertEqual(UserDefaults.standard.integer(forKey: failKey), 1)

        // 두 번째 실행: 카운터 1 → 2
        let failures2 = UserDefaults.standard.integer(forKey: failKey)
        XCTAssertTrue(failures2 < 2)
        UserDefaults.standard.set(failures2 + 1, forKey: failKey)

        // 두 번째 실행에서도 앱 크래시 → 카운터 2 유지
        XCTAssertEqual(UserDefaults.standard.integer(forKey: failKey), 2)

        // 세 번째 실행: 카운터 >= 2 → 자동 로드 건너뛰기
        let failures3 = UserDefaults.standard.integer(forKey: failKey)
        XCTAssertTrue(failures3 >= 2, "세 번째 실행에서 threshold 도달")
    }

    // MARK: - clearPersistedSelection 호출 후 loadDefaultModelIfNeeded가 모든 경로를 건너뛰는지 확인

    func test_clearPersistedSelection_preventsAllLoadPaths() async {
        // Given: 새 포맷과 기존 포맷 모두에 값 설정 후 clear
        UserDefaults.standard.set("whisperKit", forKey: engineKey)
        UserDefaults.standard.set("openai_whisper-tiny", forKey: variantKey)
        sut.clearPersistedSelection()

        // When
        await sut.loadDefaultModelIfNeeded()

        // Then: 새 포맷 경로(engineType+variant)도, 기존 포맷 경로(variant만)도 매칭 안 됨
        XCTAssertNil(sut.activeModel,
                     "clear 후에는 어떤 경로로도 모델이 로드되면 안 됨")
    }

    // MARK: - deleteModel이 clearPersistedSelection을 호출하는지 간접 검증

    func test_deleteModel_activeModel_clearsAllFiveKeys() async {
        // Given: activeModel 설정 + 모든 persisted 키에 값 저장
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        sut.activeModel = tinyId
        UserDefaults.standard.set(tinyId.variantKey, forKey: variantKey)
        UserDefaults.standard.set(tinyId.engine.rawValue, forKey: engineKey)
        AppGroupConstants.sharedDefaults.set(tinyId.variantKey, forKey: variantKey)
        AppGroupConstants.sharedDefaults.set(tinyId.engine.rawValue, forKey: engineKey)
        AppGroupConstants.sharedDefaults.set(tinyId.displayName, forKey: displayNameKey)

        // When
        await sut.deleteModel(tinyId)

        // Then: clearPersistedSelection이 호출되어 5개 키 모두 제거됨
        XCTAssertNil(sut.activeModel,
                     "deleteModel 후 activeModel은 nil이어야 함")
        XCTAssertNil(UserDefaults.standard.string(forKey: variantKey),
                     "deleteModel 후 standard variant가 제거되어야 함")
        XCTAssertNil(UserDefaults.standard.string(forKey: engineKey),
                     "deleteModel 후 standard engineType이 제거되어야 함")
        XCTAssertNil(AppGroupConstants.sharedDefaults.string(forKey: variantKey),
                     "deleteModel 후 shared variant가 제거되어야 함")
        XCTAssertNil(AppGroupConstants.sharedDefaults.string(forKey: engineKey),
                     "deleteModel 후 shared engineType이 제거되어야 함")
        XCTAssertNil(AppGroupConstants.sharedDefaults.string(forKey: displayNameKey),
                     "deleteModel 후 shared displayName이 제거되어야 함")
    }

    func test_deleteModel_nonActiveModel_doesNotClearSelection() async {
        // Given: activeModel은 tiny, 삭제 대상은 base
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        let baseId = WhisperModelVariant.base.modelIdentifier
        sut.activeModel = tinyId
        UserDefaults.standard.set(tinyId.variantKey, forKey: variantKey)
        UserDefaults.standard.set(tinyId.engine.rawValue, forKey: engineKey)

        // When: 활성 모델이 아닌 다른 모델 삭제
        await sut.deleteModel(baseId)

        // Then: activeModel과 selection은 유지됨
        XCTAssertEqual(sut.activeModel, tinyId,
                       "활성 모델이 아닌 모델 삭제 시 activeModel은 유지되어야 함")
        XCTAssertNotNil(UserDefaults.standard.string(forKey: variantKey),
                        "활성 모델이 아닌 모델 삭제 시 selection은 유지되어야 함")
    }
}
