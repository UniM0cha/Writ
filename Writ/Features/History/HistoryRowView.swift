import SwiftUI

struct HistoryRowView: View {
    let recording: Recording

    var body: some View {
        HStack(spacing: WritSpacing.sm) {
            VStack(alignment: .leading, spacing: WritSpacing.xxs) {
                // 제목 행
                HStack {
                    Text(recording.createdAt, style: .time)
                        .font(WritFont.body)
                        .foregroundStyle(WritColor.primaryText)

                    Spacer()

                    statusBadge
                }

                // 프리뷰 텍스트
                if let text = recording.transcription?.text, !text.isEmpty {
                    Text(text)
                        .font(WritFont.callout)
                        .lineLimit(1)
                        .foregroundStyle(WritColor.secondaryText)
                }

                // 메타 정보
                HStack(spacing: WritSpacing.xxs) {
                    Text(formatDuration(recording.duration))
                        .font(WritFont.caption)
                        .foregroundStyle(WritColor.secondaryText)

                    if let model = recording.transcription?.modelUsed {
                        Text("·")
                            .foregroundStyle(WritColor.secondaryText)
                        Text(model)
                            .font(WritFont.caption)
                            .foregroundStyle(WritColor.secondaryText)
                    }
                }

                // 진행 바 (전사 진행 중)
                if recording.transcription?.status == .inProgress {
                    let progress = recording.transcription?.progress ?? 0
                    if progress > 0 {
                        HStack(spacing: WritSpacing.xxs) {
                            ProgressView(value: progress)
                                .tint(WritColor.warning)
                            Text("\(Int(progress * 100))%")
                                .font(WritFont.smallCaption)
                                .foregroundStyle(WritColor.secondaryText)
                                .monospacedDigit()
                        }
                    } else {
                        ProgressView()
                            .tint(WritColor.warning)
                    }
                }
            }
        }
        .padding(.vertical, WritSpacing.xxs)
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        switch recording.transcription?.status {
        case .completed:
            badge("완료", textColor: WritColor.statusCompleteText, bgColor: WritColor.statusCompleteBackground)
        case .inProgress:
            badge("전사 중", textColor: WritColor.statusProcessingText, bgColor: WritColor.statusProcessingBackground)
        case .pending:
            badge("대기", textColor: WritColor.statusWaitingText, bgColor: WritColor.statusWaitingBackground)
        case .failed:
            badge("실패", textColor: WritColor.recordingRed, bgColor: WritColor.recordingRed.opacity(0.12))
        case nil:
            EmptyView()
        }
    }

    private func badge(_ text: String, textColor: Color, bgColor: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, WritSpacing.xs)
            .padding(.vertical, WritSpacing.xxxs)
            .background(bgColor, in: RoundedRectangle(cornerRadius: 4))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
