import SwiftUI
import AVFoundation

struct KeyboardView: View {
    let textDocumentProxy: UITextDocumentProxy
    let advanceToNextInputMode: () -> Void

    @State private var state: KeyboardState = .idle
    @State private var recorder: AVAudioRecorder?
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var resultText: String?
    @State private var waveformHeights: [CGFloat] = Array(repeating: 0.3, count: 20)

    enum KeyboardState {
        case idle
        case recording
        case transcribing
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerView

            // 메인 콘텐츠
            ZStack {
                backgroundColor
                    .animation(.easeInOut(duration: 0.3), value: state)

                switch state {
                case .idle:
                    idleView
                case .recording:
                    recordingView
                case .transcribing:
                    transcribingView
                case .done:
                    doneView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backgroundColor: Color {
        switch state {
        case .recording:
            return Color(red: 0.11, green: 0.11, blue: 0.118) // #1c1c1e
        default:
            return Color(red: 0.82, green: 0.827, blue: 0.851) // #d1d3d9
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // 앱 로고
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0, green: 0.478, blue: 1),
                                    Color(red: 0.345, green: 0.337, blue: 0.839)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 20, height: 20)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                }
                Text("Writ")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(state == .recording
                        ? Color.white.opacity(0.7)
                        : Color(red: 0.2, green: 0.2, blue: 0.2))
            }

            Spacer()

            // 글로브 버튼
            Button(action: advanceToNextInputMode) {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundStyle(state == .recording
                        ? Color.white.opacity(0.7)
                        : Color(red: 0.2, green: 0.2, blue: 0.2))
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(state == .recording
            ? Color(red: 0.173, green: 0.173, blue: 0.18) // #2c2c2e
            : Color(red: 0.82, green: 0.827, blue: 0.851)) // #d1d3d9
        .animation(.easeInOut(duration: 0.3), value: state)
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 12) {
            Spacer()

            // 64px 빨간 마이크 버튼
            Button(action: startRecording) {
                ZStack {
                    Circle()
                        .fill(Color(red: 1, green: 0.231, blue: 0.188)) // #ff3b30
                        .frame(width: 64, height: 64)
                        .shadow(color: Color(red: 1, green: 0.231, blue: 0.188).opacity(0.3),
                                radius: 6, y: 4)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
            }

            // 힌트
            Text("탭하여 녹음")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))

            // 최근 전사 버튼
            Button(action: insertRecentTranscription) {
                Text("최근 전사문 삽입")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0, green: 0.478, blue: 1))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(red: 0, green: 0.478, blue: 1).opacity(0.1))
                    )
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Recording State

    private var recordingView: some View {
        VStack(spacing: 8) {
            Spacer()

            // 파형: 20바, 3px, red
            HStack(spacing: 3) {
                ForEach(0..<20, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 1, green: 0.231, blue: 0.188))
                        .frame(width: 3, height: waveformHeights[index] * 40)
                }
            }
            .frame(height: 40)

            // 타이머
            Text(formatTime(recordingTime))
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white)
                .monospacedDigit()

            // 녹음 중 라벨
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: 1, green: 0.231, blue: 0.188))
                    .frame(width: 6, height: 6)
                Text("녹음 중")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 1, green: 0.231, blue: 0.188))
            }

            Spacer()
                .frame(height: 8)

            // 정지 버튼: 48px, 3px red border, 20x20 빨간 사각형
            Button(action: stopRecording) {
                ZStack {
                    Circle()
                        .strokeBorder(Color(red: 1, green: 0.231, blue: 0.188), lineWidth: 3)
                        .frame(width: 48, height: 48)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 1, green: 0.231, blue: 0.188))
                        .frame(width: 20, height: 20)
                }
            }

            Spacer()
        }
        .padding(20)
        .onAppear { startWaveformAnimation() }
    }

    // MARK: - Transcribing State

    private var transcribingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color(red: 0, green: 0.478, blue: 1))
                .scaleEffect(1.2)
            Text("전사 중...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
        }
    }

    // MARK: - Done State

    private var doneView: some View {
        VStack(spacing: 12) {
            Spacer()

            // 48px 초록 체크 원
            ZStack {
                Circle()
                    .fill(Color(red: 0.204, green: 0.78, blue: 0.349)) // #34c759
                    .frame(width: 48, height: 48)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            // 완료 라벨
            Text("전사 완료 — 텍스트 삽입됨")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.204, green: 0.78, blue: 0.349))

            // 삽입된 텍스트 프리뷰
            if let text = resultText {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.204, green: 0.78, blue: 0.349).opacity(0.1))
                    )
            }

            Spacer()
                .frame(height: 8)

            // 다시 녹음 버튼
            Button(action: resetToIdle) {
                ZStack {
                    Circle()
                        .fill(Color(red: 1, green: 0.231, blue: 0.188))
                        .frame(width: 48, height: 48)
                        .shadow(color: Color(red: 1, green: 0.231, blue: 0.188).opacity(0.2),
                                radius: 4, y: 2)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }
            }

            Text("다시 녹음")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Actions

    private func startRecording() {
        let fileName = "\(UUID().uuidString).m4a"
        let url = AppGroupConstants.recordingsDirectory.appendingPathComponent(fileName)

        try? FileManager.default.createDirectory(
            at: AppGroupConstants.recordingsDirectory,
            withIntermediateDirectories: true
        )

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else { return }
        rec.record()
        recorder = rec
        state = .recording

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime = rec.currentTime
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        guard let rec = recorder else { return }
        let audioURL = rec.url
        rec.stop()
        recorder = nil
        state = .transcribing

        requestTranscription(audioURL: audioURL)
    }

    private func resetToIdle() {
        state = .idle
        recordingTime = 0
        resultText = nil
    }

    private func requestTranscription(audioURL: URL) {
        let request = ["audioPath": audioURL.lastPathComponent]
        if let data = try? JSONSerialization.data(withJSONObject: request) {
            try? data.write(to: AppGroupConstants.keyboardRequestFile)
        }

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(rawValue: AppGroupConstants.transcriptionRequestNotification as CFString),
            nil,
            nil,
            true
        )

        pollForResult()
    }

    private func pollForResult() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { pollTimer in
            guard let data = try? Data(contentsOf: AppGroupConstants.keyboardResultFile),
                  let result = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let text = result["text"] else { return }

            pollTimer.invalidate()
            resultText = text
            textDocumentProxy.insertText(text)
            try? FileManager.default.removeItem(at: AppGroupConstants.keyboardResultFile)
            state = .done

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if state == .done {
                    resetToIdle()
                }
            }
        }
    }

    private func insertRecentTranscription() {
        // App Group에서 최근 전사문 읽기
        let recentFile = AppGroupConstants.containerURL.appendingPathComponent("recent_transcription.txt")
        if let text = try? String(contentsOf: recentFile, encoding: .utf8), !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
    }

    // MARK: - Waveform Animation

    private func startWaveformAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { waveTimer in
            guard state == .recording else {
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
