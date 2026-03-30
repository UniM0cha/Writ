import XCTest
@testable import Writ

/// HistoryView의 Button + navigationDestination(item:) 네비게이션 패턴 검증
///
/// HistoryView는 NavigationLink(destination:)에서 Button + @State navigateToRecording으로 변경되었다.
/// SwiftUI View의 @State는 직접 테스트할 수 없으므로, 네비게이션을 구동하는
/// AppState.pendingRecordingID → navigateToRecording 연결 로직의 전제조건을 검증한다.
@MainActor
final class HistoryViewNavigationTests: XCTestCase {

    // MARK: - pendingRecordingID 초기 상태

    func test_pendingRecordingID_initialValue_isNil() {
        let appState = AppState.shared
        XCTAssertNil(
            appState.pendingRecordingID,
            "pendingRecordingID 초기값은 nil이어야 함"
        )
    }

    // MARK: - pendingRecordingID 값 설정

    func test_pendingRecordingID_canBeSetToUUIDString() {
        let appState = AppState.shared
        let original = appState.pendingRecordingID

        let testID = "550E8400-E29B-41D4-A716-446655440000"
        appState.pendingRecordingID = testID
        XCTAssertEqual(
            appState.pendingRecordingID, testID,
            "pendingRecordingID를 UUID 문자열로 설정할 수 있어야 함"
        )

        // 정리
        appState.pendingRecordingID = original
    }

    func test_pendingRecordingID_canBeSetBackToNil() {
        let appState = AppState.shared
        let original = appState.pendingRecordingID

        appState.pendingRecordingID = "test-id"
        XCTAssertNotNil(appState.pendingRecordingID)

        appState.pendingRecordingID = nil
        XCTAssertNil(
            appState.pendingRecordingID,
            "pendingRecordingID를 nil로 되돌릴 수 있어야 함"
        )

        // 정리
        appState.pendingRecordingID = original
    }

    // MARK: - pendingRecordingID Published 동작

    func test_pendingRecordingID_isPublished() {
        let appState = AppState.shared
        let original = appState.pendingRecordingID
        let expectation = XCTestExpectation(description: "objectWillChange가 발행되어야 함")

        let cancellable = appState.objectWillChange
            .sink { _ in
                expectation.fulfill()
            }

        appState.pendingRecordingID = "trigger-change"

        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()

        // 정리
        appState.pendingRecordingID = original
    }

    // MARK: - 네비게이션 시나리오: 탭 전환 후 pendingRecordingID 설정

    func test_navigationScenario_setTabToHistoryThenSetPendingID() {
        let appState = AppState.shared
        let originalTab = appState.selectedTab
        let originalPending = appState.pendingRecordingID

        // 알림 딥링크 시나리오: history 탭으로 전환 후 pendingRecordingID 설정
        appState.selectedTab = .history
        appState.pendingRecordingID = "test-recording-id"

        XCTAssertEqual(appState.selectedTab, .history)
        XCTAssertEqual(appState.pendingRecordingID, "test-recording-id")

        // 정리
        appState.selectedTab = originalTab
        appState.pendingRecordingID = originalPending
    }

    // MARK: - pendingRecordingID가 빈 문자열인 경우

    func test_pendingRecordingID_emptyString_isNotNil() {
        let appState = AppState.shared
        let original = appState.pendingRecordingID

        appState.pendingRecordingID = ""
        XCTAssertNotNil(
            appState.pendingRecordingID,
            "빈 문자열은 nil이 아님 (onChange에서 guard let이 통과함)"
        )
        XCTAssertEqual(appState.pendingRecordingID, "")

        // 정리
        appState.pendingRecordingID = original
    }

    // MARK: - pendingRecordingID 연속 설정 안정성

    func test_pendingRecordingID_rapidUpdates_doesNotCrash() {
        let appState = AppState.shared
        let original = appState.pendingRecordingID

        for i in 0..<50 {
            appState.pendingRecordingID = "id-\(i)"
        }
        appState.pendingRecordingID = nil

        XCTAssertNil(
            appState.pendingRecordingID,
            "50회 연속 설정 후 nil로 복원되어야 함"
        )

        // 정리
        appState.pendingRecordingID = original
    }

    // MARK: - Recording 모델: UUID 문자열 비교 (onChange 내부 로직)

    func test_recording_uuidString_matchesPendingID() {
        // HistoryView.onChange에서 recordings.first(where: { $0.id.uuidString == idString })
        // 이 비교가 정상 동작하는지 검증
        let testUUID = UUID()
        let recording = Recording(
            id: testUUID,
            audioFileName: "test.m4a"
        )

        XCTAssertEqual(
            recording.id.uuidString, testUUID.uuidString,
            "Recording.id.uuidString은 원본 UUID와 동일해야 함"
        )
    }

    func test_recording_uuidString_caseConsistency() {
        // UUID.uuidString은 항상 대문자 반환
        let uuid = UUID()
        let uuidString = uuid.uuidString

        XCTAssertEqual(
            uuidString, uuidString.uppercased(),
            "UUID.uuidString은 대문자여야 함"
        )
    }

    // MARK: - Recording의 navigationDestination(item:) 사용 전제조건

    func test_recording_conformsToIdentifiable() {
        // navigationDestination(item:)은 Identifiable 프로토콜을 요구함
        let recording = Recording(audioFileName: "nav-test.m4a")
        let identifiable: any Identifiable = recording
        XCTAssertNotNil(
            identifiable,
            "Recording은 Identifiable을 준수해야 함 (navigationDestination(item:) 요구사항)"
        )
    }

    func test_recording_conformsToHashable() {
        // navigationDestination(item:)의 Binding<Item?>은 Hashable을 요구함
        let recording = Recording(audioFileName: "hash-test.m4a")
        let hashable: any Hashable = recording
        XCTAssertNotNil(
            hashable,
            "Recording은 Hashable을 준수해야 함 (navigationDestination(item:) 요구사항)"
        )
    }

    func test_recording_distinctInstances_haveDifferentIdentity() {
        // Button이 각 recording을 navigateToRecording에 설정하므로
        // 서로 다른 Recording이 구별되어야 올바른 항목으로 네비게이션됨
        let recording1 = Recording(audioFileName: "file1.m4a")
        let recording2 = Recording(audioFileName: "file2.m4a")

        XCTAssertNotEqual(
            recording1.id, recording2.id,
            "서로 다른 Recording 인스턴스는 다른 id를 가져야 함"
        )
        XCTAssertNotEqual(
            recording1.hashValue, recording2.hashValue,
            "서로 다른 Recording 인스턴스는 다른 hashValue를 가져야 함"
        )
    }

    func test_recording_sameInstance_hasConsistentHash() {
        // 동일 인스턴스의 hashValue가 안정적이어야 Binding이 정상 동작함
        let recording = Recording(audioFileName: "stable.m4a")
        let hash1 = recording.hashValue
        let hash2 = recording.hashValue

        XCTAssertEqual(
            hash1, hash2,
            "동일 Recording의 hashValue는 일관되어야 함"
        )
    }

    func test_recording_idProperty_isUUID() {
        // navigateToRecording 바인딩이 Recording.id로 식별하므로 UUID 타입이어야 함
        let recording = Recording(audioFileName: "uuid-check.m4a")
        let id: UUID = recording.id
        XCTAssertFalse(
            id.uuidString.isEmpty,
            "Recording.id는 유효한 UUID여야 함"
        )
    }

    // MARK: - navigateToRecording Optional 바인딩 시나리오

    func test_recording_optionalAssignment_worksCorrectly() {
        // @State private var navigateToRecording: Recording? 패턴 시뮬레이션
        var navigateToRecording: Recording? = nil
        XCTAssertNil(navigateToRecording)

        let recording = Recording(audioFileName: "optional-test.m4a")
        navigateToRecording = recording
        XCTAssertNotNil(navigateToRecording)
        XCTAssertEqual(navigateToRecording?.id, recording.id)

        // 네비게이션 해제 시 nil로 설정
        navigateToRecording = nil
        XCTAssertNil(
            navigateToRecording,
            "navigateToRecording을 nil로 설정하여 네비게이션을 해제할 수 있어야 함"
        )
    }

    func test_recording_optionalReplacement_updatesToNewRecording() {
        // 사용자가 다른 녹음을 빠르게 탭하는 시나리오
        var navigateToRecording: Recording? = nil

        let first = Recording(audioFileName: "first.m4a")
        let second = Recording(audioFileName: "second.m4a")

        navigateToRecording = first
        XCTAssertEqual(navigateToRecording?.id, first.id)

        navigateToRecording = second
        XCTAssertEqual(
            navigateToRecording?.id, second.id,
            "navigateToRecording을 다른 Recording으로 교체하면 새 값이 반영되어야 함"
        )
    }
}
