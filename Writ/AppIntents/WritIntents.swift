import AppIntents
import Foundation

// MARK: - 녹음 시작

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "녹음 시작"
    static var description: IntentDescription = "Writ에서 음성 녹음을 시작합니다."
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // 앱을 열어서 녹음 화면으로 이동 (URL scheme 사용)
        return .result()
    }
}

// MARK: - 녹음 중지

struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "녹음 중지"
    static var description: IntentDescription = "Writ에서 진행 중인 녹음을 중지하고 전사를 시작합니다."
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - 오디오 파일 전사

struct TranscribeFileIntent: AppIntent {
    static var title: LocalizedStringResource = "오디오 파일 전사"
    static var description: IntentDescription = "오디오 파일을 텍스트로 전사합니다."
    static var openAppWhenRun: Bool = true

    @Parameter(title: "오디오 파일")
    var audioFile: IntentFile

    @Parameter(title: "언어", default: "auto")
    var language: String?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // 파일을 임시 디렉토리에 저장
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("intent_\(UUID().uuidString).m4a")
        try audioFile.data.write(to: tempURL)

        // AppGroupConstants 경로로 복사하여 메인 앱이 처리하도록 함
        let destDir = AppGroupConstants.recordingsDirectory
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destURL = destDir.appendingPathComponent(tempURL.lastPathComponent)
        try? FileManager.default.copyItem(at: tempURL, to: destURL)

        // 전사 요청 (키보드 확장과 동일한 메커니즘 사용)
        let request: [String: String] = ["audioPath": destURL.lastPathComponent]
        if let data = try? JSONSerialization.data(withJSONObject: request) {
            try? data.write(to: AppGroupConstants.keyboardRequestFile)
        }

        // Darwin Notification 발송
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(rawValue: AppGroupConstants.transcriptionRequestNotification as CFString),
            nil,
            nil,
            true
        )

        // 결과 대기 (최대 60초)
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(500))
            if let data = try? Data(contentsOf: AppGroupConstants.keyboardResultFile),
               let result = try? JSONSerialization.jsonObject(with: data) as? [String: String],
               let text = result["text"] {
                try? FileManager.default.removeItem(at: AppGroupConstants.keyboardResultFile)
                try? FileManager.default.removeItem(at: tempURL)
                return .result(value: text)
            }
        }

        try? FileManager.default.removeItem(at: tempURL)
        throw IntentError.timeout
    }

    enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
        case timeout

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .timeout: "전사 시간이 초과되었습니다."
            }
        }
    }
}

// MARK: - Shortcuts Provider

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
