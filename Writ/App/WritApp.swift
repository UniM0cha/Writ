import SwiftUI
import SwiftData

@main
struct WritApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        #if os(macOS)
        WindowGroup("Writ") {
            MacMainView()
                .environmentObject(appState)
                .modelContainer(appState.modelContainer)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 900, height: 600)

        MenuBarExtra("Writ", systemImage: "waveform") {
            MenuBarView()
                .environmentObject(appState)
                .modelContainer(appState.modelContainer)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .modelContainer(appState.modelContainer)
        }
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
                try? await appState.startRecordingFlow()
            }
        case "stop-recording":
            Task { @MainActor in
                if appState.recorderService.isRecording {
                    appState.stopRecordingAndTranscribe()
                }
            }
        case "recording":
            // writ://recording/{id} — 알림 탭 시 해당 녹음 상세로 이동
            appState.selectedTab = .history
            if let idString = url.pathComponents.dropFirst().first {
                appState.pendingRecordingID = idString
            }
        default:
            break
        }
    }
}
