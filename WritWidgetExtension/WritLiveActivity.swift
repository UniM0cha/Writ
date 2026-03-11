import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Attributes

struct WritActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var recordingDuration: TimeInterval
        var isTranscribing: Bool
    }
}

// MARK: - Live Activity Widget

struct WritLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WritActivityAttributes.self) { context in
            // 잠금 화면 Live Activity
            lockScreenView(context: context)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Writ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(formatTime(context.state.recordingDuration))
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // 정지 버튼: 36x36, red, 10px radius, 내부 14x14 흰색 사각형
                    Link(destination: URL(string: "writ://stop-recording")!) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 1, green: 0.231, blue: 0.188)) // #ff3b30
                                .frame(width: 36, height: 36)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white)
                                .frame(width: 14, height: 14)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // 파형: 14바, 3px 너비, red
                    HStack(spacing: 2) {
                        ForEach(0..<14, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(red: 1, green: 0.231, blue: 0.188))
                                .frame(width: 3, height: waveformBarHeight(index: index))
                        }
                    }
                    .frame(height: 40)
                }
            } compactLeading: {
                // Compact Leading: 8px 빨간 점 (펄스)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 1, green: 0.231, blue: 0.188))
                        .frame(width: 8, height: 8)
                    Text(formatTime(context.state.recordingDuration))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            } compactTrailing: {
                // Compact Trailing: 미니 파형 7바
                HStack(spacing: 1.5) {
                    ForEach(0..<7, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(red: 1, green: 0.231, blue: 0.188))
                            .frame(width: 2, height: miniWaveformBarHeight(index: index))
                    }
                }
                .frame(height: 16)
            } minimal: {
                ZStack {
                    Circle()
                        .fill(Color(red: 1, green: 0.231, blue: 0.188))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }

    // MARK: - Lock Screen View

    private func lockScreenView(context: ActivityViewContext<WritActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            // 앱 아이콘: 36x36, gradient, 8px radius
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0, green: 0.478, blue: 1), // #007aff
                                Color(red: 0.345, green: 0.337, blue: 0.839) // #5856d6
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
                Text(context.state.isTranscribing ? "전사 중..." : "녹음 중")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(formatTime(context.state.recordingDuration))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }

            Spacer()

            // 미니 파형
            HStack(spacing: 1.5) {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white.opacity(0.6))
                        .frame(width: 2, height: miniWaveformBarHeight(index: index))
                }
            }
            .frame(height: 16)

            // 정지 버튼: 32x32, red circle, 10x10 흰색 사각형
            if !context.state.isTranscribing {
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
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .activityBackgroundTint(.black.opacity(0.8))
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func waveformBarHeight(index: Int) -> CGFloat {
        // 시뮬레이션된 파형 높이 (4~40 범위)
        let heights: [CGFloat] = [12, 24, 16, 32, 20, 36, 14, 28, 18, 34, 22, 10, 30, 16]
        return heights[index % heights.count]
    }

    private func miniWaveformBarHeight(index: Int) -> CGFloat {
        // 미니 파형 높이 (3~14 범위)
        let heights: [CGFloat] = [6, 10, 8, 14, 12, 7, 9]
        return heights[index % heights.count]
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
