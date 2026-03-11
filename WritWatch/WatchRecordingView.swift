import SwiftUI
import AVFoundation

struct WatchRecordingView: View {
    @StateObject private var sessionManager = WatchSessionManager.shared
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var recorder: AVAudioRecorder?
    @State private var timer: Timer?
    @State private var waveformHeights: [CGFloat] = Array(repeating: 0.3, count: 9)

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if isRecording {
                    recordingStateView
                } else {
                    idleStateView
                }
            }
            .navigationTitle("Writ")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            sessionManager.activate()
        }
    }

    // MARK: - Idle State

    private var idleStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            // 72px 링 버튼 (3px 보더)
            Button(action: startRecording) {
                ZStack {
                    Circle()
                        .strokeBorder(Color(red: 1, green: 0.231, blue: 0.188), lineWidth: 3)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(Color(red: 1, green: 0.231, blue: 0.188))
                        .frame(width: 54, height: 54)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            // 연결 상태
            HStack(spacing: 4) {
                Circle()
                    .fill(sessionManager.isReachable
                        ? Color(red: 0.204, green: 0.78, blue: 0.349)
                        : Color(red: 0.557, green: 0.557, blue: 0.576))
                    .frame(width: 6, height: 6)
                Text(sessionManager.isReachable ? "iPhone 연결됨" : "연결 안 됨")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 기록 내비게이션
            NavigationLink {
                WatchRecordingListView()
            } label: {
                Label("기록", systemImage: "clock")
                    .font(.system(size: 14))
            }
        }
    }

    // MARK: - Recording State

    private var recordingStateView: some View {
        VStack(spacing: 8) {
            Spacer()

            // 타이머: 32px weight light
            Text(formatTime(recordingTime))
                .font(.system(size: 32, weight: .light))
                .monospacedDigit()

            // 9바 파형
            HStack(spacing: 2) {
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 1, green: 0.231, blue: 0.188))
                        .frame(width: 3, height: waveformHeights[index] * 32)
                }
            }
            .frame(height: 32)

            // 녹음 중 표시
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: 1, green: 0.231, blue: 0.188))
                    .frame(width: 6, height: 6)
                Text("녹음 중")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 1, green: 0.231, blue: 0.188))
            }

            Spacer()

            // 정지 버튼
            Button(action: stopRecording) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 48, height: 48)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 1, green: 0.231, blue: 0.188))
                        .frame(width: 18, height: 18)
                }
            }
            .buttonStyle(.plain)
        }
        .onAppear { startWaveformAnimation() }
    }

    // MARK: - Recording Actions

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
        let duration = rec.currentTime
        let url = rec.url
        rec.stop()
        recorder = nil
        isRecording = false

        let recordingId = UUID().uuidString

        // WatchConnectivity로 iPhone에 전송
        sessionManager.transferRecording(
            url: url,
            metadata: [
                "id": recordingId,
                "duration": duration,
                "fileName": url.lastPathComponent
            ]
        )

        recordingTime = 0
    }

    // MARK: - Waveform

    private func startWaveformAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { waveTimer in
            guard isRecording else {
                waveTimer.invalidate()
                return
            }
            withAnimation(.easeInOut(duration: 0.15)) {
                for i in 0..<waveformHeights.count {
                    waveformHeights[i] = CGFloat.random(in: 0.15...1.0)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
