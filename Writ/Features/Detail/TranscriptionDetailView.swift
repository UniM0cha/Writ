import SwiftUI
import AVFoundation

struct TranscriptionDetailView: View {
    let recording: Recording
    @State private var isPlaying = false
    @State private var currentPlaybackTime: TimeInterval = 0
    @State private var showExportSheet = false
    @State private var showRetranscribeSheet = false
    @State private var copiedFeedback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 오디오 플레이어
                AudioPlayerView(
                    audioURL: recording.audioURL,
                    duration: recording.duration,
                    isPlaying: $isPlaying,
                    currentTime: $currentPlaybackTime
                )
                .padding(.horizontal, WritSpacing.md)
                .padding(.top, WritSpacing.md)

                // 액션 바
                actionBar
                    .padding(.horizontal, WritSpacing.lg)
                    .padding(.vertical, WritSpacing.sm)

                // 구분선
                Rectangle()
                    .fill(WritColor.divider)
                    .frame(height: 0.5)

                // 전사문 세그먼트
                if let segments = recording.transcription?.segments {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(segments.sorted(by: { $0.orderIndex < $1.orderIndex })) { segment in
                            SegmentRowView(
                                segment: segment,
                                isHighlighted: isSegmentHighlighted(segment)
                            )

                            Rectangle()
                                .fill(WritColor.divider)
                                .frame(height: 0.5)
                                .padding(.leading, WritSpacing.lg)
                        }
                    }
                }
            }
        }
        .background(WritColor.background)
        .navigationTitle(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showRetranscribeSheet = true }) {
                        Label("다른 모델로 재전사", systemImage: "arrow.clockwise")
                    }
                    Button(action: copyText) {
                        Label("전체 복사", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {} label: {
                        Label("삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(recording: recording)
        }
        .sheet(isPresented: $showRetranscribeSheet) {
            RetranscribeSheet(recording: recording)
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: WritSpacing.md) {
            actionButton(icon: "doc.on.doc", label: "복사") {
                copyText()
            }
            actionButton(icon: "square.and.arrow.up", label: "공유") {
                showExportSheet = true
            }
            actionButton(icon: "arrow.down.doc", label: "내보내기") {
                showExportSheet = true
            }
            Spacer()
        }
        .overlay(alignment: .leading) {
            if copiedFeedback {
                Text("복사됨")
                    .font(WritFont.smallCaption)
                    .foregroundStyle(WritColor.success)
                    .transition(.opacity)
            }
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: WritSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(
                        width: WritDimension.actionIconSize,
                        height: WritDimension.actionIconSize
                    )
                    .background(WritColor.accentLight, in: RoundedRectangle(cornerRadius: WritRadius.button))
                Text(label)
                    .font(WritFont.smallCaption)
            }
            .foregroundStyle(WritColor.accent)
        }
    }

    // MARK: - Helpers

    private func isSegmentHighlighted(_ segment: WritSegment) -> Bool {
        currentPlaybackTime >= segment.startTime && currentPlaybackTime < segment.endTime
    }

    private func copyText() {
        guard let text = recording.transcription?.text else { return }
        ClipboardService.copy(text)
        withAnimation(WritAnimation.toast) {
            copiedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(WritAnimation.toast) {
                copiedFeedback = false
            }
        }
    }
}

// MARK: - Segment Row

struct SegmentRowView: View {
    let segment: WritSegment
    let isHighlighted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: WritSpacing.sm) {
            Text(formatTimestamp(segment.startTime))
                .font(WritFont.timestamp)
                .foregroundStyle(WritColor.accent)
                .frame(width: 50, alignment: .trailing)

            Text(segment.text)
                .font(WritFont.transcript)
                .lineSpacing(4)
                .foregroundStyle(WritColor.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, WritSpacing.sm)
        .padding(.horizontal, WritSpacing.lg)
        .background(isHighlighted ? WritColor.accent.opacity(0.06) : Color.clear)
        .overlay(alignment: .leading) {
            if isHighlighted {
                Rectangle()
                    .fill(WritColor.accent)
                    .frame(width: 3)
            }
        }
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
