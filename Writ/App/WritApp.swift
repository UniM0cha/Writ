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

        Window("Writ", id: "main") {
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
        if url.host == "start-recording" {
            Task { @MainActor in
                if !appState.recorderService.isRecording {
                    _ = try? appState.recorderService.startRecording()
                    appState.selectedTab = .record
                }
            }
        }
    }
}
