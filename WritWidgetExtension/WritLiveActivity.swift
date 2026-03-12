import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// WritActivityAttributes는 Writ/Core/Models/WritActivityAttributes.swift에서 공유

private extension Color {
    static let writRecordingRed = Color(red: 1, green: 0.231, blue: 0.188)
}

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
                    phaseIndicator(phase: context.state.phase)
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
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
    private func phaseIndicator(phase: ActivityPhase) -> some View {
        switch phase {
        case .recording:
            Circle()
                .fill(Color.writRecordingRed)
                .frame(width: 10, height: 10)
        case .transcribing:
            Circle()
                .fill(.blue)
                .frame(width: 10, height: 10)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private func expandedCenter(context: ActivityViewContext<WritActivityAttributes>) -> some View {
        switch context.state.phase {
        case .recording:
            Text(context.state.recordingStartDate, style: .timer)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        case .transcribing:
            VStack(spacing: 4) {
                Text("전사 중...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                ProgressView(value: Double(context.state.transcriptionProgress))
                    .tint(.blue)
            }
        case .completed:
            Text("클립보드에 복사됨")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
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
        case .transcribing:
            ProgressView()
                .tint(.blue)
                .frame(width: 32, height: 32)
        case .completed:
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
                .frame(width: 32, height: 32)
        }
    }

    // MARK: - Compact

    @ViewBuilder
    private func compactLeadingContent(context: ActivityViewContext<WritActivityAttributes>) -> some View {
        switch context.state.phase {
        case .recording:
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.writRecordingRed)
                    .frame(width: 8, height: 8)
                Text(context.state.recordingStartDate, style: .timer)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
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
                Text("복사됨")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private func compactTrailingContent(context: ActivityViewContext<WritActivityAttributes>) -> some View {
        switch context.state.phase {
        case .recording:
            PowerWaveformView(
                barCount: 3,
                barWidth: 2,
                barSpacing: 1.5,
                frameHeight: 14,
                barColor: Color.writRecordingRed,
                power: CGFloat(context.state.averagePower)
            )
        case .transcribing:
            Text("\(Int(context.state.transcriptionProgress * 100))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.blue)
                .monospacedDigit()
        case .completed:
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 12))
                .foregroundStyle(.green)
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

// MARK: - Power-driven Waveform (음성 파워 반응)

private struct PowerWaveformView: View {
    let barCount: Int
    let barWidth: CGFloat
    let barSpacing: CGFloat
    let frameHeight: CGFloat
    let barColor: Color
    let power: CGFloat // 0~1

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                let centerDistance = abs(CGFloat(index) - CGFloat(barCount - 1) / 2) / (CGFloat(barCount) / 2)
                let baseHeight: CGFloat = 0.15
                let variation = (1.0 - centerDistance * 0.5) * max(baseHeight, power)
                let barHeight = max(3, variation * frameHeight)
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(barColor)
                    .frame(width: barWidth, height: barHeight)
            }
        }
        .frame(height: frameHeight)
        .animation(.easeInOut(duration: 0.15), value: power)
    }
}

// MARK: - Lock Screen View

private struct LockScreenLiveActivityView: View {
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
        case .completed: "클립보드에 복사됨"
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
            HStack(spacing: 12) {
                PowerWaveformView(
                    barCount: 7,
                    barWidth: 2,
                    barSpacing: 1.5,
                    frameHeight: 16,
                    barColor: .white.opacity(0.6),
                    power: CGFloat(context.state.averagePower)
                )

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
            }
        case .transcribing:
            ProgressView(value: Double(context.state.transcriptionProgress))
                .tint(.blue)
                .frame(width: 60)
        case .completed:
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
        }
    }
}

// MARK: - 홈 화면 위젯

struct WritRecordingWidget: Widget {
    let kind: String = "WritRecordingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WritWidgetProvider()) { entry in
            WritWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("녹음 시작")
        .description("탭하여 Writ 녹음을 바로 시작합니다.")
        .supportedFamilies([.systemSmall])
    }
}

struct WritWidgetEntry: TimelineEntry {
    let date: Date
    let modelName: String
}

struct WritWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WritWidgetEntry {
        WritWidgetEntry(date: Date(), modelName: "Small")
    }

    func getSnapshot(in context: Context, completion: @escaping (WritWidgetEntry) -> Void) {
        completion(WritWidgetEntry(date: Date(), modelName: currentModelName()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WritWidgetEntry>) -> Void) {
        let entry = WritWidgetEntry(date: Date(), modelName: currentModelName())
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }

    private func currentModelName() -> String {
        AppGroupConstants.sharedDefaults.string(forKey: "selectedModelDisplayName") ?? "준비 중"
    }
}

struct WritWidgetEntryView: View {
    let entry: WritWidgetEntry

    var body: some View {
        Link(destination: URL(string: "writ://start-recording")!) {
            VStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.red)

                Text("녹음 시작")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(entry.modelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Widget Bundle

@main
struct WritWidgetBundle: WidgetBundle {
    var body: some Widget {
        WritLiveActivity()
        WritRecordingWidget()
    }
}
