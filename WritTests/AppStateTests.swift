import XCTest
@testable import Writ

/// AppState 리팩토링 후 제거된 프로퍼티 및 현행 인터페이스 검증
@MainActor
final class AppStateTests: XCTestCase {

    // MARK: - 제거된 프로퍼티 확인 (런타임 검증)
    //
    // 아래 테스트들은 코드 리뷰에서 제거된 dead state가 다시 추가되지 않는지 검증합니다.
    // AppState가 @MainActor이므로 responds(to:)로 확인합니다.

    func testIsRecordingProperty_doesNotExist() {
        // AppState.isRecording (@Published) 가 제거되었는지 확인
        // recorderService.isRecording으로 대체됨
        let appState = AppState.shared
        let selector = NSSelectorFromString("isRecording")
        let responds = (appState as AnyObject).responds(to: selector)
        XCTAssertFalse(
            responds,
            "AppState에서 'isRecording' 프로퍼티가 제거되었어야 함 (recorderService.isRecording 사용)"
        )
    }

    func testPendingStopRecordingProperty_doesNotExist() {
        // AppState.pendingStopRecording 가 제거되었는지 확인
        let appState = AppState.shared
        let selector = NSSelectorFromString("pendingStopRecording")
        let responds = (appState as AnyObject).responds(to: selector)
        XCTAssertFalse(
            responds,
            "AppState에서 'pendingStopRecording' 프로퍼티가 제거되었어야 함"
        )
    }

    // MARK: - 현행 인터페이스 존재 확인

    func testPendingRecordingID_exists() {
        // pendingRecordingID는 알림 탭 → 녹음 상세 이동에 사용됨
        let appState = AppState.shared
        XCTAssertNil(appState.pendingRecordingID, "초기값은 nil이어야 함")

        // 값 설정 후 확인
        appState.pendingRecordingID = "test-uuid"
        XCTAssertEqual(appState.pendingRecordingID, "test-uuid")

        // 정리
        appState.pendingRecordingID = nil
    }

    func testSelectedTab_defaultIsRecord() {
        let appState = AppState.shared
        XCTAssertEqual(appState.selectedTab, .record, "기본 선택 탭은 녹음이어야 함")
    }

    func testSelectedTab_canBeChanged() {
        let appState = AppState.shared
        let originalTab = appState.selectedTab

        appState.selectedTab = .history
        XCTAssertEqual(appState.selectedTab, .history)

        appState.selectedTab = .settings
        XCTAssertEqual(appState.selectedTab, .settings)

        // 정리
        appState.selectedTab = originalTab
    }

    // MARK: - 싱글턴 검증

    func testShared_returnsSameInstance() {
        let instance1 = AppState.shared
        let instance2 = AppState.shared
        XCTAssertTrue(instance1 === instance2, "AppState.shared는 동일한 인스턴스를 반환해야 함")
    }

    // MARK: - 서비스 초기화 검증

    func testEngine_isNotNil() {
        let appState = AppState.shared
        XCTAssertNotNil(appState.engine, "WhisperKitEngine이 초기화되어야 함")
    }

    func testModelManager_isNotNil() {
        let appState = AppState.shared
        XCTAssertNotNil(appState.modelManager, "ModelManager가 초기화되어야 함")
    }

    func testRecorderService_isNotNil() {
        let appState = AppState.shared
        XCTAssertNotNil(appState.recorderService, "AudioRecorderService가 초기화되어야 함")
    }

    func testModelContainer_isNotNil() {
        let appState = AppState.shared
        XCTAssertNotNil(appState.modelContainer, "ModelContainer가 초기화되어야 함")
    }
}
