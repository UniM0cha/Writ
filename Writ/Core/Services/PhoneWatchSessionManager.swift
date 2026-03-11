#if os(iOS)
import Foundation
import WatchConnectivity
import SwiftData

/// iPhone 측 WatchConnectivity 세션 관리
/// Watch에서 녹음 파일을 수신하여 전사하고 결과를 Watch로 반환
@MainActor
final class PhoneWatchSessionManager: NSObject, ObservableObject {
    static let shared = PhoneWatchSessionManager()

    private var engine: WhisperKitEngine?
    private var modelContainer: ModelContainer?

    private override init() {
        super.init()
    }

    func configure(engine: WhisperKitEngine, modelContainer: ModelContainer) {
        self.engine = engine
        self.modelContainer = modelContainer
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Watch에서 수신한 녹음 파일 전사 후 결과 반환
    private func handleReceivedFile(url: URL, metadata: [String: Any]) {
        guard let engine = self.engine else { return }
        let recordingId = metadata["id"] as? String ?? UUID().uuidString
        let duration = metadata["duration"] as? TimeInterval ?? 0

        // 녹음 파일을 영구 디렉토리로 복사
        let destDir = AppGroupConstants.recordingsDirectory
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destURL = destDir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: destURL)

        // SwiftData에 저장
        if let modelContainer {
            let context = ModelContext(modelContainer)
            let recording = Recording(
                duration: duration,
                audioFileName: url.lastPathComponent,
                sourceDevice: .watch
            )
            context.insert(recording)
            try? context.save()
        }

        // 전사 실행
        Task {
            do {
                let output = try await engine.transcribe(
                    audioURL: destURL,
                    language: nil,
                    progressCallback: nil
                )

                // 결과를 Watch로 전송
                let result: [String: Any] = [
                    "recordingId": recordingId,
                    "transcription": output.text,
                    "language": output.language ?? "unknown"
                ]

                if WCSession.default.activationState == .activated {
                    WCSession.default.transferUserInfo(result)
                }

                // SwiftData에 전사 결과 저장
                if let modelContainer {
                    let context = ModelContext(modelContainer)
                    let segments = output.segments.map { seg in
                        WritSegment(
                            text: seg.text,
                            startTime: seg.startTime,
                            endTime: seg.endTime
                        )
                    }
                    let transcription = Transcription(
                        text: output.text,
                        modelUsed: engine.currentModel?.rawValue ?? "unknown",
                        status: .completed,
                        segments: segments
                    )
                    context.insert(transcription)
                    try? context.save()
                }
            } catch {
                // 실패 시에도 Watch에 알림
                let result: [String: Any] = [
                    "recordingId": recordingId,
                    "error": error.localizedDescription
                ]
                if WCSession.default.activationState == .activated {
                    WCSession.default.transferUserInfo(result)
                }
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneWatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    /// Watch에서 전송된 녹음 파일 수신
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let url = file.fileURL
        let metadata = file.metadata ?? [:]
        Task { @MainActor in
            self.handleReceivedFile(url: url, metadata: metadata)
        }
    }
}
#endif
