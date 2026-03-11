import SwiftUI
import SwiftData

@main
struct WritApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        #if os(macOS)
        MenuBarExtra("Writ", systemImage: "waveform") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Writ") {
            MacMainView()
                .environmentObject(appState)
                .modelContainer(appState.modelContainer)
        }
        .defaultSize(width: 900, height: 600)
        #else
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(appState.modelContainer)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        #endif
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "writ" else { return }
        switch url.host {
        case "start-recording":
            Task { @MainActor in
                if !appState.recorderService.isRecording {
                    _ = try? await appState.recorderService.startRecording()
                    appState.selectedTab = .record
                }
            }
        case "stop-recording":
            Task { @MainActor in
                if appState.recorderService.isRecording {
                    appState.selectedTab = .record
                    // RecordingView의 stopAndTranscribe가 처리하도록 플래그 설정
                    appState.pendingStopRecording = true
                }
            }
        default:
            break
        }
    }
}
