#if os(iOS)
import XCTest
@testable import Writ

// MARK: - LiveActivityManager Phase Tests

/// LiveActivityManager 상태머신의 phase 전이를 검증한다.
/// ActivityKit API(Activity.request 등)는 시뮬레이터에서 동작하지 않으므로
/// 상태 전이 로직과 guard 조건만 검증한다.
@MainActor
final class LiveActivityManagerPhaseTests: XCTestCase {

    private var sut: LiveActivityManager!

    override func setUp() {
        super.setUp()
        sut = LiveActivityManager()
    }

    override func tearDown() {
        sut.end() // 타이머 정리
        sut = nil
        super.tearDown()
    }

    // MARK: - 초기 상태

    func testInitialPhase_isIdle() {
        XCTAssertEqual(sut.phase, .idle, "초기 phase는 .idle이어야 함")
    }

    // MARK: - idle -> recording 전이

    func testStartRecording_fromIdle_transitionsToRecording() {
        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording)
    }

    func testStartRecording_fromRecording_isIgnored() {
        // 이미 recording 상태에서 다시 startRecording 호출하면 무시
        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording)

        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording, "중복 startRecording은 무시되어야 함")
    }

    func testStartRecording_fromTranscribing_isIgnored() {
        // recording -> transcribing 상태에서 startRecording 호출하면 무시
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .transcribing, "transcribing 중 startRecording은 무시되어야 함")
    }

    // MARK: - recording -> transcribing 전이

    func testTransitionToTranscribing_fromRecording_transitionsToTranscribing() {
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing)
    }

    func testTransitionToTranscribing_fromIdle_isIgnored() {
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .idle, "idle에서 transitionToTranscribing은 무시되어야 함")
    }

    func testTransitionToTranscribing_fromTranscribing_isIgnored() {
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing)

        // 이미 transcribing인데 다시 호출
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing, "중복 transitionToTranscribing은 무시되어야 함")
    }

    // MARK: - transcribing -> completed -> idle 전이

    func testTransitionToCompleted_fromTranscribing_transitionsToCompletedOrIdle() {
        // transitionToCompleted는 currentActivity 유무에 따라:
        // - currentActivity == nil: 동기적으로 idle 전환
        // - currentActivity != nil: 동기적으로 completed, 비동기로 idle 전환
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        sut.transitionToCompleted()

        let phase = sut.phase
        XCTAssertTrue(
            phase == .idle || phase == .completed,
            "transitionToCompleted 후 idle 또는 completed여야 함, 실제: \(phase)"
        )
    }

    func testTransitionToCompleted_fromIdle_isIgnored() {
        sut.transitionToCompleted()
        XCTAssertEqual(sut.phase, .idle, "idle에서 transitionToCompleted은 무시되어야 함")
    }

    func testTransitionToCompleted_fromRecording_isIgnored() {
        sut.startRecording(startDate: Date())
        sut.transitionToCompleted()
        XCTAssertEqual(sut.phase, .recording, "recording에서 transitionToCompleted은 무시되어야 함")
    }

    // MARK: - end() (어떤 phase에서든 idle로 전환)

    func testEnd_fromIdle_remainsIdle() {
        sut.end()
        XCTAssertEqual(sut.phase, .idle)
    }

    func testEnd_fromRecording_transitionsToIdle() {
        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording)

        sut.end()
        XCTAssertEqual(sut.phase, .idle)
    }

    func testEnd_fromTranscribing_transitionsToIdle() {
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.end()
        XCTAssertEqual(sut.phase, .idle)
    }

    func testEnd_calledMultipleTimes_remainsIdle() {
        sut.startRecording(startDate: Date())
        sut.end()
        sut.end()
        sut.end()
        XCTAssertEqual(sut.phase, .idle, "end()를 여러 번 호출해도 idle 유지")
    }

    // MARK: - 전체 라이프사이클

    func testFullLifecycle_idleToRecordingToTranscribingToCompleted() {
        XCTAssertEqual(sut.phase, .idle)

        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording)

        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.transitionToCompleted()
        // currentActivity 유무에 따라 completed 또는 idle
        let phase = sut.phase
        XCTAssertTrue(
            phase == .idle || phase == .completed,
            "전체 사이클 후 idle 또는 completed여야 함, 실제: \(phase)"
        )
    }

    func testFullLifecycle_canRestartAfterCompletion() {
        // 완료 후 다시 녹음 시작 가능한지 검증
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        sut.transitionToCompleted()
        // end()로 확실히 idle 전환 (currentActivity가 있었을 수 있으므로)
        sut.end()
        XCTAssertEqual(sut.phase, .idle)

        // 다시 시작
        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording)
    }

    func testFullLifecycle_canRestartAfterEnd() {
        // end()로 취소 후 다시 녹음 시작 가능한지 검증
        sut.startRecording(startDate: Date())
        sut.end()
        XCTAssertEqual(sut.phase, .idle)

        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording)
    }

    func testLifecycle_cancelDuringTranscribing() {
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing)

        sut.end()
        XCTAssertEqual(sut.phase, .idle, "전사 중 end()로 취소 가능해야 함")
    }

    // MARK: - 잘못된 전이 순서 (skipping phases)

    func testInvalidTransition_idleToTranscribing_isRejected() {
        // idle에서 바로 transcribing으로 갈 수 없다
        XCTAssertEqual(sut.phase, .idle)
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .idle, "idle -> transcribing 직접 전이는 불가")
    }

    func testInvalidTransition_idleToCompleted_isRejected() {
        // idle에서 바로 completed로 갈 수 없다
        XCTAssertEqual(sut.phase, .idle)
        sut.transitionToCompleted()
        XCTAssertEqual(sut.phase, .idle, "idle -> completed 직접 전이는 불가")
    }

    func testInvalidTransition_recordingToCompleted_isRejected() {
        // recording에서 바로 completed로 갈 수 없다 (transcribing을 거쳐야 함)
        sut.startRecording(startDate: Date())
        sut.transitionToCompleted()
        XCTAssertEqual(sut.phase, .recording, "recording -> completed 직접 전이는 불가")
    }

    // MARK: - updateProgress guard 조건

    func testUpdateProgress_fromIdle_isIgnored() {
        // idle 상태에서 updateProgress 호출은 무시 (크래시 없이)
        sut.updateProgress(0.5)
        XCTAssertEqual(sut.phase, .idle)
    }

    func testUpdateProgress_fromRecording_isIgnored() {
        sut.startRecording(startDate: Date())
        sut.updateProgress(0.5)
        XCTAssertEqual(sut.phase, .recording, "recording 중 updateProgress는 phase를 변경하지 않음")
    }

    func testUpdateProgress_fromTranscribing_doesNotChangePhase() {
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        sut.updateProgress(0.5)
        XCTAssertEqual(sut.phase, .transcribing, "updateProgress는 phase를 변경하지 않아야 함")
    }

}

// MARK: - LiveActivityManager.Phase Tests

@MainActor
final class LiveActivityManagerPhaseEnumTests: XCTestCase {

    // MARK: - RawValue

    func testPhase_rawValues() {
        XCTAssertEqual(LiveActivityManager.Phase.idle.rawValue, "idle")
        XCTAssertEqual(LiveActivityManager.Phase.recording.rawValue, "recording")
        XCTAssertEqual(LiveActivityManager.Phase.transcribing.rawValue, "transcribing")
        XCTAssertEqual(LiveActivityManager.Phase.completed.rawValue, "completed")
    }

    func testPhase_initFromRawValue() {
        XCTAssertEqual(LiveActivityManager.Phase(rawValue: "idle"), .idle)
        XCTAssertEqual(LiveActivityManager.Phase(rawValue: "recording"), .recording)
        XCTAssertEqual(LiveActivityManager.Phase(rawValue: "transcribing"), .transcribing)
        XCTAssertEqual(LiveActivityManager.Phase(rawValue: "completed"), .completed)
    }

    func testPhase_initFromInvalidRawValue_returnsNil() {
        XCTAssertNil(LiveActivityManager.Phase(rawValue: "invalid"))
        XCTAssertNil(LiveActivityManager.Phase(rawValue: ""))
        XCTAssertNil(LiveActivityManager.Phase(rawValue: "Idle")) // 대소문자 구분
    }

    func testPhase_allCases_hasFourCases() {
        // idle, recording, transcribing, completed
        let allCases: [LiveActivityManager.Phase] = [.idle, .recording, .transcribing, .completed]
        let uniqueRawValues = Set(allCases.map(\.rawValue))
        XCTAssertEqual(uniqueRawValues.count, 4)
    }
}

// MARK: - LiveActivityManager State Machine Edge Cases

@MainActor
final class LiveActivityManagerEdgeCaseTests: XCTestCase {

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

    // MARK: - startDate 전달 확인

    func testStartRecording_acceptsDistantPastDate() {
        // 과거 날짜도 크래시 없이 수용
        sut.startRecording(startDate: Date.distantPast)
        XCTAssertEqual(sut.phase, .recording)
    }

    func testStartRecording_acceptsDistantFutureDate() {
        // 미래 날짜도 크래시 없이 수용
        sut.startRecording(startDate: Date.distantFuture)
        XCTAssertEqual(sut.phase, .recording)
    }

    // MARK: - 빠른 연속 전이

    func testRapidSuccessiveTransitions_doNotCrash() {
        // 빠르게 전체 사이클을 여러 번 반복
        // transitionToCompleted()는 currentActivity가 있을 때 비동기로 idle 전환하므로
        // end()로 동기적 idle 전환을 보장한 후 다음 사이클 시작
        for _ in 0..<10 {
            sut.startRecording(startDate: Date())
            sut.transitionToTranscribing()
            sut.transitionToCompleted()
            // currentActivity가 있을 수 있으므로 end()로 확실히 idle 전환
            sut.end()
        }
        XCTAssertEqual(sut.phase, .idle, "10회 반복 사이클 후 idle 상태여야 함")
    }

    func testRapidEndCalls_doNotCrash() {
        sut.startRecording(startDate: Date())
        // end()를 빠르게 연속 호출
        for _ in 0..<100 {
            sut.end()
        }
        XCTAssertEqual(sut.phase, .idle)
    }

    // MARK: - end() 후 상태 완전 초기화

    func testEnd_afterRecording_allowsFullCycleRestart() {
        // 첫 번째 사이클
        sut.startRecording(startDate: Date())
        sut.end()

        // 두 번째 사이클: 전체 경로 수행 가능
        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording)
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing)
        sut.transitionToCompleted()
        // currentActivity가 있으면 비동기로 idle 전환, 없으면 동기로 idle 전환
        // 동기적으로는 completed 또는 idle일 수 있음
        let phase = sut.phase
        XCTAssertTrue(
            phase == .idle || phase == .completed,
            "transitionToCompleted 후 idle 또는 completed여야 함, 실제: \(phase)"
        )
    }

    // MARK: - 혼합 잘못된 호출

    func testMixedInvalidCalls_stateRemainsConsistent() {
        XCTAssertEqual(sut.phase, .idle)

        // idle에서 모든 잘못된 전이 시도
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .idle)
        sut.transitionToCompleted()
        XCTAssertEqual(sut.phase, .idle)
        sut.updateProgress(0.5)
        XCTAssertEqual(sut.phase, .idle)

        // recording으로 전이 후 잘못된 호출
        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording)
        sut.transitionToCompleted() // 잘못된 전이
        XCTAssertEqual(sut.phase, .recording)
        sut.startRecording(startDate: Date()) // 중복 시작
        XCTAssertEqual(sut.phase, .recording)

        // 올바른 전이
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing)

        // transcribing에서 잘못된 호출
        sut.startRecording(startDate: Date()) // 잘못된 전이
        XCTAssertEqual(sut.phase, .transcribing)
        sut.transitionToTranscribing() // 중복 전이
        XCTAssertEqual(sut.phase, .transcribing)

        // 완료 후 end()로 확실히 idle 전환
        sut.transitionToCompleted()
        sut.end()
        XCTAssertEqual(sut.phase, .idle)
    }

    // MARK: - ObservableObject 적합성

    func testLiveActivityManager_isObservableObject() {
        // ObservableObject 적합성 확인 (objectWillChange가 존재)
        let publisher = sut.objectWillChange
        XCTAssertNotNil(publisher, "ObservableObject의 objectWillChange publisher가 있어야 함")
    }
}

// MARK: - AppState LiveActivityManager 연동 검증

@MainActor
final class AppStateLiveActivityIntegrationTests: XCTestCase {

    func testAppState_hasLiveActivityManager() {
        let appState = AppState.shared
        XCTAssertNotNil(appState.liveActivityManager, "AppState에 liveActivityManager가 있어야 함")
    }

    func testAppState_liveActivityManager_initialPhaseIsIdle() {
        let appState = AppState.shared
        // setup() 후 cleanupOrphanedActivities()가 호출되므로 idle이어야 함
        // (단, setup()이 호출되지 않은 경우에도 초기값은 idle)
        XCTAssertEqual(
            appState.liveActivityManager.phase, .idle,
            "liveActivityManager의 초기 phase는 idle이어야 함"
        )
    }

    func testAppState_liveActivityManager_endMethod_isCallable() {
        // LiveActivityIntents에서 appState.liveActivityManager.end() 호출 검증
        let appState = AppState.shared
        appState.liveActivityManager.end()
        XCTAssertEqual(appState.liveActivityManager.phase, .idle)
    }
}
#endif
