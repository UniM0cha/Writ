import SwiftUI
import SwiftData
import Combine
import UserNotifications
#if os(iOS)
import BackgroundTasks
#endif

/// 앱 전역 상태
@MainActor
final class AppState: ObservableObject {
    /// AppIntents에서 접근하기 위한 싱글턴
    static let shared = AppState()

    @Published var selectedTab: AppTab = .record
    /// 알림 탭 시 이동할 녹음 ID (UUID string)
    @Published var pendingRecordingID: String?

    let modelManager: ModelManager
    let recorderService: AudioRecorderService
    let modelContainer: ModelContainer
    #if os(macOS)
    let fnKeyMonitor = FnKeyMonitor()
    #endif

    /// 전사 큐 항목
    struct TranscriptionQueueItem {
        let recordingID: PersistentIdentifier
        let audioFileName: String
        let language: String?
        let autoCopy: Bool
    }
    /// 순차 처리 전사 큐 (ANE 경합 방지)
    var transcriptionQueue: [TranscriptionQueueItem] = []
    /// 큐 처리 루프 실행 중 여부
    @Published var isProcessingQueue = false

    #if os(iOS)
    let liveActivityManager = LiveActivityManager()
    /// 현재 활성 BGContinuedProcessingTask (전사 진행률 연동용)
    var activeBGTask: BGContinuedProcessingTask?
    #endif

    private var cancellables = Set<AnyCancellable>()
    private let notificationDelegate = NotificationDelegate()
    /// 현재 전사 진행 중인 녹음 ID (중복 실행 방지)
    var activeTranscriptionIDs = Set<PersistentIdentifier>()
    /// 진행률 저장 throttle용 (0.5초 간격)
    var lastProgressSaveDate = Date.distantPast
    /// resumePendingTranscriptions throttle용
    var lastResumeDate = Date.distantPast

    private init() {
        self.modelManager = ModelManager(whisperEngine: WhisperKitEngine())
        self.recorderService = AudioRecorderService()

        do {
            let schema = Schema([
                Recording.self,
                Transcription.self,
                WritSegment.self
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData ModelContainer 생성 실패: \(error)")
        }

        // 자식 ObservableObject 변경을 AppState로 포워딩
        modelManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        recorderService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        #if os(iOS)
        liveActivityManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        #endif
    }

    func setup() async {
        // 기존 Documents → App Group 마이그레이션
        AppGroupConstants.migrateFromDocumentsIfNeeded()

        // Orphaned Live Activity 정리
        #if os(iOS)
        await liveActivityManager.cleanupOrphanedActivities()

        // BGContinuedProcessingTask handler 등록 (한 번만)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.solstice.writ.transcribe",
            using: nil
        ) { task in
            guard let bgTask = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await AppState.shared.performBGTranscription(bgTask: bgTask)
            }
        }
        #endif

        // 크래시 루프 방지: 연속 2회 이상 모델 로드 실패 시 자동 로드 건너뛰기
        let failKey = "consecutiveLoadFailures"
        let failures = UserDefaults.standard.integer(forKey: failKey)
        if failures >= 2 {
            UserDefaults.standard.set(0, forKey: failKey)
            modelManager.clearPersistedSelection()
        } else {
            UserDefaults.standard.set(failures + 1, forKey: failKey)
            await modelManager.loadDefaultModelIfNeeded()
            // 모델 로드 성공 또는 저장된 선택이 없는 최초 실행 시에만 리셋
            let hasPersistedSelection = UserDefaults.standard.string(forKey: "selectedModelVariant") != nil
            if modelManager.activeModel != nil || !hasPersistedSelection {
                UserDefaults.standard.set(0, forKey: failKey)
            }
        }

        // WatchConnectivity 설정
        #if os(iOS)
        let watchSession = PhoneWatchSessionManager.shared
        watchSession.configure(modelManager: modelManager, modelContainer: modelContainer)
        watchSession.activate()
        #endif

        // macOS fn 키 모니터 시작
        #if os(macOS)
        fnKeyMonitor.onFnDown = { [weak self] in
            guard let self else { return }
            if !recorderService.isRecording {
                Task {
                    _ = try? await self.recorderService.startRecording()
                }
            }
        }
        fnKeyMonitor.onFnUp = { [weak self] in
            guard let self else { return }
            if recorderService.isRecording {
                stopRecordingAndTranscribe()
            }
        }
        fnKeyMonitor.start()
        #endif

        // 알림 권한 요청 + delegate 설정
        let notifCenter = UNUserNotificationCenter.current()
        notifCenter.delegate = notificationDelegate
        _ = try? await notifCenter.requestAuthorization(options: [.alert, .sound])

        // 오래된 녹음 자동 삭제
        cleanupOldRecordings()

        // 중단된 전사 복구 (.pending / .inProgress 상태)
        resumePendingTranscriptions()
    }

    // MARK: - 녹음 시작 공통 플로우

    func startRecordingFlow() async throws {
        guard !recorderService.isRecording else { return }
        guard modelManager.activeModel != nil else {
            selectedTab = .settings
            return
        }
        _ = try await recorderService.startRecording()
        selectedTab = .record
        #if os(iOS)
        liveActivityManager.startRecording(startDate: Date())
        #endif
    }
}

// MARK: - Notification Delegate

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let recordingID = userInfo["recordingID"] as? String {
            Task { @MainActor in
                AppState.shared.selectedTab = .history
                AppState.shared.pendingRecordingID = recordingID
            }
        }
        completionHandler()
    }

    // 앱이 foreground일 때도 알림 표시
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
