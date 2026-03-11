import SwiftUI

struct WatchRecordingListView: View {
    @StateObject private var sessionManager = WatchSessionManager.shared

    var body: some View {
        List {
            if sessionManager.recordings.isEmpty {
                Text("녹음 기록이 없습니다")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
            } else {
                ForEach(sessionManager.recordings) { recording in
                    recordingRow(recording)
                }
            }
        }
        .navigationTitle("기록")
    }

    private func recordingRow(_ recording: WatchRecording) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatDate(recording.date))
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                statusIcon(recording.status)
            }

            HStack(spacing: 8) {
                Text(formatDuration(recording.duration))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                statusText(recording.status)
                    .font(.system(size: 11))
            }

            // 전사 결과 텍스트 (있으면)
            if case .completed(let text) = recording.status {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Status

    private func statusIcon(_ status: WatchRecording.TransferStatus) -> some View {
        Group {
            switch status {
            case .transferring:
                Image(systemName: "arrow.up.circle")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14))
            case .sent:
                Image(systemName: "clock")
                    .foregroundStyle(.blue)
                    .font(.system(size: 14))
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
            case .failed:
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.red)
                    .font(.system(size: 14))
            }
        }
    }

    private func statusText(_ status: WatchRecording.TransferStatus) -> some View {
        Group {
            switch status {
            case .transferring:
                Text("전송 중...")
                    .foregroundStyle(.orange)
            case .sent:
                Text("전사 대기")
                    .foregroundStyle(.blue)
            case .completed:
                Text("완료")
                    .foregroundStyle(.green)
            case .failed:
                Text("실패")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Formatting

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
