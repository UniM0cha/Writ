import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// WritActivityAttributes는 Writ/Core/Models/WritActivityAttributes.swift에서 공유

// MARK: - Live Activity Widget

struct WritLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WritActivityAttributes.self) { context in
            // 잠금 화면 Live Activity
            LockScreenLiveActivityView(context: context)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
            } compactLeading: {
                compactLeadingContent(context: context)
            } compactTrailing: {
                compactTrailingContent(context: context)
            } minimal: {
                minimalContent(phase: context.state.phase)
            }
        }
    }

    // MARK: - Dynamic Island Expanded

    @ViewBuilder
    private func expandedLeading(context: ActivityViewContext<WritActivityAttributes>) -> some View {
        switch context.state.phase {
        case .recording:
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.writRecordingRed)
                Text(context.state.recordingStartDate, style: .timer)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(maxHeight: .infinity, alignment: .center)
        case .transcribing:
            EmptyView()
        case .completed:
            Text("전사 완료")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func expandedCenter(context: ActivityViewContext<WritActivityAttributes>) -> some View {
        switch context.state.phase {
        case .recording:
            EmptyView()
        case .transcribing:
            VStack(spacing: 4) {
                Text("전사 중...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                ProgressView(value: Double(context.state.transcriptionProgress))
                    .tint(.blue)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        case .completed:
            EmptyView()
        }
    }

    @ViewBuilder
    private func expandedTrailing(context: ActivityViewContext<WritActivityAttributes>) -> some View {
        switch context.state.phase {
        case .recording:
            Button(intent: StopRecordingIntent()) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.writRecordingRed)
                        .frame(width: 32, height: 32)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white)
                        .frame(width: 12, height: 12)
                }
            }
            .buttonStyle(.plain)
            .frame(maxHeight: .infinity, alignment: .center)
        case .transcribing:
            Text("\(Int(context.state.transcriptionProgress * 100))%")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.blue)
                .monospacedDigit()
                .frame(maxHeight: .infinity, alignment: .center)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
                .frame(width: 32, height: 32)
                .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    // MARK: - Compact

    @ViewBuilder
    private func compactLeadingContent(context: ActivityViewContext<WritActivityAttributes>) -> some View {
        switch context.state.phase {
        case .recording:
            Circle()
                .fill(Color.writRecordingRed)
                .frame(width: 8, height: 8)
        case .transcribing:
            HStack(spacing: 6) {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                Text("전사 중")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        case .completed:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                Text("완료")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private func compactTrailingContent(context: ActivityViewContext<WritActivityAttributes>) -> some View {
        switch context.state.phase {
        case .recording:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(context.state.recordingStartDate, style: .timer)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 52)
        case .transcribing:
            Text("\(Int(context.state.transcriptionProgress * 100))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.blue)
                .monospacedDigit()
        case .completed:
            EmptyView()
        }
    }

    // MARK: - Minimal

    @ViewBuilder
    private func minimalContent(phase: ActivityPhase) -> some View {
        switch phase {
        case .recording:
            Circle()
                .fill(Color.writRecordingRed)
                .frame(width: 8, height: 8)
        case .transcribing:
            Circle()
                .fill(.blue)
                .frame(width: 8, height: 8)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        }
    }
}
