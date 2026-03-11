import ActivityKit
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
                // Expanded — Apple 음성 메모 스타일
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 1, green: 0.231, blue: 0.188))
                            .frame(width: 8, height: 8)
                        Text("녹음 중")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.recordingStartDate, style: .timer)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: "writ://stop-recording")!) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 1, green: 0.231, blue: 0.188))
                                .frame(width: 32, height: 32)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PowerWaveformView(
                        barCount: 20,
                        barWidth: 3,
                        barSpacing: 2,
                        frameHeight: 24,
                        barColor: Color(red: 1, green: 0.231, blue: 0.188),
                        power: CGFloat(context.state.averagePower)
                    )
                }
            } compactLeading: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 1, green: 0.231, blue: 0.188))
                        .frame(width: 8, height: 8)
                    Text(context.state.recordingStartDate, style: .timer)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            } compactTrailing: {
                PowerWaveformView(
                    barCount: 5,
                    barWidth: 2,
                    barSpacing: 1.5,
                    frameHeight: 14,
                    barColor: Color(red: 1, green: 0.231, blue: 0.188),
                    power: CGFloat(context.state.averagePower)
                )
            } minimal: {
                Circle()
                    .fill(Color(red: 1, green: 0.231, blue: 0.188))
                    .frame(width: 8, height: 8)
            }
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
                Image(systemName: "mic.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("녹음 중")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(context.state.recordingStartDate, style: .timer)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }

            Spacer()

            // 파형
            PowerWaveformView(
                barCount: 7,
                barWidth: 2,
                barSpacing: 1.5,
                frameHeight: 16,
                barColor: .white.opacity(0.6),
                power: CGFloat(context.state.averagePower)
            )

            // 정지 버튼
            Link(destination: URL(string: "writ://stop-recording")!) {
                ZStack {
                    Circle()
                        .fill(Color(red: 1, green: 0.231, blue: 0.188))
                        .frame(width: 32, height: 32)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .activityBackgroundTint(.black.opacity(0.8))
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
        if let rawValue = UserDefaults.standard.string(forKey: "selectedModelVariant") {
            switch rawValue {
            case "openai_whisper-tiny": return "Tiny"
            case "openai_whisper-base": return "Base"
            case "openai_whisper-small": return "Small"
            case "openai_whisper-large-v3": return "Large v3"
            case "openai_whisper-large-v3_turbo": return "Large v3 Turbo"
            default: return rawValue
            }
        }
        return "준비 중"
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
