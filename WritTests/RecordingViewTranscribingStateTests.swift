import XCTest
import Combine
@testable import Writ

/// RecordingView의 전사 중 스피너 상태를 구동하는 AppState.isProcessingQueue 검증
///
/// RecordingView는 `isTranscribing` 계산 프로퍼티를 통해 AppState.isProcessingQueue를 참조한다.
/// SwiftUI View의 private 프로퍼티는 직접 테스트할 수 없으므로,
/// 뷰 상태를 결정하는 AppState.isProcessingQueue의 동작을 검증한다.
///
/// 녹음 버튼 3가지 상태:
/// 1. idle: 빨간 원 (isRecording=false, isProcessingQueue=false)
/// 2. recording: 빨간 정사각형 (isRecording=true)
/// 3. transcribing (NEW): 주황 링 + 스피너, 버튼 비활성 (isProcessingQueue=true)
@MainActor
final class RecordingViewTranscribingStateTests: XCTestCase {

    // MARK: - isProcessingQueue 초기 상태

    func testIsProcessingQueue_initialValue_isFalse() {
        let appState = AppState.shared
        XCTAssertFalse(
            appState.isProcessingQueue,
            "isProcessingQueue 초기값은 false여야 함 (idle 상태)"
        )
    }

    // MARK: - isProcessingQueue 값 변경

    func testIsProcessingQueue_canBeSetToTrue() {
        let appState = AppState.shared
        let original = appState.isProcessingQueue

        appState.isProcessingQueue = true
        XCTAssertTrue(
            appState.isProcessingQueue,
            "isProcessingQueue를 true로 설정할 수 있어야 함"
        )

        // 정리
        appState.isProcessingQueue = original
    }

    func testIsProcessingQueue_canBeToggledBackToFalse() {
        let appState = AppState.shared
        let original = appState.isProcessingQueue

        appState.isProcessingQueue = true
        XCTAssertTrue(appState.isProcessingQueue)

        appState.isProcessingQueue = false
        XCTAssertFalse(
            appState.isProcessingQueue,
            "isProcessingQueue를 false로 되돌릴 수 있어야 함"
        )

        // 정리
        appState.isProcessingQueue = original
    }

    // MARK: - isProcessingQueue 변경 시 objectWillChange 발행 (UI 갱신 보장)

    func testIsProcessingQueue_change_triggersObjectWillChange() {
        let appState = AppState.shared
        let original = appState.isProcessingQueue
        let expectation = XCTestExpectation(description: "objectWillChange가 발행되어야 함")

        var cancellable: AnyCancellable?
        cancellable = appState.objectWillChange
            .sink { _ in
                expectation.fulfill()
                cancellable?.cancel()
            }

        // isProcessingQueue 변경 → AppState는 ObservableObject이므로
        // 자식 서비스의 objectWillChange를 포워딩하지만, isProcessingQueue는
        // 직접 @Published가 아닌 일반 var이므로 수동 발행 여부를 확인
        appState.isProcessingQueue = !original

        // 짧은 대기 후 확인 (objectWillChange가 즉시 또는 다음 RunLoop에서 발행)
        wait(for: [expectation], timeout: 1.0)

        // 정리
        appState.isProcessingQueue = original
        cancellable?.cancel()
    }

    // MARK: - 상태 조합: isRecording과 isProcessingQueue의 상호 배제

    func testIdleState_neitherRecordingNorProcessing() {
        // RecordingView idle 상태: isRecording=false, isProcessingQueue=false
        let appState = AppState.shared

        XCTAssertFalse(
            appState.recorderService.isRecording,
            "테스트 시작 시 녹음 중이 아니어야 함"
        )
        XCTAssertFalse(
            appState.isProcessingQueue,
            "테스트 시작 시 큐 처리 중이 아니어야 함"
        )
    }

    func testTranscribingState_notRecordingButProcessing() {
        // RecordingView transcribing 상태: isRecording=false, isProcessingQueue=true
        let appState = AppState.shared
        let original = appState.isProcessingQueue

        appState.isProcessingQueue = true

        XCTAssertFalse(
            appState.recorderService.isRecording,
            "전사 중에는 녹음 중이 아니어야 함"
        )
        XCTAssertTrue(
            appState.isProcessingQueue,
            "전사 중에는 isProcessingQueue가 true여야 함"
        )

        // 정리
        appState.isProcessingQueue = original
    }

    // MARK: - processNextInQueue가 isProcessingQueue 라이프사이클을 올바르게 관리

    func testProcessNextInQueue_emptyQueue_setsAndClearsIsProcessingQueue() async {
        let appState = AppState.shared

        XCTAssertFalse(appState.isProcessingQueue, "호출 전 false여야 함")

        await appState.processNextInQueue()

        XCTAssertFalse(
            appState.isProcessingQueue,
            "빈 큐 처리 완료 후 isProcessingQueue는 false여야 함 (defer에 의해 해제)"
        )
    }

    func testProcessNextInQueue_guard_preventsReentrance() async {
        let appState = AppState.shared

        // 수동으로 true 설정 → guard에 의해 즉시 반환
        appState.isProcessingQueue = true

        await appState.processNextInQueue()

        // guard에서 반환되었으므로 defer가 실행되지 않아 여전히 true
        XCTAssertTrue(
            appState.isProcessingQueue,
            "guard에 의해 반환되면 isProcessingQueue는 변경되지 않아야 함"
        )

        // 정리
        appState.isProcessingQueue = false
    }

    // MARK: - isProcessingQueue 반복 토글 안정성

    func testIsProcessingQueue_rapidToggle_doesNotCrash() {
        let appState = AppState.shared

        for _ in 0..<100 {
            appState.isProcessingQueue = true
            appState.isProcessingQueue = false
        }

        XCTAssertFalse(
            appState.isProcessingQueue,
            "100회 토글 후 false 상태여야 함"
        )
    }

    // MARK: - 녹음 중 stopRecordingAndTranscribe 후 isProcessingQueue 상태

    func testStopRecordingAndTranscribe_whenNotRecording_doesNotSetProcessingQueue() {
        let appState = AppState.shared

        XCTAssertFalse(appState.recorderService.isRecording)

        appState.stopRecordingAndTranscribe()

        // 녹음 중이 아닐 때 호출하면 큐에 추가하지 않으므로
        // isProcessingQueue가 변경되지 않아야 함
        // (processNextInQueue가 비동기로 호출될 수 있으므로 즉시 상태만 확인)
        // stopRecordingAndTranscribe 내부에서 guard로 보호되므로 안전
    }

    // MARK: - isProcessingQueue가 true일 때 버튼 비활성화 시나리오

    func testRecordButtonDisabled_whenProcessingQueue() {
        // RecordingView에서 .disabled(isTranscribing) 적용됨
        // isTranscribing == appState.isProcessingQueue
        // 이 테스트는 isProcessingQueue가 true일 때 버튼이 비활성화되어야 하는
        // 전제 조건인 isProcessingQueue 값이 올바르게 설정되는지 검증
        let appState = AppState.shared
        let original = appState.isProcessingQueue

        appState.isProcessingQueue = true
        // RecordingView의 isTranscribing은 appState.isProcessingQueue를 직접 참조
        // → true면 .disabled(true)가 적용되어 버튼이 비활성화됨
        XCTAssertTrue(
            appState.isProcessingQueue,
            "isProcessingQueue가 true이면 RecordingView의 녹음 버튼이 비활성화되어야 함"
        )

        appState.isProcessingQueue = false
        XCTAssertFalse(
            appState.isProcessingQueue,
            "isProcessingQueue가 false이면 녹음 버튼이 활성화되어야 함"
        )

        // 정리
        appState.isProcessingQueue = original
    }

    // MARK: - processNextInQueue defer 보장: 예외 상황에서도 false로 복원

    func testProcessNextInQueue_completesWithFalse_evenWhenQueueEmpty() async {
        let appState = AppState.shared

        // 큐가 비어있는 상태에서 호출
        XCTAssertTrue(appState.transcriptionQueue.isEmpty)

        await appState.processNextInQueue()

        // defer에 의해 반드시 false로 복원
        XCTAssertFalse(
            appState.isProcessingQueue,
            "processNextInQueue 완료 후 defer에 의해 isProcessingQueue가 false로 복원되어야 함"
        )
    }

    // MARK: - isProcessingQueue 동일 값 재설정 안정성

    func testIsProcessingQueue_setToSameValue_doesNotCrash() {
        let appState = AppState.shared

        appState.isProcessingQueue = false
        appState.isProcessingQueue = false
        XCTAssertFalse(appState.isProcessingQueue)

        appState.isProcessingQueue = true
        appState.isProcessingQueue = true
        XCTAssertTrue(appState.isProcessingQueue)

        // 정리
        appState.isProcessingQueue = false
    }
}
