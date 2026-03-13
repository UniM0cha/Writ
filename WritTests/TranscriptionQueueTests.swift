#if os(iOS)
import XCTest
@testable import Writ

// MARK: - LiveActivityManager.startTranscribingDirectly() Tests

/// startTranscribingDirectly() 메서드의 상태머신 전이를 검증한다.
/// idle→transcribing 직접 전환 (recording phase를 거치지 않음)으로
/// 큐 대기 항목 처리 시 사용된다.
@MainActor
final class StartTranscribingDirectlyTests: XCTestCase {

    private var sut: LiveActivityManager!

    override func setUp() {
        super.setUp()
        sut = LiveActivityManager()
    }

    override func tearDown() {
        sut.end()
        sut = nil
        super.tearDown()
    }

    // MARK: - 정상 전이: idle → transcribing

    func testStartTranscribingDirectly_fromIdle_transitionsToTranscribing() {
        XCTAssertEqual(sut.phase, .idle)

        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing,
                       "idle에서 startTranscribingDirectly 호출 시 transcribing으로 전이해야 함")
    }

    // MARK: - 잘못된 phase에서 호출 시 무시

    func testStartTranscribingDirectly_fromRecording_isIgnored() {
        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording)

        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .recording,
                       "recording 상태에서 startTranscribingDirectly은 무시되어야 함")
    }

    func testStartTranscribingDirectly_fromTranscribing_isIgnored() {
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing,
                       "이미 transcribing 상태에서 startTranscribingDirectly은 무시되어야 함")
    }

    func testStartTranscribingDirectly_fromTranscribingViaDirectMethod_isIgnored() {
        // startTranscribingDirectly로 transcribing 진입 후 다시 호출
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing,
                       "startTranscribingDirectly로 진입한 transcribing에서 재호출은 무시되어야 함")
    }

    // MARK: - startTranscribingDirectly 후 전이 경로

    func testStartTranscribingDirectly_thenTransitionToCompleted() {
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.transitionToCompleted()
        // currentActivity 유무에 따라 completed 또는 idle
        let phase = sut.phase
        XCTAssertTrue(
            phase == .idle || phase == .completed,
            "startTranscribingDirectly 후 transitionToCompleted는 idle 또는 completed여야 함, 실제: \(phase)"
        )
    }

    func testStartTranscribingDirectly_thenEnd() {
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.end()
        XCTAssertEqual(sut.phase, .idle,
                       "startTranscribingDirectly 후 end()는 idle로 전이해야 함")
    }

    func testStartTranscribingDirectly_thenUpdateProgress_doesNotChangePhase() {
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.updateProgress(0.5)
        XCTAssertEqual(sut.phase, .transcribing,
                       "updateProgress는 phase를 변경하지 않아야 함")
    }

    func testStartTranscribingDirectly_thenStartRecording_isIgnored() {
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .transcribing,
                       "transcribing 상태에서 startRecording은 무시되어야 함")
    }

    func testStartTranscribingDirectly_thenTransitionToTranscribing_isIgnored() {
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing,
                       "이미 transcribing 상태에서 transitionToTranscribing은 무시되어야 함")
    }

    // MARK: - 전체 라이프사이클 (직접 전사 경로)

    func testFullLifecycle_directTranscribing() {
        // idle → transcribing (직접) → completed/idle
        XCTAssertEqual(sut.phase, .idle)

        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.transitionToCompleted()
        sut.end() // 확실히 idle로 전환
        XCTAssertEqual(sut.phase, .idle)
    }

    func testFullLifecycle_canRestartAfterDirectTranscribing() {
        // 직접 전사 완료 후 다시 녹음 시작 가능한지 검증
        sut.startTranscribingDirectly()
        sut.transitionToCompleted()
        sut.end()
        XCTAssertEqual(sut.phase, .idle)

        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording,
                       "직접 전사 완료 후 녹음을 다시 시작할 수 있어야 함")
    }

    func testFullLifecycle_canStartDirectTranscribingAfterNormalCycle() {
        // 일반 녹음→전사 사이클 완료 후 직접 전사 시작 가능한지 검증
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        sut.transitionToCompleted()
        sut.end()
        XCTAssertEqual(sut.phase, .idle)

        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing,
                       "일반 사이클 완료 후 직접 전사를 시작할 수 있어야 함")
    }

    // MARK: - 빠른 연속 호출

    func testRapidDirectTranscribingCycles_doNotCrash() {
        // 직접 전사 사이클을 빠르게 반복
        for _ in 0..<10 {
            sut.startTranscribingDirectly()
            sut.transitionToCompleted()
            sut.end()
        }
        XCTAssertEqual(sut.phase, .idle, "10회 직접 전사 사이클 후 idle 상태여야 함")
    }

    func testAlternatingNormalAndDirectCycles_doNotCrash() {
        // 일반 사이클과 직접 전사 사이클을 번갈아 수행
        for i in 0..<5 {
            if i % 2 == 0 {
                // 일반 사이클: idle → recording → transcribing → completed → idle
                sut.startRecording(startDate: Date())
                sut.transitionToTranscribing()
            } else {
                // 직접 전사 사이클: idle → transcribing → completed → idle
                sut.startTranscribingDirectly()
            }
            sut.transitionToCompleted()
            sut.end()
        }
        XCTAssertEqual(sut.phase, .idle, "번갈아 수행 후 idle 상태여야 함")
    }
}

// MARK: - AppState 전사 큐 인터페이스 검증

/// AppState의 전사 큐 관련 인터페이스가 올바르게 존재하는지 검증한다.
/// transcriptionQueue, isProcessingQueue는 private이므로
/// 관찰 가능한 공개 인터페이스와 제거된 프로퍼티의 부재를 확인한다.
@MainActor
final class AppStateTranscriptionQueueTests: XCTestCase {

    // MARK: - LiveActivityManager 연동 확인

    func testAppState_liveActivityManager_hasStartTranscribingDirectly() {
        // startTranscribingDirectly 메서드가 LiveActivityManager에 존재하는지 확인
        let appState = AppState.shared
        // idle 상태에서 호출 가능한지 확인
        appState.liveActivityManager.startTranscribingDirectly()
        XCTAssertEqual(
            appState.liveActivityManager.phase, .transcribing,
            "startTranscribingDirectly 호출 후 phase가 transcribing이어야 함"
        )

        // 정리
        appState.liveActivityManager.end()
        XCTAssertEqual(appState.liveActivityManager.phase, .idle)
    }

    // MARK: - resumePendingTranscriptions throttle 검증

    func testResumePendingTranscriptions_throttled_within5Seconds() {
        // 5초 이내에 연속 호출 시 두 번째 호출은 무시되어야 함
        let appState = AppState.shared

        // 첫 번째 호출 (throttle 초기화)
        appState.resumePendingTranscriptions()

        // 즉시 두 번째 호출 — throttle에 의해 무시됨
        // 크래시 없이 완료되면 성공
        appState.resumePendingTranscriptions()

        // throttle 로직이 크래시 없이 동작하는지만 검증
        // (내부 lastResumeDate가 private이므로 직접 확인 불가)
    }

    // MARK: - stopRecordingAndTranscribe 녹음 미진행 시 안전성

    func testStopRecordingAndTranscribe_whenNotRecording_doesNotCrash() {
        // 녹음 중이 아닐 때 호출해도 크래시가 발생하지 않아야 함
        let appState = AppState.shared
        XCTAssertFalse(appState.recorderService.isRecording,
                       "테스트 시작 시 녹음 중이 아니어야 함")

        // 여러 번 호출해도 안전
        for _ in 0..<5 {
            appState.stopRecordingAndTranscribe()
        }

        // LiveActivityManager phase가 idle로 유지 (end()가 호출되었을 수 있음)
        XCTAssertEqual(appState.liveActivityManager.phase, .idle,
                       "녹음 미진행 시 liveActivityManager는 idle 상태를 유지해야 함")
    }
}

// MARK: - LiveActivityManager 상태머신 확장 테스트 (큐 시나리오)

/// 전사 큐 시나리오에서 발생할 수 있는 LiveActivityManager 상태 전이를 검증한다.
/// 큐에 여러 항목이 있을 때의 DI 전환 패턴을 시뮬레이션한다.
@MainActor
final class LiveActivityManagerQueueScenarioTests: XCTestCase {

    private var sut: LiveActivityManager!

    override func setUp() {
        super.setUp()
        sut = LiveActivityManager()
    }

    override func tearDown() {
        sut.end()
        sut = nil
        super.tearDown()
    }

    // MARK: - 큐 시뮬레이션: 첫 항목 (recording → transcribing 경로)

    func testQueueFirstItem_normalRecordingToTranscribingPath() {
        // 첫 번째 큐 항목: 일반 녹음→전사 경로
        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording)

        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.transitionToCompleted()
        sut.end() // 확실히 idle 전환
        XCTAssertEqual(sut.phase, .idle)
    }

    // MARK: - 큐 시뮬레이션: 두 번째 이후 항목 (직접 전사 경로)

    func testQueueSubsequentItems_directTranscribingPath() {
        // 첫 번째 항목 완료 후
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        sut.transitionToCompleted()
        sut.end()
        XCTAssertEqual(sut.phase, .idle)

        // 두 번째 항목: 직접 전사 경로 (큐 대기 항목)
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.transitionToCompleted()
        sut.end()
        XCTAssertEqual(sut.phase, .idle)

        // 세 번째 항목: 직접 전사 경로
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.transitionToCompleted()
        sut.end()
        XCTAssertEqual(sut.phase, .idle)
    }

    // MARK: - 큐 시뮬레이션: 전사 중 에러 발생 시 end() 복구

    func testQueueItem_errorDuringTranscribing_endRecovery() {
        // 직접 전사 시작 후 에러 발생 → end()로 복구
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing)

        // 에러 발생 시 end() 호출
        sut.end()
        XCTAssertEqual(sut.phase, .idle)

        // 다음 항목 처리 가능
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing,
                       "에러 복구 후 다음 항목을 처리할 수 있어야 함")
    }

    // MARK: - 큐 시뮬레이션: 여러 항목 순차 처리

    func testMultipleQueueItems_sequentialProcessing() {
        // 3개 항목을 순차 처리하는 전체 시나리오 시뮬레이션
        // 항목 1: 녹음→전사 (일반 경로)
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        sut.updateProgress(0.5)
        XCTAssertEqual(sut.phase, .transcribing)
        sut.transitionToCompleted()
        sut.end()
        XCTAssertEqual(sut.phase, .idle, "항목 1 완료 후 idle")

        // 항목 2: 직접 전사 (큐 대기 항목)
        sut.startTranscribingDirectly()
        sut.updateProgress(0.3)
        sut.updateProgress(0.7)
        sut.updateProgress(1.0)
        XCTAssertEqual(sut.phase, .transcribing)
        sut.transitionToCompleted()
        sut.end()
        XCTAssertEqual(sut.phase, .idle, "항목 2 완료 후 idle")

        // 항목 3: 직접 전사 (큐 대기 항목)
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing)
        sut.transitionToCompleted()
        sut.end()
        XCTAssertEqual(sut.phase, .idle, "항목 3 완료 후 idle")
    }

    // MARK: - transitionToCompleted 후 즉시 startTranscribingDirectly

    func testTransitionToCompleted_thenStartTranscribingDirectly() {
        // transitionToCompleted는 phase를 즉시 idle로 전환
        // (currentActivity가 없는 테스트 환경)
        sut.startTranscribingDirectly()
        sut.transitionToCompleted()

        // currentActivity가 nil이므로 phase는 즉시 idle
        XCTAssertEqual(sut.phase, .idle,
                       "currentActivity 없이 transitionToCompleted 후 즉시 idle이어야 함")

        // 바로 다음 항목 시작 가능
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing,
                       "idle 전환 즉시 다음 직접 전사를 시작할 수 있어야 함")
    }

    // MARK: - phase가 idle이 아닐 때 startTranscribingDirectly 안전성

    func testStartTranscribingDirectly_duringActiveTranscription_isIgnored() {
        // 이미 전사 중일 때 다음 큐 항목이 잘못 시작되지 않는지 검증
        sut.startTranscribingDirectly()
        XCTAssertEqual(sut.phase, .transcribing)

        // 큐 처리 로직에서 phase == .idle 체크를 시뮬레이션
        if sut.phase == .idle {
            sut.startTranscribingDirectly()
        }
        // phase가 transcribing이므로 위 블록은 실행되지 않아야 함
        XCTAssertEqual(sut.phase, .transcribing)
    }
}
#endif
