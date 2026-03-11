import SwiftUI

#if os(macOS)
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("selectedLanguage") private var selectedLanguage = "auto"
    @State private var currentFileName: String?
    @State private var isTranscribing = false
    @State private var lastResult: String?
    @State private var errorMessage: String?

    private var isRecording: Bool { appState.recorderService.isRecording }

    var body: some View {
        VStack(spacing: WritSpacing.sm) {
            // 녹음 버튼
            Button(action: toggleRecording) {
                HStack(spacing: WritSpacing.xs) {
                    if isRecording {
                        // 펄스 빨간 점
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)

                        Text(formatTime(appState.recorderService.currentTime))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                    } else if isTranscribing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("전사 중...")
                            .foregroundStyle(WritColor.primaryText)
                    } else {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.white)
                        Text("녹음 시작")
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, WritSpacing.sm)
                .background(
                    isRecording || !isTranscribing
                        ? WritColor.recordingRed
                        : WritColor.secondaryText,
                    in: RoundedRectangle(cornerRadius: WritRadius.sheet)
                )
            }
            .buttonStyle(.plain)
            .disabled(isTranscribing || appState.modelManager.activeModel == nil)

            // 파형 (녹음 중)
            if isRecording {
                WaveformView(
                    power: appState.recorderService.averagePower,
                    isRecording: true
                )
                .frame(height: 32)
            }

            if !isRecording && !isTranscribing {
                Text("fn 키를 길게 눌러 녹음")
                    .font(WritFont.caption)
                    .foregroundStyle(WritColor.secondaryText)
            }

            // 최근 전사 결과
            if let result = lastResult {
                VStack(alignment: .leading, spacing: WritSpacing.xxs) {
                    Text("최근 전사")
                        .font(WritFont.smallCaption)
                        .foregroundStyle(WritColor.tertiaryText)
                    Text(result)
                        .font(WritFont.caption)
                        .lineLimit(3)
                        .foregroundStyle(WritColor.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(WritSpacing.xs)
                .background(WritColor.background, in: RoundedRectangle(cornerRadius: WritRadius.small))
            }

            if let error = errorMessage {
                Text(error)
                    .font(WritFont.caption)
                    .foregroundStyle(WritColor.recordingRed)
            }

            Divider()

            // 모델 정보
            HStack {
                Circle()
                    .fill(appState.modelManager.activeModel != nil ? WritColor.success : WritColor.secondaryText)
                    .frame(width: WritDimension.modelDotSize, height: WritDimension.modelDotSize)
                Text("모델")
                    .font(WritFont.caption)
                    .foregroundStyle(WritColor.secondaryText)
                Spacer()
                Text(appState.modelManager.activeModel?.displayName ?? "없음")
                    .font(WritFont.caption)
                    .foregroundStyle(WritColor.secondaryText)
            }

            Divider()

            Button("전체 기록 보기") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.plain)

            Button("설정...") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.plain)

            Divider()

            Button("종료") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(WritSpacing.sm)
        .frame(width: 320)
    }

    private func toggleRecording() {
        if isRecording {
            stopAndTranscribe()
        } else {
            errorMessage = nil
            lastResult = nil
            currentFileName = try? appState.recorderService.startRecording()
        }
    }

    private func stopAndTranscribe() {
        guard let (fileName, _) = appState.recorderService.stopRecording() else { return }
        let audioURL = AppGroupConstants.recordingsDirectory.appendingPathComponent(fileName)
        let language: String? = selectedLanguage == "auto" ? nil : selectedLanguage

        isTranscribing = true
        errorMessage = nil
        Task {
            do {
                let output = try await appState.modelManager.transcribe(
                    audioURL: audioURL,
                    language: language,
                    progressCallback: nil
                )
                lastResult = output.text
                ClipboardService.copy(output.text)
            } catch {
                errorMessage = "전사 실패: \(error.localizedDescription)"
            }
            isTranscribing = false
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
#endif
