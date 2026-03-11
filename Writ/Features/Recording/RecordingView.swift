import SwiftUI
import SwiftData

struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedLanguage") private var selectedLanguage = "auto"
    @AppStorage("autoCopyEnabled") private var autoCopyEnabled = false

    @State private var currentFileName: String?
    @State private var transcriptionResult: String?
    @State private var isTranscribing = false
    @State private var errorMessage: String?

    private var isRecording: Bool { appState.recorderService.isRecording }

    private var isModelReady: Bool {
        appState.modelManager.activeModel != nil
    }

    private let languages: [(String, String)] = [
        ("auto", "자동 감지"),
        ("ko", "한국어"),
        ("en", "English"),
        ("ja", "日本語"),
        ("zh", "中文"),
        ("es", "Español"),
        ("fr", "Français"),
        ("de", "Deutsch")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // 배경
                (isRecording ? WritColor.recordingBackground : WritColor.background)
                    .ignoresSafeArea()
                    .animation(WritAnimation.backgroundTransition, value: isRecording)

                VStack(spacing: 0) {
                    // 언어 선택 칩
                    languageChip
                        .padding(.top, WritSpacing.sm)

                    Spacer()

                    // 파형
                    WaveformView(
                        power: appState.recorderService.averagePower,
                        isRecording: isRecording
                    )
                    .frame(height: 120)
                    .padding(.horizontal, WritSpacing.xxl)

                    // 타이머
                    timerDisplay
                        .padding(.top, WritSpacing.lg)

                    Spacer()

                    // 전사 결과 / 진행중 / 에러
                    resultSection

                    // 모델 표시
                    modelIndicator
                        .padding(.bottom, WritSpacing.xs)

                    // 녹음 버튼
                    recordButton
                        .padding(.bottom, 48)
                }
            }
            .navigationTitle("녹음")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(isRecording ? .dark : nil, for: .navigationBar)
        }
    }

    // MARK: - Language Chip

    private var languageChip: some View {
        Menu {
            ForEach(languages, id: \.0) { code, name in
                Button {
                    selectedLanguage = code
                } label: {
                    HStack {
                        Text(name)
                        if selectedLanguage == code {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: WritSpacing.xxs) {
                Image(systemName: "globe")
                    .font(.system(size: 13))
                Text(languages.first { $0.0 == selectedLanguage }?.1 ?? "자동 감지")
                    .font(WritFont.caption)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isRecording ? .white : WritColor.primaryText)
            .padding(.horizontal, WritSpacing.sm)
            .padding(.vertical, WritSpacing.xs)
            .background(
                Capsule()
                    .fill(isRecording ? Color.white.opacity(0.15) : WritColor.chipBackground)
            )
        }
        .animation(WritAnimation.backgroundTransition, value: isRecording)
    }

    // MARK: - Timer

    private var timerDisplay: some View {
        VStack(spacing: WritSpacing.xxs) {
            Text(formatTime(appState.recorderService.currentTime))
                .font(WritFont.timer)
                .tracking(2)
                .foregroundStyle(isRecording ? .white : WritColor.primaryText)
                .contentTransition(.numericText())

            if isRecording {
                HStack(spacing: WritSpacing.xxs) {
                    Circle()
                        .fill(WritColor.recordingRed)
                        .frame(width: WritDimension.modelDotSize, height: WritDimension.modelDotSize)
                        .modifier(PulseModifier())
                    Text("녹음 중")
                        .font(WritFont.caption)
                        .foregroundStyle(WritColor.recordingRed)
                }
            }
        }
        .animation(WritAnimation.backgroundTransition, value: isRecording)
    }

    // MARK: - Result Section

    @ViewBuilder
    private var resultSection: some View {
        if let result = transcriptionResult {
            ScrollView {
                Text(result)
                    .font(.body)
                    .foregroundStyle(isRecording ? .white : WritColor.primaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: WritRadius.card))
            .padding(.horizontal, WritSpacing.md)
        }

        if isTranscribing {
            HStack(spacing: WritSpacing.xs) {
                ProgressView()
                    .tint(isRecording ? .white : WritColor.accent)
                Text("전사 중...")
                    .font(WritFont.caption)
                    .foregroundStyle(isRecording ? .white : WritColor.secondaryText)
            }
            .padding()
        }

        if let error = errorMessage {
            Text(error)
                .font(WritFont.caption)
                .foregroundStyle(WritColor.recordingRed)
                .padding()
        }
    }

    // MARK: - Model Indicator

    private var modelIndicator: some View {
        Group {
            if !isModelReady {
                HStack(spacing: WritSpacing.xs) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(isRecording ? .white : nil)
                    Text(modelStatusText)
                        .font(WritFont.caption)
                        .foregroundStyle(isRecording ? .white.opacity(0.7) : WritColor.secondaryText)
                }
            } else if let active = appState.modelManager.activeModel {
                HStack(spacing: WritSpacing.xxs) {
                    Circle()
                        .fill(WritColor.success)
                        .frame(width: WritDimension.modelDotSize, height: WritDimension.modelDotSize)
                    Text("\(active.displayName) 모델 사용 중")
                        .font(WritFont.caption)
                        .foregroundStyle(isRecording ? .white.opacity(0.7) : WritColor.secondaryText)
                }
            }
        }
        .animation(WritAnimation.backgroundTransition, value: isRecording)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                // 외부 링
                Circle()
                    .strokeBorder(WritColor.recordingRed, lineWidth: WritDimension.recordButtonBorder)
                    .frame(
                        width: WritDimension.recordButtonOuter,
                        height: WritDimension.recordButtonOuter
                    )

                // 내부: 원 ↔ 사각형 모프
                if isRecording {
                    RoundedRectangle(cornerRadius: WritDimension.recordButtonStopRadius)
                        .fill(WritColor.recordingRed)
                        .frame(
                            width: WritDimension.recordButtonStopSize,
                            height: WritDimension.recordButtonStopSize
                        )
                } else {
                    Circle()
                        .fill(WritColor.recordingRed)
                        .frame(
                            width: WritDimension.recordButtonInner,
                            height: WritDimension.recordButtonInner
                        )
                }
            }
            .animation(WritAnimation.buttonMorph, value: isRecording)
        }
        .disabled(!isModelReady && !isRecording)
        .opacity(!isModelReady && !isRecording ? 0.4 : 1.0)
    }

    // MARK: - Model Status Text

    private var modelStatusText: String {
        if let active = appState.modelManager.activeModel {
            return "\(active.displayName) 모델 준비됨"
        }
        if let loading = appState.modelManager.models.first(where: {
            if case .loading = $0.state { return true }
            if case .downloading = $0.state { return true }
            return false
        }) {
            if case .downloading(let progress) = loading.state {
                return "\(loading.variant.displayName) 다운로드 중 (\(Int(progress * 100))%)"
            }
            return "\(loading.variant.displayName) 로딩 중..."
        }
        return "모델을 로드하는 중..."
    }

    // MARK: - Actions

    private func toggleRecording() {
        if isRecording {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        transcriptionResult = nil
        errorMessage = nil
        do {
            currentFileName = try appState.recorderService.startRecording()
        } catch {
            errorMessage = "녹음을 시작할 수 없습니다: \(error.localizedDescription)"
        }
    }

    private func stopAndTranscribe() {
        guard let (fileName, duration) = appState.recorderService.stopRecording() else { return }
        let audioURL = AppGroupConstants.recordingsDirectory.appendingPathComponent(fileName)
        let language: String? = selectedLanguage == "auto" ? nil : selectedLanguage

        isTranscribing = true
        Task {
            do {
                let output = try await appState.modelManager.transcribe(
                    audioURL: audioURL,
                    language: language,
                    progressCallback: nil
                )
                transcriptionResult = output.text

                let recording = Recording(
                    duration: duration,
                    audioFileName: fileName,
                    languageCode: language,
                    sourceDevice: .iPhone
                )

                let segments = output.segments.enumerated().map { index, seg in
                    WritSegment(
                        text: seg.text,
                        startTime: seg.startTime,
                        endTime: seg.endTime,
                        orderIndex: index
                    )
                }

                let transcription = Transcription(
                    text: output.text,
                    modelUsed: appState.modelManager.activeModel?.displayName ?? "unknown",
                    status: .completed,
                    segments: segments
                )

                recording.transcription = transcription
                modelContext.insert(recording)
                try modelContext.save()

                if autoCopyEnabled {
                    ClipboardService.copy(output.text)
                }
            } catch {
                errorMessage = "전사 실패: \(error.localizedDescription)"
            }
            isTranscribing = false
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let centiseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }
}

// MARK: - Pulse Animation Modifier

private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .onAppear {
                withAnimation(WritAnimation.pulse) {
                    isPulsing = true
                }
            }
    }
}
