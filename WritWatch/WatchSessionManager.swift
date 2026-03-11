import Foundation
import WatchConnectivity

/// Watch 측 WatchConnectivity 세션 관리
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var isReachable = false
    @Published var recordings: [WatchRecording] = []

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// 녹음 파일을 iPhone으로 전송
    func transferRecording(url: URL, metadata: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }

        let id = metadata["id"] as? String ?? UUID().uuidString

        // 녹음 목록에 추가
        let recording = WatchRecording(
            id: id,
            fileName: url.lastPathComponent,
            date: Date(),
            duration: metadata["duration"] as? TimeInterval ?? 0,
            status: .transferring
        )
        recordings.insert(recording, at: 0)

        WCSession.default.transferFile(url, metadata: metadata)
    }

    /// 녹음 상태 업데이트
    func updateRecordingStatus(id: String, status: WatchRecording.TransferStatus) {
        if let index = recordings.firstIndex(where: { $0.id == id }) {
            recordings[index].status = status
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    /// iPhone에서 전사 결과 수신
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let id = userInfo["recordingId"] as? String,
              let text = userInfo["transcription"] as? String else { return }

        DispatchQueue.main.async {
            self.updateRecordingStatus(id: id, status: .completed(text: text))
        }
    }

    /// 파일 전송 완료
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        guard let id = fileTransfer.file.metadata?["id"] as? String else { return }

        DispatchQueue.main.async {
            if error != nil {
                self.updateRecordingStatus(id: id, status: .failed)
            } else {
                self.updateRecordingStatus(id: id, status: .sent)
            }
        }
    }
}

// MARK: - WatchRecording Model

struct WatchRecording: Identifiable {
    let id: String
    let fileName: String
    let date: Date
    let duration: TimeInterval
    var status: TransferStatus

    enum TransferStatus: Equatable {
        case transferring
        case sent
        case completed(text: String)
        case failed

        static func == (lhs: TransferStatus, rhs: TransferStatus) -> Bool {
            switch (lhs, rhs) {
            case (.transferring, .transferring), (.sent, .sent), (.failed, .failed):
                return true
            case let (.completed(a), .completed(b)):
                return a == b
            default:
                return false
            }
        }
    }
}
