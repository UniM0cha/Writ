import SwiftUI

@main
struct WritWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            WatchRecordingView()
                .onAppear {
                    sessionManager.activate()
                }
        }
    }
}
