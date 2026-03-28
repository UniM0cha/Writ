import SwiftUI
import SwiftData

struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedLanguage") private var selectedLanguage = "auto"
    @AppStorage("autoCopyEnabled") private var autoCopyEnabled = false

    private var isRecording: Bool { appState.recorderService.isRecording }
    private var isTranscribing: Bool { appState.isProcessingQueue }

    private enum RecordButtonState: Equatable {
        case idle, recording, transcribing
    }
    private var buttonState: RecordButtonState {
        if isRecording { return .recording }
        if isTranscribing { return .transcribing }
        return .idle
    }

    private var isModelReady: Bool {
        appState.modelManager.activeModel != nil
    }

    private var languages: [(code: String, name: String)] {
        AppGroupConstants.supportedLanguages
    }

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

                    // 파형 + 타이머 그룹 (수직 중앙)
                    VStack(spacing: WritSpacing.md) {
                        WaveformView(
                            power: appState.recorderService.averagePower,
                            isRecording: isRecording
                        )
                        .frame(height: 120)
                        .padding(.horizontal, WritSpacing.xxl)

                        timerDisplay
                    }

                    Spacer()

                    // 모델 표시
                    modelIndicator
                        .padding(.bottom, WritSpacing.xs)

                    // 녹음 버튼
                    recordButton
                        .padding(.bottom, 48)
                }
            }
            .navigationTitle("녹음")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(isRecording ? .dark : nil, for: .navigationBar)
            #endif
        }
    }

    // MARK: - Language Chip

    private var languageChip: some View {
        Menu {
            ForEach(languages, id: \.code) { code, name in
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
                Text(languages.first { $0.code == selectedLanguage }?.name ?? "자동 감지")
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

    // MARK: - Model Indicator

    /// 모델이 로드 중인지 (다운로드/최적화/로딩 상태)
    private var isModelLoading: Bool {
        appState.modelManager.models.contains {
            switch $0.state {
            case .downloading, .optimizing, .loading: return true
            default: return false
            }
        }
    }

    private var modelIndicator: some View {
        Group {
            if isModelLoading {
                HStack(spacing: WritSpacing.xs) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(isRecording ? .white : nil)
                    Text(modelStatusText)
                        .font(WritFont.caption)
                        .foregroundStyle(isRecording ? .white.opacity(0.7) : WritColor.secondaryText)

                    if let loadingModel = appState.modelManager.models.first(where: {
                        switch $0.state {
                        case .downloading, .optimizing, .loading: return true
                        default: return false
                        }
                    }) {
                        Button {
                            appState.modelManager.cancelDownload(loadingModel.identifier)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(isRecording ? .white.opacity(0.5) : WritColor.secondaryText)
                        }
                    }
                }
            } else if let active = appState.modelManager.activeModel {
                HStack(spacing: WritSpacing.xxs) {
                    Circle()
                        .fill(WritColor.success)
                        .frame(width: WritDimension.modelDotSize, height: WritDimension.modelDotSize)
                    Text("\(active.engine.displayName) \(active.displayName) 모델 사용 중")
                        .font(WritFont.caption)
                        .foregroundStyle(isRecording ? .white.opacity(0.7) : WritColor.secondaryText)
                }
            } else {
                Button {
                    appState.selectedTab = .settings
                } label: {
                    HStack(spacing: WritSpacing.xxs) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12))
                        Text("모델을 선택해주세요")
                            .font(WritFont.caption)
                    }
                    .foregroundStyle(WritColor.accent)
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
                    .strokeBorder(
                        isTranscribing ? WritColor.warning : WritColor.recordingRed,
                        lineWidth: WritDimension.recordButtonBorder
                    )
                    .frame(
                        width: WritDimension.recordButtonOuter,
                        height: WritDimension.recordButtonOuter
                    )

                // 내부: 원 ↔ 사각형 ↔ 스피너 모프
                if isRecording {
                    RoundedRectangle(cornerRadius: WritDimension.recordButtonStopRadius)
                        .fill(WritColor.recordingRed)
                        .frame(
                            width: WritDimension.recordButtonStopSize,
                            height: WritDimension.recordButtonStopSize
                        )
                } else if isTranscribing {
                    ProgressView()
                        .tint(WritColor.warning)
                } else {
                    Circle()
                        .fill(WritColor.recordingRed)
                        .frame(
                            width: WritDimension.recordButtonInner,
                            height: WritDimension.recordButtonInner
                        )
                }
            }
            .animation(WritAnimation.buttonMorph, value: buttonState)
        }
        .disabled(isTranscribing)
        .accessibilityLabel(
            isRecording ? "녹음 중지" :
            isTranscribing ? "전사 처리 중" : "녹음 시작"
        )
        .accessibilityHint(
            isTranscribing ? "전사가 완료되면 녹음을 시작할 수 있습니다" : ""
        )
    }

    // MARK: - Model Status Text

    private var modelStatusText: String {
        if let loading = appState.modelManager.models.first(where: {
            if case .loading = $0.state { return true }
            if case .downloading = $0.state { return true }
            if case .optimizing = $0.state { return true }
            return false
        }) {
            if case .downloading(let progress, let status) = loading.state {
                let label = status ?? "다운로드 중"
                return "\(loading.identifier.displayName) \(label) (\(Int(progress * 100))%)"
            }
            if case .optimizing = loading.state {
                return "\(loading.identifier.displayName) 최적화 중..."
            }
            return "\(loading.identifier.displayName) 로딩 중..."
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
        // 모델이 선택되지 않았으면 설정 탭으로 이동
        guard appState.modelManager.activeModel != nil || isModelLoading else {
            appState.selectedTab = .settings
            return
        }

        Task {
            try? await appState.startRecordingFlow()
        }
    }

    private func stopAndTranscribe() {
        appState.stopRecordingAndTranscribe()
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
