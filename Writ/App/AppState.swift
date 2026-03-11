import SwiftUI
import SwiftData
import Combine

/// 앱 전역 상태
@MainActor
final class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var selectedTab: AppTab = .record

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
