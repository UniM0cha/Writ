import AVFoundation
import Foundation

/// 오디오 녹음 서비스. App Group 컨테이너에 녹음 파일을 저장한다.
@MainActor
final class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var currentTime: TimeInterval = 0
    @Published var averagePower: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentFileName: String?

    override init() {
        super.init()
        ensureRecordingsDirectory()
    }

    /// 녹음 시작. 녹음 파일명을 반환.
    func startRecording() async throws -> String {
        #if os(iOS)
        // 마이크 권한 확인 및 요청
        let permission = AVAudioApplication.shared.recordPermission
        if permission == .undetermined {
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            guard granted else {
                throw AudioRecorderError.microphonePermissionDenied
            }
        } else if permission == .denied {
            throw AudioRecorderError.microphonePermissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        #endif

        let fileName = "\(UUID().uuidString).m4a"
        let url = AppGroupConstants.recordingsDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
            AVEncoderBitRateKey: 128000
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.delegate = self
        recorder.record()

        audioRecorder = recorder
        currentFileName = fileName
        isRecording = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.updateMeters()
            }
        }

        return fileName
    }

    /// 녹음 중지. (파일명, 녹음 시간) 반환.
    func stopRecording() -> (String, TimeInterval)? {
        guard let recorder = audioRecorder, let fileName = currentFileName else {
            print("[Writ] AudioRecorderService.stopRecording: no active recorder or fileName")
            return nil
        }
        let duration = recorder.currentTime
        recorder.stop()

        let fileURL = AppGroupConstants.recordingsDirectory.appendingPathComponent(fileName)
        print("[Writ] AudioRecorderService.stopRecording: fileName = \(fileName)")
        print("[Writ] AudioRecorderService.stopRecording: duration = \(duration)")
        print("[Writ] AudioRecorderService.stopRecording: file exists = \(FileManager.default.fileExists(atPath: fileURL.path))")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int {
            print("[Writ] AudioRecorderService.stopRecording: file size = \(size) bytes")
        }

        timer?.invalidate()
        timer = nil
        audioRecorder = nil
        isRecording = false
        currentTime = 0
        averagePower = 0

        return (fileName, duration)
    }

    private func updateMeters() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        currentTime = recorder.currentTime
        averagePower = recorder.averagePower(forChannel: 0)
    }

    private func ensureRecordingsDirectory() {
        try? FileManager.default.createDirectory(
            at: AppGroupConstants.recordingsDirectory,
            withIntermediateDirectories: true
        )
    }
}

enum AudioRecorderError: LocalizedError {
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied: "마이크 접근 권한이 필요합니다. 설정에서 허용해주세요."
        }
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            isRecording = false
        }
    }
}
