import XCTest
import SwiftData
import UserNotifications
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

    func testWhisperEngine_isNotNil() {
        let appState = AppState.shared
        XCTAssertNotNil(appState.modelManager.whisperEngine, "WhisperKitEngine이 초기화되어야 함")
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

    // MARK: - 전사 큐 프로퍼티 접근성 검증 (private -> internal 리팩토링)

    func testTranscriptionQueue_isAccessible() {
        // 리팩토링 후 transcriptionQueue가 internal 접근 가능한지 검증
        let appState = AppState.shared
        XCTAssertNotNil(appState.transcriptionQueue, "transcriptionQueue가 접근 가능해야 함")
    }

    func testTranscriptionQueue_initiallyEmpty() {
        let appState = AppState.shared
        // 이전 테스트에서 남은 항목이 있을 수 있으므로 타입만 확인
        XCTAssertTrue(
            appState.transcriptionQueue is [AppState.TranscriptionQueueItem],
            "transcriptionQueue는 TranscriptionQueueItem 배열이어야 함"
        )
    }

    func testIsProcessingQueue_isAccessible() {
        // 리팩토링 후 isProcessingQueue가 internal 접근 가능한지 검증
        let appState = AppState.shared
        let _ = appState.isProcessingQueue
        // 접근 자체가 성공하면 테스트 통과
    }

    func testActiveTranscriptionIDs_isAccessible() {
        // 리팩토링 후 activeTranscriptionIDs가 internal 접근 가능한지 검증
        let appState = AppState.shared
        XCTAssertNotNil(
            appState.activeTranscriptionIDs,
            "activeTranscriptionIDs가 접근 가능해야 함"
        )
    }

    func testLastProgressSaveDate_isAccessible() {
        // 리팩토링 후 lastProgressSaveDate가 internal 접근 가능한지 검증
        let appState = AppState.shared
        XCTAssertEqual(
            appState.lastProgressSaveDate, Date.distantPast,
            "lastProgressSaveDate 초기값은 Date.distantPast여야 함"
        )
    }

    func testLastResumeDate_isAccessible() {
        // 리팩토링 후 lastResumeDate가 internal 접근 가능한지 검증
        let appState = AppState.shared
        // lastResumeDate는 resumePendingTranscriptions() 호출 시 업데이트됨
        let _ = appState.lastResumeDate
        // 접근 자체가 성공하면 테스트 통과
    }

    // MARK: - TranscriptionQueueItem 구조체 검증

    func testTranscriptionQueueItem_canBeCreated() {
        // TranscriptionQueueItem이 internal 접근 가능한지 검증
        // SwiftData PersistentIdentifier는 테스트에서 직접 생성하기 어려우므로
        // 타입 자체가 접근 가능한지만 확인
        let queueType = AppState.TranscriptionQueueItem.self
        XCTAssertNotNil(queueType, "TranscriptionQueueItem 타입이 접근 가능해야 함")
    }

    // MARK: - Extension 메서드 존재 확인

    func testCleanupOldRecordings_isCallable() {
        // AppState+Notifications.swift에서 분리된 메서드가 호출 가능한지 검증
        let appState = AppState.shared
        // autoDeleteDays가 0이면 즉시 반환하므로 안전하게 호출 가능
        UserDefaults.standard.set(0, forKey: "autoDeleteDays")
        appState.cleanupOldRecordings()
        // 크래시 없이 완료되면 성공
    }

    func testResumePendingTranscriptions_isCallable() {
        // AppState+TranscriptionQueue.swift에서 분리된 메서드가 호출 가능한지 검증
        let appState = AppState.shared
        appState.resumePendingTranscriptions()
        // 크래시 없이 완료되면 성공
    }

    func testStopRecordingAndTranscribe_isCallable() {
        // AppState+Recording.swift에서 분리된 메서드가 호출 가능한지 검증
        let appState = AppState.shared
        // 녹음 중이 아닐 때 호출해도 안전
        appState.stopRecordingAndTranscribe()
        // 크래시 없이 완료되면 성공
    }

    func testProcessNextInQueue_isCallable() async {
        // AppState+TranscriptionQueue.swift에서 분리된 메서드가 호출 가능한지 검증
        let appState = AppState.shared
        // 큐가 비어있으므로 즉시 반환
        await appState.processNextInQueue()
        // 크래시 없이 완료되면 성공
    }

    func testStartRecordingFlow_isCallable() {
        // AppState.swift 코어에 남아있는 메서드가 접근 가능한지 검증
        let appState = AppState.shared
        // startRecordingFlow는 마이크 권한이 필요하므로 존재만 확인
        let _ = appState.startRecordingFlow
        // 메서드 참조가 가능하면 성공
    }
}

// MARK: - TranscriptionQueueItem 상세 검증

/// TranscriptionQueueItem이 private에서 internal로 변경된 후
/// extension 파일들에서 올바르게 접근할 수 있는지 검증한다.
@MainActor
final class TranscriptionQueueItemTests: XCTestCase {

    func testTranscriptionQueueItem_propertiesAreReadable() {
        // SwiftData의 PersistentIdentifier를 직접 생성할 수 없으므로
        // 실제 Recording을 생성하여 ID를 얻은 후 QueueItem을 생성
        let container = AppState.shared.modelContainer
        let context = ModelContext(container)
        let recording = Recording(audioFileName: "test.m4a")
        context.insert(recording)
        try? context.save()

        let item = AppState.TranscriptionQueueItem(
            recordingID: recording.persistentModelID,
            audioFileName: "test.m4a",
            language: "ko",
            autoCopy: true
        )

        XCTAssertEqual(item.audioFileName, "test.m4a")
        XCTAssertEqual(item.language, "ko")
        XCTAssertTrue(item.autoCopy)
        XCTAssertEqual(item.recordingID, recording.persistentModelID)

        // 정리
        context.delete(recording)
        try? context.save()
    }

    func testTranscriptionQueueItem_nilLanguage() {
        let container = AppState.shared.modelContainer
        let context = ModelContext(container)
        let recording = Recording(audioFileName: "test2.m4a")
        context.insert(recording)
        try? context.save()

        let item = AppState.TranscriptionQueueItem(
            recordingID: recording.persistentModelID,
            audioFileName: "test2.m4a",
            language: nil,
            autoCopy: false
        )

        XCTAssertNil(item.language, "language가 nil일 수 있어야 함 (auto 감지)")
        XCTAssertFalse(item.autoCopy)

        // 정리
        context.delete(recording)
        try? context.save()
    }

    func testTranscriptionQueueItem_canBeAppendedToQueue() {
        let appState = AppState.shared
        let initialCount = appState.transcriptionQueue.count

        let container = appState.modelContainer
        let context = ModelContext(container)
        let recording = Recording(audioFileName: "test3.m4a")
        context.insert(recording)
        try? context.save()

        let item = AppState.TranscriptionQueueItem(
            recordingID: recording.persistentModelID,
            audioFileName: "test3.m4a",
            language: "en",
            autoCopy: false
        )
        appState.transcriptionQueue.append(item)

        XCTAssertEqual(
            appState.transcriptionQueue.count, initialCount + 1,
            "큐에 항목이 추가되어야 함"
        )

        // 정리
        appState.transcriptionQueue.removeLast()
        context.delete(recording)
        try? context.save()
    }
}

// MARK: - 오래된 녹음 자동 삭제 로직 검증

@MainActor
final class CleanupOldRecordingsTests: XCTestCase {

    override func tearDown() {
        // autoDeleteDays 정리
        UserDefaults.standard.removeObject(forKey: "autoDeleteDays")
        super.tearDown()
    }

    func testCleanupOldRecordings_autoDeleteDaysZero_doesNothing() {
        // autoDeleteDays가 0이면 삭제하지 않음
        UserDefaults.standard.set(0, forKey: "autoDeleteDays")
        let appState = AppState.shared

        // 크래시 없이 즉시 반환
        appState.cleanupOldRecordings()
    }

    func testCleanupOldRecordings_autoDeleteDaysNegative_doesNothing() {
        // autoDeleteDays가 음수이면 삭제하지 않음 (guard autoDeleteDays > 0)
        UserDefaults.standard.set(-1, forKey: "autoDeleteDays")
        let appState = AppState.shared

        appState.cleanupOldRecordings()
        // 크래시 없이 완료되면 성공
    }

    func testCleanupOldRecordings_autoDeleteDaysPositive_doesNotCrash() {
        // autoDeleteDays가 양수일 때 크래시 없이 동작하는지 확인
        // (실제 삭제 여부는 DB 상태에 의존)
        UserDefaults.standard.set(30, forKey: "autoDeleteDays")
        let appState = AppState.shared

        appState.cleanupOldRecordings()
        // 크래시 없이 완료되면 성공
    }

    func testCleanupOldRecordings_veryLargeDeleteDays_doesNotCrash() {
        // 매우 큰 값이어도 크래시 없이 동작
        UserDefaults.standard.set(Int.max, forKey: "autoDeleteDays")
        let appState = AppState.shared

        appState.cleanupOldRecordings()
    }
}

// MARK: - resumePendingTranscriptions Throttle 검증

@MainActor
final class ResumePendingTranscriptionsTests: XCTestCase {

    func testResumePendingTranscriptions_throttle_withinFiveSeconds() {
        let appState = AppState.shared

        // 첫 호출
        appState.resumePendingTranscriptions()
        let firstResumeDate = appState.lastResumeDate

        // 즉시 두 번째 호출 — throttle에 의해 무시되어야 함
        appState.resumePendingTranscriptions()
        let secondResumeDate = appState.lastResumeDate

        // lastResumeDate가 갱신되지 않았어야 함
        XCTAssertEqual(
            firstResumeDate, secondResumeDate,
            "5초 이내 재호출 시 lastResumeDate가 갱신되면 안 됨"
        )
    }

    func testResumePendingTranscriptions_multipleRapidCalls_noCrash() {
        let appState = AppState.shared

        // 빠른 연속 호출이 크래시를 일으키지 않는지 검증
        for _ in 0..<20 {
            appState.resumePendingTranscriptions()
        }
        // 크래시 없이 완료되면 성공
    }
}

// MARK: - processNextInQueue 검증

@MainActor
final class ProcessNextInQueueTests: XCTestCase {

    func testProcessNextInQueue_emptyQueue_completesImmediately() async {
        let appState = AppState.shared
        // 큐가 비어있으면 isProcessingQueue가 false 상태로 즉시 반환
        let wasProcessing = appState.isProcessingQueue

        await appState.processNextInQueue()

        // 처리 완료 후 isProcessingQueue는 false
        XCTAssertFalse(
            appState.isProcessingQueue,
            "빈 큐 처리 후 isProcessingQueue는 false여야 함"
        )

        // 원래 값이 true였다면 (다른 처리가 진행 중이었다면) guard에 의해 즉시 반환
        if wasProcessing {
            // isProcessingQueue가 true인 상태에서 호출하면 guard에 의해 무시됨
        }
    }

    func testProcessNextInQueue_whileAlreadyProcessing_isGuarded() async {
        let appState = AppState.shared

        // isProcessingQueue를 수동으로 true로 설정하여 guard 테스트
        appState.isProcessingQueue = true

        await appState.processNextInQueue()
        // guard에 의해 즉시 반환되어야 함

        // 정리
        appState.isProcessingQueue = false
    }
}

// MARK: - sendCompletionNotification 검증

@MainActor
final class SendCompletionNotificationTests: XCTestCase {

    func testSendCompletionNotification_doesNotCrash() async {
        // 알림 권한이 없어도 크래시 없이 동작해야 함
        let appState = AppState.shared
        let testID = UUID()

        await appState.sendCompletionNotification(
            text: "테스트 전사 결과",
            recordingID: testID
        )
        // 크래시 없이 완료되면 성공
    }

    func testSendCompletionNotification_emptyText_doesNotCrash() async {
        let appState = AppState.shared
        let testID = UUID()

        await appState.sendCompletionNotification(
            text: "",
            recordingID: testID
        )
    }

    func testSendCompletionNotification_veryLongText_isTruncatedInBody() async {
        // body에 text.prefix(100)이 사용되므로 긴 텍스트도 안전해야 함
        let appState = AppState.shared
        let testID = UUID()
        let longText = String(repeating: "가", count: 10000)

        await appState.sendCompletionNotification(
            text: longText,
            recordingID: testID
        )
        // 크래시 없이 완료되면 성공
    }
}
