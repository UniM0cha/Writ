import SwiftUI
import SwiftData
#if os(iOS)
import ActivityKit
#endif

struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedLanguage") private var selectedLanguage = "auto"
    @AppStorage("autoCopyEnabled") private var autoCopyEnabled = false

    @State private var currentFileName: String?
    #if os(iOS)
    @State private var currentActivity: Activity<WritActivityAttributes>?
    @State private var liveActivityTimer: Timer?
    #endif

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
            .onChange(of: appState.pendingStopRecording) { _, pending in
                if pending && isRecording {
                    stopAndTranscribe()
                    appState.pendingStopRecording = false
                }
            }
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
        .opacity(1.0)
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
        Task {
            do {
                currentFileName = try await appState.recorderService.startRecording()
                #if os(iOS)
                startLiveActivity()
                #endif
            } catch {
                // 녹음 시작 실패 시 무시 (UI에서 별도 처리 없음)
            }
        }

        // 모델이 아직 로드되지 않았으면 별도 Task로 백그라운드 로드
        if appState.modelManager.activeModel == nil {
            Task {
                await appState.modelManager.loadDefaultModelIfNeeded()
            }
        }
    }

    private func stopAndTranscribe() {
        guard let (fileName, duration) = appState.recorderService.stopRecording() else {
            print("[Writ] stopAndTranscribe: stopRecording returned nil")
            return
        }
        let language: String? = selectedLanguage == "auto" ? nil : selectedLanguage

        print("[Writ] stopAndTranscribe: fileName = \(fileName), duration = \(duration)")

        // 즉시 Recording 객체 생성 및 pending 상태로 저장
        let recording = Recording(
            duration: duration,
            audioFileName: fileName,
            languageCode: language,
            sourceDevice: .iPhone
        )
        let transcription = Transcription(
            text: "",
            modelUsed: appState.modelManager.activeModel?.displayName ?? "unknown",
            status: .pending
        )
        recording.transcription = transcription
        modelContext.insert(recording)

        do {
            try modelContext.save()
            print("[Writ] stopAndTranscribe: recording saved with persistentModelID = \(recording.persistentModelID)")
        } catch {
            print("[Writ] stopAndTranscribe: ERROR saving recording: \(error)")
        }

        let recordingID = recording.persistentModelID
        let autoCopy = autoCopyEnabled

        // 녹음 중단 → 즉시 Live Activity 종료
        #if os(iOS)
        endLiveActivity()
        #endif

        // 백그라운드에서 전사 시작 (RecordingView는 즉시 초기 상태로 리셋)
        Task {
            await appState.transcribeInBackground(
                recordingID: recordingID,
                audioFileName: fileName,
                language: language,
                autoCopy: autoCopy
            )
        }

        // 녹음 뷰 초기화 (다음 녹음 준비)
        currentFileName = nil
    }

    // MARK: - Live Activity

    #if os(iOS)
    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WritActivityAttributes()
        let startDate = Date()
        let state = WritActivityAttributes.ContentState(
            recordingDuration: 0,
            recordingStartDate: startDate,
            isTranscribing: false,
            averagePower: 0
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            currentActivity = activity

            // 0.3초마다 averagePower push
            liveActivityTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                Task { @MainActor in
                    self.pushLiveActivityPower(startDate: startDate)
                }
            }
        } catch {
            // Live Activity 시작 실패 — 무시 (핵심 기능 아님)
        }
    }

    private func pushLiveActivityPower(startDate: Date) {
        guard let activity = currentActivity else { return }
        let state = WritActivityAttributes.ContentState(
            recordingDuration: appState.recorderService.currentTime,
            recordingStartDate: startDate,
            isTranscribing: false,
            averagePower: appState.recorderService.averagePower
        )
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    private func endLiveActivity() {
        liveActivityTimer?.invalidate()
        liveActivityTimer = nil

        guard let activity = currentActivity else { return }
        Task {
            let finalState = WritActivityAttributes.ContentState(
                recordingDuration: 0,
                recordingStartDate: Date(),
                isTranscribing: false,
                averagePower: 0
            )
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        currentActivity = nil
    }
    #endif

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
