import AppIntents
import Foundation

// MARK: - 녹음 시작

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "녹음 시작"
    static var description: IntentDescription = "Writ에서 음성 녹음을 시작합니다."
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        try await AppState.shared.startRecordingFlow()
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

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // 파일을 녹음 디렉토리에 저장
        let destDir = AppGroupConstants.recordingsDirectory
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let ext = (audioFile.filename as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        let destURL = destDir.appendingPathComponent("intent_\(UUID().uuidString).\(safeExt)")
        try audioFile.data.write(to: destURL)

        let lang = AppGroupConstants.resolvedLanguage(from: language)

        do {
            let appState = AppState.shared
            if appState.modelManager.activeModel == nil {
                await appState.modelManager.loadDefaultModelIfNeeded()
            }

            let output = try await appState.modelManager.transcribe(
                audioURL: destURL, language: lang, progressCallback: nil
            )

            try? FileManager.default.removeItem(at: destURL)
            return .result(value: output.text)
        } catch {
            try? FileManager.default.removeItem(at: destURL)
            throw error
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
    }
}
