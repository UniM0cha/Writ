import SwiftUI
import AVFoundation

struct WatchRecordingView: View {
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var recorder: AVAudioRecorder?
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 16) {
            if isRecording {
                Text(formatTime(recordingTime))
                    .font(.system(size: 28, weight: .light, design: .monospaced))

                // 간단 파형
                HStack(spacing: 2) {
                    ForEach(0..<12, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.red)
                            .frame(width: 3, height: CGFloat.random(in: 8...32))
                    }
                }
                .frame(height: 32)

                Button(action: stopRecording) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 48, height: 48)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.red)
                            .frame(width: 18, height: 18)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text("Writ")
                    .font(.headline)

                Button(action: startRecording) {
                    Circle()
                        .fill(.red)
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: "mic.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                }
                .buttonStyle(.plain)

                NavigationLink("기록") {
                    WatchRecordingListView()
                }
                .font(.caption)
            }
        }
    }

    private func startRecording() {
        let fileName = "\(UUID().uuidString).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else { return }
        rec.record()
        recorder = rec
        isRecording = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime = rec.currentTime
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        guard let rec = recorder else { return }
        rec.stop()
        isRecording = false
        recordingTime = 0

        // TODO: WCSession.transferFile()로 iPhone에 전송
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
