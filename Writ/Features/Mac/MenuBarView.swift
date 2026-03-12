import SwiftUI
import SwiftData

#if os(macOS)
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    private var isRecording: Bool { appState.recorderService.isRecording }

    var body: some View {
        VStack(spacing: 0) {
            // 녹음 버튼
            recordButton
                .padding(.horizontal, WritSpacing.md)
                .padding(.top, WritSpacing.md)
                .padding(.bottom, WritSpacing.xs)

            // fn 키 힌트
            Text(isRecording
                 ? "fn 놓기로 녹음 중지 + 전사"
                 : "fn 길게 누르기로 빠른 녹음")
                .font(WritFont.smallCaption)
                .foregroundStyle(WritColor.secondaryText)
                .padding(.bottom, WritSpacing.sm)

            Divider()

            // 모델 정보
            HStack {
                Text("모델")
                    .font(WritFont.caption)
                    .foregroundStyle(WritColor.secondaryText)
                Spacer()
                HStack(spacing: WritSpacing.xxs) {
                    Circle()
                        .fill(appState.modelManager.activeModel != nil ? WritColor.success : WritColor.secondaryText)
                        .frame(width: WritDimension.modelDotSize, height: WritDimension.modelDotSize)
                    Text(appState.modelManager.activeModel?.displayName ?? "없음")
                        .font(WritFont.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(WritColor.primaryText)
                }
            }
            .padding(.horizontal, WritSpacing.md)
            .padding(.vertical, WritSpacing.sm)

            Divider()

            // 최근 전사 섹션
            if !recentRecordings.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("최근 전사")
                        .font(WritFont.smallCaption)
                        .foregroundStyle(WritColor.secondaryText)
                        .textCase(.uppercase)
                        .padding(.horizontal, WritSpacing.md)
                        .padding(.top, WritSpacing.sm)
                        .padding(.bottom, WritSpacing.xxs)

                    ForEach(recentRecordings) { recording in
                        recentRow(recording)
                    }
                }
            }

            Divider()

            // 메인 윈도우 열기
            Button {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.title == "Writ" {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Text("메인 윈도우 열기")
                    .font(WritFont.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(WritColor.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, WritSpacing.sm)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, WritSpacing.md)
            .padding(.bottom, WritSpacing.xs)
        }
        .frame(width: 320)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button(action: toggleRecording) {
            HStack(spacing: WritSpacing.xs) {
                if isRecording {
                    Circle()
                        .fill(WritColor.recordingRed)
                        .frame(width: 8, height: 8)
                        .opacity(pulseOpacity)
                        .onAppear {
                            withAnimation(WritAnimation.pulse) {
                                pulseOpacity = 0.3
                            }
                        }
                        .onDisappear { pulseOpacity = 1.0 }

                    Text(formatTime(appState.recorderService.currentTime))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)

                    Spacer()

                    HStack(spacing: WritSpacing.xxs) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text("중지")
                            .font(WritFont.caption)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                    Text("녹음 시작")
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, WritSpacing.sm)
            .padding(.horizontal, WritSpacing.md)
            .background(
                isRecording ? Color.black : WritColor.recordingRed,
                in: RoundedRectangle(cornerRadius: WritRadius.medium)
            )
        }
        .buttonStyle(.plain)
        .disabled(appState.modelManager.activeModel == nil && !isRecording)
    }

    @State private var pulseOpacity: Double = 1.0

    // MARK: - Recent Recordings

    private var recentRecordings: [Recording] {
        Array(recordings.prefix(3))
    }

    private func recentRow(_ recording: Recording) -> some View {
        Button {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.title == "Writ" {
                window.makeKeyAndOrderFront(nil)
            }
        } label: {
            HStack(spacing: WritSpacing.sm) {
                statusIcon(for: recording)

                VStack(alignment: .leading, spacing: WritSpacing.xxxs) {
                    Text(recording.transcription?.text.prefix(40).description ?? "전사 대기 중")
                        .font(WritFont.caption)
                        .foregroundStyle(WritColor.primaryText)
                        .lineLimit(1)

                    Text("\(formatDuration(recording.duration)) · \(relativeTime(recording.createdAt))")
                        .font(WritFont.smallCaption)
                        .foregroundStyle(WritColor.secondaryText)
                }

                Spacer()

                if let text = recording.transcription?.text, !text.isEmpty {
                    Button {
                        ClipboardService.copy(text)
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 13))
                            .foregroundStyle(WritColor.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, WritSpacing.md)
            .padding(.vertical, WritSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusIcon(for recording: Recording) -> some View {
        switch recording.transcription?.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(WritColor.success)
        case .inProgress:
            ProgressView()
                .controlSize(.small)
        case .pending:
            Image(systemName: "clock")
                .font(.system(size: 14))
                .foregroundStyle(WritColor.secondaryText)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(WritColor.recordingRed)
        case nil:
            Image(systemName: "clock")
                .font(.system(size: 14))
                .foregroundStyle(WritColor.secondaryText)
        }
    }

    // MARK: - Helpers

    private func toggleRecording() {
        if isRecording {
            appState.stopRecordingAndTranscribe()
        } else {
            Task {
                try? await appState.startRecordingFlow()
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private func relativeTime(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}
#endif
