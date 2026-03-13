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

    let engine: WhisperKitEngine
    let modelManager: ModelManager
    let recorderService: AudioRecorderService
    let modelContainer: ModelContainer
    #if os(macOS)
    let fnKeyMonitor = FnKeyMonitor()
    #endif

    #if os(iOS)
    let liveActivityManager = LiveActivityManager()

    /// BGContinuedProcessingTask에 전달할 대기 전사 정보
    private struct PendingBGTranscription {
        let recordingID: PersistentIdentifier
        let audioFileName: String
        let language: String?
        let autoCopy: Bool
    }
    private var pendingBGTranscription: PendingBGTranscription?

    /// 현재 활성 BGContinuedProcessingTask (전사 진행률 연동용)
    private var activeBGTask: BGContinuedProcessingTask?
    #endif

    private var cancellables = Set<AnyCancellable>()
    private let notificationDelegate = NotificationDelegate()
    /// 현재 전사 진행 중인 녹음 ID (중복 실행 방지)
    private var activeTranscriptionIDs = Set<PersistentIdentifier>()
    /// 진행률 저장 throttle용 (0.5초 간격)
    private var lastProgressSaveDate = Date.distantPast
    /// resumePendingTranscriptions throttle용
    private var lastResumeDate = Date.distantPast

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
        liveActivityManager.startRecording(startDate: Date())
        #endif
    }

    // MARK: - 녹음 중지 + 전사 (Intent 및 RecordingView에서 호출)

    func stopRecordingAndTranscribe() {
        guard let (fileName, duration) = recorderService.stopRecording() else {
            #if os(iOS)
            liveActivityManager.end()
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

        #if os(iOS)
        // Live Activity를 전사 상태로 전환
        liveActivityManager.transitionToTranscribing()

        // BGContinuedProcessingTask 등록 및 제출
        pendingBGTranscription = PendingBGTranscription(
            recordingID: recordingID,
            audioFileName: fileName,
            language: language,
            autoCopy: autoCopy
        )

        let request = BGContinuedProcessingTaskRequest(
            identifier: "com.solstice.writ.transcribe",
            title: "전사 중",
            subtitle: "음성을 텍스트로 변환하고 있습니다"
        )
        request.strategy = .fail

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // BGTask 제출 실패 시 fallback: 직접 전사 실행
            Task {
                await self.transcribeInBackground(
                    recordingID: recordingID,
                    audioFileName: fileName,
                    language: language,
                    autoCopy: autoCopy
                )
            }
        }
        #else
        // macOS: 백그라운드 제한 없음, 직접 실행
        Task {
            await self.transcribeInBackground(
                recordingID: recordingID,
                audioFileName: fileName,
                language: language,
                autoCopy: autoCopy
            )
        }
        #endif
    }

    // MARK: - BGContinuedProcessingTask Handler

    #if os(iOS)
    private func performBGTranscription(bgTask: BGContinuedProcessingTask) async {
        guard let pending = pendingBGTranscription else {
            bgTask.setTaskCompleted(success: false)
            return
        }
        pendingBGTranscription = nil
        activeBGTask = bgTask

        // expiration handler 설정
        let container = modelContainer
        let recordingID = pending.recordingID
        bgTask.expirationHandler = { @Sendable [weak bgTask] in
            let expiredContext = ModelContext(container)
            if let rec = expiredContext.model(for: recordingID) as? Recording,
               rec.transcription?.status == .inProgress {
                rec.transcription?.status = .pending
                try? expiredContext.save()
            }
            bgTask?.setTaskCompleted(success: false)
        }
        bgTask.progress.totalUnitCount = 100
        bgTask.progress.completedUnitCount = 0

        await transcribeInBackground(
            recordingID: pending.recordingID,
            audioFileName: pending.audioFileName,
            language: pending.language,
            autoCopy: pending.autoCopy
        )

        // transcribeInBackground 내부에서 setTaskCompleted가 호출되지 않는 경로 보장 (duplicate guard 등)
        if activeBGTask != nil {
            bgTask.setTaskCompleted(success: false)
        }
        activeBGTask = nil
    }
    #endif

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
        // Live Activity 정리 보장 (completed는 transitionToCompleted()가 자체 종료 처리)
        defer {
            let p = liveActivityManager.phase
            if p != .idle && p != .completed {
                liveActivityManager.end()
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
            #if os(iOS)
            activeBGTask?.setTaskCompleted(success: false)
            activeBGTask = nil
            #endif
            return
        }

        // 상태를 inProgress로 업데이트
        if let recording = backgroundContext.model(for: recordingID) as? Recording {
            recording.transcription?.status = .inProgress
            try? backgroundContext.save()
        } else {
            #if os(iOS)
            activeBGTask?.setTaskCompleted(success: false)
            activeBGTask = nil
            #endif
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
                        appState.liveActivityManager.updateProgress(progress)
                        appState.activeBGTask?.progress.completedUnitCount = Int64(progress * 100)
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

                // Live Activity → 완료 상태
                #if os(iOS)
                liveActivityManager.transitionToCompleted()
                activeBGTask?.setTaskCompleted(success: true)
                activeBGTask = nil
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
            #if os(iOS)
            activeBGTask?.setTaskCompleted(success: false)
            activeBGTask = nil
            #endif
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

    func resumePendingTranscriptions() {
        // scenePhase 변경마다 호출되므로 5초 throttle
        let now = Date()
        guard now.timeIntervalSince(lastResumeDate) >= 5 else { return }
        lastResumeDate = now

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
