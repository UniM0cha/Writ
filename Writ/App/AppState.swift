import SwiftUI
import SwiftData
import Combine

/// 앱 전역 상태
@MainActor
final class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var selectedTab: AppTab = .record
    @Published var pendingStopRecording = false

    let engine: WhisperKitEngine
    let modelManager: ModelManager
    let recorderService: AudioRecorderService
    let modelContainer: ModelContainer

    private var cancellables = Set<AnyCancellable>()

    init() {
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
                isStoredInMemoryOnly: false
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
        await modelManager.loadDefaultModelIfNeeded()

        // WatchConnectivity 설정
        #if os(iOS)
        let watchSession = PhoneWatchSessionManager.shared
        watchSession.configure(engine: engine, modelContainer: modelContainer)
        watchSession.activate()
        #endif

        // 키보드 확장 전사 요청 리스너
        registerKeyboardTranscriptionListener()

        // 오래된 녹음 자동 삭제
        cleanupOldRecordings()
    }

    /// 키보드 확장에서 Darwin Notification을 통해 전사를 요청하면 처리
    private func registerKeyboardTranscriptionListener() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let appState = Unmanaged<AppState>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    await appState.handleKeyboardTranscriptionRequest()
                }
            },
            AppGroupConstants.transcriptionRequestNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// 백그라운드에서 전사 수행
    func transcribeInBackground(
        recordingID: PersistentIdentifier,
        audioFileName: String,
        language: String?,
        autoCopy: Bool
    ) async {
        let audioURL = AppGroupConstants.recordingsDirectory.appendingPathComponent(audioFileName)

        print("[Writ] transcribeInBackground: starting for \(audioFileName)")
        print("[Writ] transcribeInBackground: audio file exists = \(FileManager.default.fileExists(atPath: audioURL.path))")
        print("[Writ] transcribeInBackground: model loaded = \(modelManager.activeModel != nil)")

        // 모델이 아직 로드되지 않았으면 로드 대기
        if modelManager.activeModel == nil {
            print("[Writ] transcribeInBackground: waiting for model to load...")
            await modelManager.loadDefaultModelIfNeeded()
            print("[Writ] transcribeInBackground: model load finished, activeModel = \(String(describing: modelManager.activeModel))")
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("[Writ] transcribeInBackground: ERROR - audio file not found at \(audioURL.path)")
            let backgroundContext = ModelContext(modelContainer)
            if let recording = backgroundContext.model(for: recordingID) as? Recording {
                recording.transcription?.status = .failed
                try? backgroundContext.save()
            }
            return
        }

        let backgroundContext = ModelContext(modelContainer)

        // 상태를 inProgress로 업데이트
        if let recording = backgroundContext.model(for: recordingID) as? Recording {
            print("[Writ] transcribeInBackground: recording found, updating status to inProgress")
            recording.transcription?.status = .inProgress
            try? backgroundContext.save()
        } else {
            print("[Writ] transcribeInBackground: ERROR - could not find Recording for persistentModelID")
            return
        }

        do {
            print("[Writ] transcribeInBackground: calling modelManager.transcribe()...")
            let output = try await modelManager.transcribe(
                audioURL: audioURL,
                language: language,
                progressCallback: nil
            )
            print("[Writ] transcribeInBackground: transcription completed, text length = \(output.text.count)")

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
                recording.transcription?.segments = segments
                try backgroundContext.save()
                print("[Writ] transcribeInBackground: saved successfully")

                if autoCopy {
                    ClipboardService.copy(output.text)
                    print("[Writ] transcribeInBackground: copied to clipboard")
                }
            } else {
                print("[Writ] transcribeInBackground: ERROR - could not find Recording after transcription")
            }
        } catch {
            print("[Writ] transcribeInBackground: ERROR - transcription failed: \(error)")
            if let recording = backgroundContext.model(for: recordingID) as? Recording {
                recording.transcription?.status = .failed
                try? backgroundContext.save()
                print("[Writ] transcribeInBackground: marked as failed")
            } else {
                print("[Writ] transcribeInBackground: ERROR - could not find Recording to mark as failed")
            }
        }
    }

    /// 오래된 녹음 자동 삭제
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

    /// 키보드에서 요청한 전사 처리
    func handleKeyboardTranscriptionRequest() async {
        guard let data = try? Data(contentsOf: AppGroupConstants.keyboardRequestFile),
              let request = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let audioPath = request["audioPath"] else { return }

        let audioURL = AppGroupConstants.recordingsDirectory.appendingPathComponent(audioPath)

        do {
            let output = try await engine.transcribe(
                audioURL: audioURL,
                language: nil,
                progressCallback: nil
            )

            // 결과 파일에 저장
            let result: [String: String] = ["text": output.text]
            if let resultData = try? JSONSerialization.data(withJSONObject: result) {
                try? resultData.write(to: AppGroupConstants.keyboardResultFile)
            }

            // 최근 전사문 파일에도 저장 (최근 전사문 삽입 기능용)
            let recentFile = AppGroupConstants.containerURL.appendingPathComponent("recent_transcription.txt")
            try? output.text.write(to: recentFile, atomically: true, encoding: .utf8)

            // 요청 파일 정리
            try? FileManager.default.removeItem(at: AppGroupConstants.keyboardRequestFile)
        } catch {
            // 전사 실패 시 에러 결과 저장
            let result: [String: String] = ["error": error.localizedDescription]
            if let resultData = try? JSONSerialization.data(withJSONObject: result) {
                try? resultData.write(to: AppGroupConstants.keyboardResultFile)
            }
        }
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
