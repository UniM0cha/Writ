#if os(iOS)
import AppIntents

/// Dynamic Island 중지 버튼에서 사용하는 Intent
/// LiveActivityIntent를 채택하여 앱을 foreground로 열지 않고 실행
struct StopRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "녹음 중지"
    static var description: IntentDescription = "녹음을 중지하고 전사를 시작합니다."
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        #if !WIDGET_EXTENSION
        let appState = AppState.shared
        if appState.recorderService.isRecording {
            appState.stopRecordingAndTranscribe()
        } else {
            // 앱이 종료된 상태에서 Live Activity가 남아있는 경우 정리
            appState.liveActivityManager.end()
        }
        #endif
        return .result(dialog: "녹음을 중지합니다")
    }
}
#endif
