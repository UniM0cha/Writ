import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Lock Screen Live Activity View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<WritActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // 앱 아이콘
            ZStack {
                RoundedRectangle(cornerRadius: 8)
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
                    .frame(width: 36, height: 36)
                Image(systemName: phaseIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(phaseTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                phaseSubtitle
            }

            Spacer()

            // 오른쪽 영역
            trailingContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .activityBackgroundTint(.black.opacity(0.8))
    }

    private var phaseIcon: String {
        switch context.state.phase {
        case .recording: "mic.fill"
        case .transcribing: "text.bubble.fill"
        case .completed: "checkmark.circle.fill"
        }
    }

    private var phaseTitle: String {
        switch context.state.phase {
        case .recording: "녹음 중"
        case .transcribing: "전사 중..."
        case .completed: "전사 완료"
        }
    }

    @ViewBuilder
    private var phaseSubtitle: some View {
        switch context.state.phase {
        case .recording:
            Text(context.state.recordingStartDate, style: .timer)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
        case .transcribing:
            Text("\(Int(context.state.transcriptionProgress * 100))%")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
        case .completed:
            Text("붙여넣기하세요")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch context.state.phase {
        case .recording:
            Button(intent: StopRecordingIntent()) {
                ZStack {
                    Circle()
                        .fill(Color.writRecordingRed)
                        .frame(width: 32, height: 32)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: 10, height: 10)
                }
            }
            .buttonStyle(.plain)
        case .transcribing:
            ProgressView(value: Double(context.state.transcriptionProgress))
                .tint(.blue)
                .frame(width: 60)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
        }
    }
}
