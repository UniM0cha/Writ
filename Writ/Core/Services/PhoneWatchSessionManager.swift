#if os(iOS)
import Foundation
import WatchConnectivity
import SwiftData

/// iPhone 측 WatchConnectivity 세션 관리
/// Watch에서 녹음 파일을 수신하여 전사하고 결과를 Watch로 반환
@MainActor
final class PhoneWatchSessionManager: NSObject, ObservableObject {
    static let shared = PhoneWatchSessionManager()

    private var modelManager: ModelManager?
    private var modelContainer: ModelContainer?

    private override init() {
        super.init()
    }

    func configure(modelManager: ModelManager, modelContainer: ModelContainer) {
        self.modelManager = modelManager
        self.modelContainer = modelContainer
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Watch에서 수신한 녹음 파일 전사 후 결과 반환
    private func handleReceivedFile(url: URL, metadata: [String: Any]) {
        guard let modelManager = self.modelManager else { return }
        let recordingId = metadata["id"] as? String ?? UUID().uuidString
        let duration = metadata["duration"] as? TimeInterval ?? 0

        // 녹음 파일을 영구 디렉토리로 복사
        let destDir = AppGroupConstants.recordingsDirectory
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destURL = destDir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: destURL)

        guard let modelContainer else { return }

        // SwiftData에 Recording 저장
        let context = ModelContext(modelContainer)
        let audioFileName = url.lastPathComponent
        let recording = Recording(
            duration: duration,
            audioFileName: audioFileName,
            sourceDevice: .watch
        )
        let transcription = Transcription(
            modelUsed: modelManager.activeModel?.displayName ?? "unknown",
            status: .pending
        )
        recording.transcription = transcription
        context.insert(recording)
        try? context.save()

        // 전사 실행
        Task {
            do {
                let output = try await modelManager.transcribe(
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

                // SwiftData에 전사 결과 업데이트
                let bgContext = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<Recording>(
                    predicate: #Predicate { $0.audioFileName == audioFileName }
                )
                if let savedRecording = try? bgContext.fetch(descriptor).first {
                    let segments = output.segments.enumerated().map { index, seg in
                        WritSegment(
                            text: seg.text,
                            startTime: seg.startTime,
                            endTime: seg.endTime,
                            orderIndex: index,
                            speaker: seg.speaker
                        )
                    }
                    savedRecording.transcription?.text = output.text
                    savedRecording.transcription?.status = .completed
                    savedRecording.transcription?.segments = segments
                    savedRecording.transcription?.modelUsed = modelManager.activeModel?.displayName ?? "unknown"
                    try? bgContext.save()
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
