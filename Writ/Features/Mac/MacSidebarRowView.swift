import SwiftUI

#if os(macOS)
struct MacSidebarRowView: View {
    let recording: Recording

    var body: some View {
        HStack(alignment: .top, spacing: WritSpacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: WritSpacing.xxxs) {
                Text(titleText)
                    .font(WritFont.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(WritColor.primaryText)
                    .lineLimit(1)

                HStack(spacing: WritSpacing.xs) {
                    Text(formatDuration(recording.duration))
                        .font(WritFont.smallCaption)
                        .foregroundStyle(WritColor.secondaryText)

                    Text(statusText)
                        .font(WritFont.smallCaption)
                        .foregroundStyle(WritColor.secondaryText)
                }
            }
        }
    }

    private var titleText: String {
        if let text = recording.transcription?.text, !text.isEmpty {
            return String(text.prefix(50))
        }
        return recording.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var statusColor: Color {
        switch recording.transcription?.status {
        case .completed: WritColor.success
        case .inProgress: WritColor.warning
        case .pending, .failed, nil: WritColor.secondaryText
        }
    }

    private var statusText: String {
        switch recording.transcription?.status {
        case .completed:
            return "완료"
        case .inProgress:
            let progress = recording.transcription?.progress ?? 0
            return progress > 0 ? "전사 중 \(Int(progress * 100))%" : "전사 중"
        case .pending:
            return "대기"
        case .failed:
            return "실패"
        case nil:
            return ""
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
#endif
