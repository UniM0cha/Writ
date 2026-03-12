import SwiftUI
import SwiftData
import Combine
import UserNotifications
#if os(iOS)
import ActivityKit
#endif

/// 앱 전역 상태
@MainActor
final class AppState: ObservableObject {
    /// AppIntents에서 접근하기 위한 싱글턴
    static let shared = AppState()

    @Published var selectedTab: AppTab = .record
    /// 알림 탭 시 이동할 녹음 ID (UUID string)
    @Published var pendingRecordingID: String?

    let engine: WhisperKitEngine
    let modelManager: ModelManager
    let recorderService: AudioRecorderService
    let modelContainer: ModelContainer
    #if os(macOS)
    let fnKeyMonitor = FnKeyMonitor()
    #endif

    #if os(iOS)
    var currentActivity: Activity<WritActivityAttributes>?
    private var liveActivityTimer: Timer?
    private var recordingStartDate: Date?
    #endif

    private var cancellables = Set<AnyCancellable>()
    private let notificationDelegate = NotificationDelegate()
    /// 현재 전사 진행 중인 녹음 ID (중복 실행 방지)
    private var activeTranscriptionIDs = Set<PersistentIdentifier>()
    /// 진행률 저장 throttle용 (0.5초 간격)
    private var lastProgressSaveDate = Date.distantPast

    private init() {
        let engine = WhisperKitEngine()
        self.engine = engine
        self.modelManager = ModelManager(engine: engine)
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
    }

    func setup() async {
        // 기존 Documents → App Group 마이그레이션
        AppGroupConstants.migrateFromDocumentsIfNeeded()

        await modelManager.loadDefaultModelIfNeeded()

        // WatchConnectivity 설정
        #if os(iOS)
        let watchSession = PhoneWatchSessionManager.shared
        watchSession.configure(engine: engine, modelContainer: modelContainer)
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
        _ = try await recorderService.startRecording()
        selectedTab = .record
        #if os(iOS)
        startLiveActivity()
        #endif
    }

    // MARK: - Live Activity 관리

    #if os(iOS)
    private func stopLiveActivityTimer() {
        liveActivityTimer?.invalidate()
        liveActivityTimer = nil
    }

    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // 기존 타이머 정리 (빠른 반복 호출 방어)
        stopLiveActivityTimer()

        let startDate = Date()
        recordingStartDate = startDate
        let attributes = WritActivityAttributes()
        let state = WritActivityAttributes.ContentState.recording(duration: 0, startDate: startDate, power: 0)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            currentActivity = activity

            // 0.3초마다 averagePower push
            liveActivityTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.pushLiveActivityPower()
                }
            }
        } catch {
            // Live Activity 시작 실패 — 무시
        }
    }

    private func pushLiveActivityPower() {
        guard let activity = currentActivity, let startDate = recordingStartDate else { return }
        let state = WritActivityAttributes.ContentState.recording(
            duration: recorderService.currentTime,
            startDate: startDate,
            power: recorderService.averagePower
        )
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func updateLiveActivityToTranscribing() {
        stopLiveActivityTimer()

        guard let activity = currentActivity else { return }
        let state = WritActivityAttributes.ContentState.transcribing()
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func updateLiveActivityProgress(_ progress: Float) {
        guard let activity = currentActivity else { return }
        let state = WritActivityAttributes.ContentState.transcribing(progress: progress)
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func updateLiveActivityToCompleted() {
        stopLiveActivityTimer()
        guard let activity = currentActivity else { return }
        let state = WritActivityAttributes.ContentState.completed()
        Task {
            await activity.update(.init(state: state, staleDate: nil))
            await activity.end(
                .init(state: state, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(2))
            )
        }
        currentActivity = nil
    }

    func endLiveActivity() {
        stopLiveActivityTimer()

        guard let activity = currentActivity else { return }
        let state = WritActivityAttributes.ContentState.recording(duration: 0, startDate: Date(), power: 0)
        Task {
            await activity.end(
                .init(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        currentActivity = nil
    }
    #endif

    // MARK: - 녹음 중지 + 전사 (Intent 및 RecordingView에서 호출)

    func stopRecordingAndTranscribe() {
        guard let (fileName, duration) = recorderService.stopRecording() else {
            #if os(iOS)
            endLiveActivity()
            #endif
            return
        }

        let language = AppGroupConstants.resolvedLanguage(
            from: UserDefaults.standard.string(forKey: "selectedLanguage")
        )
        let autoCopy = UserDefaults.standard.bool(forKey: "autoCopyEnabled")

        let context = ModelContext(modelContainer)

        let sourceDevice: SourceDevice = {
            #if os(macOS)
            return .mac
            #else
            return UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
            #endif
        }()

        let recording = Recording(
            duration: duration,
            audioFileName: fileName,
            languageCode: language,
            sourceDevice: sourceDevice
        )
        let transcription = Transcription(
            text: "",
            modelUsed: modelManager.activeModel?.displayName ?? "unknown",
            status: .pending
        )
        recording.transcription = transcription
        recording.audioData = try? Data(contentsOf: recording.audioURL)
        context.insert(recording)
        try? context.save()

        let recordingID = recording.persistentModelID

        // Live Activity를 전사 상태로 전환
        #if os(iOS)
        updateLiveActivityToTranscribing()
        #endif

        // 백그라운드 전사 시작
        Task {
            await transcribeInBackground(
                recordingID: recordingID,
                audioFileName: fileName,
                language: language,
                autoCopy: autoCopy
            )
        }
    }

    // MARK: - 백그라운드 전사

    func transcribeInBackground(
        recordingID: PersistentIdentifier,
        audioFileName: String,
        language: String?,
        autoCopy: Bool
    ) async {
        // 중복 전사 방지
        guard !activeTranscriptionIDs.contains(recordingID) else { return }
        activeTranscriptionIDs.insert(recordingID)
        defer { activeTranscriptionIDs.remove(recordingID) }

        #if os(iOS)
        // Live Activity 정리 보장 (성공 시 updateLiveActivityToCompleted이 currentActivity = nil 설정)
        defer {
            if currentActivity != nil {
                endLiveActivity()
            }
        }

        // 백그라운드 태스크 요청
        var bgTaskID: UIBackgroundTaskIdentifier = .invalid
        let container = modelContainer
        bgTaskID = UIApplication.shared.beginBackgroundTask {
            // 만료 시: 동기적으로 상태 저장 후 종료
            let expiredContext = ModelContext(container)
            if let rec = expiredContext.model(for: recordingID) as? Recording,
               rec.transcription?.status == .inProgress {
                rec.transcription?.status = .pending
                try? expiredContext.save()
            }
            UIApplication.shared.endBackgroundTask(bgTaskID)
            bgTaskID = .invalid
        }
        defer {
            if bgTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(bgTaskID)
            }
        }
        #endif

        let audioURL = AppGroupConstants.recordingsDirectory.appendingPathComponent(audioFileName)

        // 모델이 아직 로드되지 않았으면 로드 대기
        if modelManager.activeModel == nil {
            await modelManager.loadDefaultModelIfNeeded()
        }

        let backgroundContext = ModelContext(modelContainer)

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            if let recording = backgroundContext.model(for: recordingID) as? Recording {
                recording.transcription?.status = .failed
                try? backgroundContext.save()
            }
            return
        }

        // 상태를 inProgress로 업데이트
        if let recording = backgroundContext.model(for: recordingID) as? Recording {
            recording.transcription?.status = .inProgress
            try? backgroundContext.save()
        } else {
            return
        }

        do {
            let output = try await modelManager.transcribe(
                audioURL: audioURL,
                language: language,
                progressCallback: { @Sendable progress in
                    Task { @MainActor in
                        let appState = AppState.shared
                        #if os(iOS)
                        appState.updateLiveActivityProgress(progress)
                        #endif
                        // SwiftData에 진행률 저장 (throttled)
                        let now = Date()
                        if now.timeIntervalSince(appState.lastProgressSaveDate) >= 0.5 {
                            appState.lastProgressSaveDate = now
                            let ctx = ModelContext(appState.modelContainer)
                            if let rec = ctx.model(for: recordingID) as? Recording {
                                rec.transcription?.progress = progress
                                try? ctx.save()
                            }
                        }
                    }
                }
            )

            if let recording = backgroundContext.model(for: recordingID) as? Recording {
                let segments = output.segments.enumerated().map { index, seg in
                    WritSegment(
                        text: seg.text,
                        startTime: seg.startTime,
                        endTime: seg.endTime,
                        orderIndex: index
                    )
                }

                recording.transcription?.text = output.text
                recording.transcription?.modelUsed = modelManager.activeModel?.displayName ?? "unknown"
                recording.transcription?.status = .completed
                recording.transcription?.progress = 1
                recording.transcription?.segments = segments
                try backgroundContext.save()

                if autoCopy {
                    ClipboardService.copy(output.text)
                }

                // Live Activity → 완료 상태 (currentActivity = nil 설정 → defer에서 중복 호출 방지)
                #if os(iOS)
                updateLiveActivityToCompleted()
                #endif

                await sendCompletionNotification(
                    text: output.text,
                    recordingID: recording.id
                )
            }
        } catch {
            if let recording = backgroundContext.model(for: recordingID) as? Recording {
                recording.transcription?.status = .failed
                try? backgroundContext.save()
            }
            // defer에서 endLiveActivity 처리
        }
    }

    // MARK: - 알림

    private func sendCompletionNotification(text: String, recordingID: UUID) async {
        let content = UNMutableNotificationContent()
        content.title = "전사 완료"
        content.body = String(text.prefix(100))
        content.sound = .default
        content.userInfo = ["recordingID": recordingID.uuidString]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - 오래된 녹음 자동 삭제

    func cleanupOldRecordings() {
        let autoDeleteDays = UserDefaults.standard.integer(forKey: "autoDeleteDays")
        guard autoDeleteDays > 0 else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -autoDeleteDays, to: Date()) ?? Date()
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<Recording> { recording in
            recording.createdAt < cutoffDate
        }
        let descriptor = FetchDescriptor<Recording>(predicate: predicate)

        guard let oldRecordings = try? context.fetch(descriptor) else { return }

        for recording in oldRecordings {
            try? FileManager.default.removeItem(at: recording.audioURL)
            context.delete(recording)
        }
        try? context.save()
    }

    // MARK: - 중단된 전사 복구

    private func resumePendingTranscriptions() {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Recording>()

        guard let allRecordings = try? context.fetch(descriptor) else { return }
        let pendingRecordings = allRecordings.filter {
            $0.transcription?.status == .pending || $0.transcription?.status == .inProgress
        }
        guard !pendingRecordings.isEmpty else { return }

        let autoCopy = UserDefaults.standard.bool(forKey: "autoCopyEnabled")
        let language = AppGroupConstants.resolvedLanguage(
            from: UserDefaults.standard.string(forKey: "selectedLanguage")
        )

        // ModelContext 해제 후에도 안전하도록 값을 미리 추출
        let items = pendingRecordings.map { ($0.persistentModelID, $0.audioFileName) }

        Task {
            for (id, fileName) in items {
                await transcribeInBackground(
                    recordingID: id,
                    audioFileName: fileName,
                    language: language,
                    autoCopy: autoCopy
                )
            }
        }
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

enum AppTab: String, CaseIterable {
    case record = "녹음"
    case history = "기록"
    case settings = "설정"

    var systemImage: String {
        switch self {
        case .record: "mic.fill"
        case .history: "clock.fill"
        case .settings: "gearshape.fill"
        }
    }
}
