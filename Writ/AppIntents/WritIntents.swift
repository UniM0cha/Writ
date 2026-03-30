import AppIntents
import Foundation
import SwiftData

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

            guard appState.modelManager.activeModel != nil else {
                throw WritIntentError.noModelSelected
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

// MARK: - 녹음 정지 + 전사 (단축어용 — 결과 반환)

struct StopAndTranscribeIntent: AppIntent {
    static var title: LocalizedStringResource = "녹음 정지 및 전사"
    static var description: IntentDescription = "현재 녹음을 정지하고 전사 결과를 반환합니다."
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let appState = AppState.shared

        guard appState.recorderService.isRecording else {
            throw WritIntentError.noRecordingInProgress
        }

        guard appState.modelManager.activeModel != nil else {
            throw WritIntentError.noModelSelected
        }

        // 녹음 정지
        guard let (fileName, _) = appState.recorderService.stopRecording() else {
            throw WritIntentError.noRecordingInProgress
        }

        let audioURL = AppGroupConstants.recordingsDirectory.appendingPathComponent(fileName)
        let language = AppGroupConstants.resolvedLanguage(
            from: UserDefaults.standard.string(forKey: "selectedLanguage")
        )

        // 전사 (CoreML/ANE — 백그라운드 동작 여부가 여기서 검증됨)
        let output = try await appState.modelManager.transcribe(
            audioURL: audioURL, language: language, progressCallback: nil
        )

        return .result(value: output.text)
    }
}

// MARK: - 최근 전사 결과 가져오기 (폴백용)

struct GetLatestTranscriptionIntent: AppIntent {
    static var title: LocalizedStringResource = "최근 전사 결과 가져오기"
    static var description: IntentDescription = "가장 최근 전사된 텍스트를 반환합니다."
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let context = ModelContext(AppState.shared.modelContainer)
        var descriptor = FetchDescriptor<Recording>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let recordings = try? context.fetch(descriptor),
              let latest = recordings.first,
              let text = latest.transcription?.text,
              latest.transcription?.status == .completed,
              !text.isEmpty else {
            throw WritIntentError.noTranscriptionAvailable
        }

        return .result(value: text)
    }
}

// MARK: - Error

enum WritIntentError: LocalizedError {
    case noModelSelected
    case noRecordingInProgress
    case noTranscriptionAvailable

    var errorDescription: String? {
        switch self {
        case .noModelSelected: "음성 인식 모델이 선택되지 않았습니다. Writ 앱에서 모델을 먼저 다운로드해주세요."
        case .noRecordingInProgress: "진행 중인 녹음이 없습니다."
        case .noTranscriptionAvailable: "전사 결과가 없습니다."
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
            intent: StopAndTranscribeIntent(),
            phrases: [
                "Stop recording and transcribe with \(.applicationName)",
                "\(.applicationName) 녹음 정지하고 전사"
            ],
            shortTitle: "녹음 정지 및 전사",
            systemImageName: "stop.circle.fill"
        )
        AppShortcut(
            intent: GetLatestTranscriptionIntent(),
            phrases: [
                "Get latest transcription from \(.applicationName)",
                "\(.applicationName) 최근 전사 결과"
            ],
            shortTitle: "최근 전사 결과",
            systemImageName: "doc.text"
        )
    }
}
