import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            RecordingView()
                .tabItem {
                    Label(AppTab.record.rawValue, systemImage: AppTab.record.systemImage)
                }
                .tag(AppTab.record)

            HistoryView()
                .tabItem {
                    Label(AppTab.history.rawValue, systemImage: AppTab.history.systemImage)
                }
                .tag(AppTab.history)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.rawValue, systemImage: AppTab.settings.systemImage)
                }
                .tag(AppTab.settings)
        }
        .task {
            await appState.setup()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appState.resumePendingTranscriptions()
            }
        }
    }
}
