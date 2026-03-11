import AppIntents

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "녹음 시작"
    static var description: IntentDescription = "Writ에서 음성 녹음을 시작합니다."
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        // TODO: 녹음 서비스 시작
        return .result()
    }
}

struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "녹음 중지"
    static var description: IntentDescription = "Writ에서 진행 중인 녹음을 중지하고 전사를 시작합니다."
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        // TODO: 녹음 중지 + 전사 시작
        return .result()
    }
}

struct WritShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start recording with \(.applicationName)",
                "\(.applicationName)으로 녹음 시작"
            ],
            shortTitle: "녹음 시작",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: [
                "Stop recording with \(.applicationName)",
                "\(.applicationName) 녹음 중지"
            ],
            shortTitle: "녹음 중지",
            systemImageName: "stop.fill"
        )
    }
}
