import SwiftUI

struct HistoryRowView: View {
    let recording: Recording

    var body: some View {
        HStack(spacing: WritSpacing.sm) {
            // 상태 아이콘
            statusIcon

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
                    ProgressView(value: 0.5)
                        .tint(WritColor.warning)
                        .frame(height: WritDimension.progressBarHeight)
                }
            }
        }
        .padding(.vertical, WritSpacing.xxs)
    }

    // MARK: - Status Icon

    private var statusIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WritRadius.button)
                .fill(statusIconBackground)
                .frame(
                    width: WritDimension.statusIconSize,
                    height: WritDimension.statusIconSize
                )

            statusIconImage
        }
    }

    private var statusIconBackground: Color {
        switch recording.transcription?.status {
        case .completed: WritColor.statusCompleteBackground
        case .inProgress: WritColor.statusProcessingBackground
        case .pending: WritColor.statusWaitingBackground
        case .failed: WritColor.recordingRed.opacity(0.12)
        case nil: WritColor.statusWaitingBackground
        }
    }

    @ViewBuilder
    private var statusIconImage: some View {
        switch recording.transcription?.status {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WritColor.success)
        case .inProgress:
            ProgressView()
                .controlSize(.small)
                .tint(WritColor.warning)
        case .pending:
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundStyle(WritColor.secondaryText)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16))
                .foregroundStyle(WritColor.recordingRed)
        case nil:
            Image(systemName: "waveform")
                .font(.system(size: 16))
                .foregroundStyle(WritColor.secondaryText)
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        switch recording.transcription?.status {
        case .completed:
            Text("완료")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WritColor.statusCompleteText)
                .padding(.horizontal, WritSpacing.xs)
                .padding(.vertical, WritSpacing.xxxs)
                .background(WritColor.statusCompleteBackground, in: RoundedRectangle(cornerRadius: 4))

        case .inProgress:
            Text("전사 중")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WritColor.statusProcessingText)
                .padding(.horizontal, WritSpacing.xs)
                .padding(.vertical, WritSpacing.xxxs)
                .background(WritColor.statusProcessingBackground, in: RoundedRectangle(cornerRadius: 4))

        case .pending:
            Text("대기")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WritColor.statusWaitingText)
                .padding(.horizontal, WritSpacing.xs)
                .padding(.vertical, WritSpacing.xxxs)
                .background(WritColor.statusWaitingBackground, in: RoundedRectangle(cornerRadius: 4))

        case .failed:
            Text("실패")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WritColor.recordingRed)
                .padding(.horizontal, WritSpacing.xs)
                .padding(.vertical, WritSpacing.xxxs)
                .background(WritColor.recordingRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))

        case nil:
            EmptyView()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
