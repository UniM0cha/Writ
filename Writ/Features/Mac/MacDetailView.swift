import SwiftUI
import AVFoundation

#if os(macOS)
struct MacDetailView: View {
    let recording: Recording
    var onDelete: (() -> Void)?
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var isPlaying = false
    @State private var currentPlaybackTime: TimeInterval = 0
    @State private var player: AVAudioPlayer?
    @State private var playbackTimer: Timer?
    @State private var playbackSpeed: Float = 1.0
    @State private var showRetranscribeSheet = false
    @State private var showDeleteConfirm = false
    @State private var copiedFeedback = false

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            header

            // 오디오 플레이어 바
            audioPlayerBar

            // 액션 바
            actionBar

            // 전사 세그먼트
            transcriptView
        }
        .background(WritColor.cardBackground)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button(action: { showRetranscribeSheet = true }) {
                        Label("다른 모델로 재전사", systemImage: "arrow.clockwise")
                    }
                    Button(action: copyFullText) {
                        Label("전체 복사", systemImage: "doc.on.doc")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showRetranscribeSheet) {
            RetranscribeSheet(recording: recording)
        }
        .confirmationDialog(
            "이 녹음을 삭제하시겠습니까?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                deleteRecording()
            }
        } message: {
            Text("오디오 파일과 전사문이 모두 삭제됩니다.")
        }
        .onDisappear {
            playbackTimer?.invalidate()
            playbackTimer = nil
            player?.stop()
            player = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: WritSpacing.xxs) {
            Text(headerTitle)
                .font(WritFont.title)
                .foregroundStyle(WritColor.primaryText)
                .lineLimit(2)

            HStack(spacing: WritSpacing.xs) {
                Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                Text("·")
                Text(formatDuration(recording.duration))
                Text("·")
                Text(recording.transcription?.modelUsed ?? "")
            }
            .font(WritFont.caption)
            .foregroundStyle(WritColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WritSpacing.xl)
        .padding(.top, WritSpacing.lg)
        .padding(.bottom, WritSpacing.md)
    }

    private var headerTitle: String {
        if let text = recording.transcription?.text, !text.isEmpty {
            return String(text.prefix(60))
        }
        return recording.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: - Audio Player Bar

    private var audioPlayerBar: some View {
        HStack(spacing: WritSpacing.sm) {
            // 재생 버튼
            Button(action: togglePlayback) {
                ZStack {
                    Circle()
                        .fill(WritColor.accent)
                        .frame(width: 32, height: 32)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .offset(x: isPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)

            // 현재 시간
            Text(formatTime(currentPlaybackTime))
                .font(WritFont.timestamp)
                .foregroundStyle(WritColor.secondaryText)
                .frame(width: 40, alignment: .trailing)

            // 시크바
            GeometryReader { geometry in
                let progress = recording.duration > 0
                    ? CGFloat(currentPlaybackTime / recording.duration)
                    : 0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WritColor.waveformUnplayed)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(WritColor.accent)
                        .frame(width: geometry.size.width * progress, height: 4)

                    Circle()
                        .fill(WritColor.accent)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                        .offset(x: geometry.size.width * progress - 5)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = max(0, min(value.location.x / geometry.size.width, 1))
                            let time = TimeInterval(fraction) * recording.duration
                            seek(to: time)
                        }
                )
            }
            .frame(height: 20)

            // 전체 시간
            Text(formatTime(recording.duration))
                .font(WritFont.timestamp)
                .foregroundStyle(WritColor.secondaryText)
                .frame(width: 40, alignment: .leading)

            // 속도 버튼
            Button(action: cycleSpeed) {
                Text(speedLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WritColor.accent)
                    .padding(.horizontal, WritSpacing.xs)
                    .padding(.vertical, WritSpacing.xxxs)
                    .background(WritColor.accentLight, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WritSpacing.xl)
        .padding(.vertical, WritSpacing.sm)
        .background(WritColor.background)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: WritSpacing.xs) {
            macActionButton(icon: "doc.on.doc", label: "복사") { copyFullText() }
            macActionButton(icon: "square.and.arrow.up", label: "공유") { shareText() }
            macActionButton(icon: "doc.text", label: "TXT") { exportTXT() }
            macActionButton(icon: "captions.bubble", label: "SRT") { exportSRT() }
            Spacer()

            if copiedFeedback {
                Text("복사됨")
                    .font(WritFont.smallCaption)
                    .foregroundStyle(WritColor.success)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, WritSpacing.xl)
        .padding(.vertical, WritSpacing.xs)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WritColor.divider)
                .frame(height: 0.5)
        }
    }

    private func macActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: WritSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(WritFont.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(WritColor.accent)
            .padding(.horizontal, WritSpacing.sm)
            .padding(.vertical, WritSpacing.xxs)
            .contentShape(RoundedRectangle(cornerRadius: WritRadius.small))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transcript

    private var transcriptView: some View {
        ScrollView {
            if let segments = recording.transcription?.segments,
               !segments.isEmpty {
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
            } else if recording.transcription?.status == .inProgress {
                VStack(spacing: WritSpacing.sm) {
                    ProgressView()
                    Text("전사 중...")
                        .font(WritFont.caption)
                        .foregroundStyle(WritColor.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 80)
            } else if recording.transcription?.status == .pending {
                Text("전사 대기 중")
                    .font(WritFont.caption)
                    .foregroundStyle(WritColor.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                Text("전사문이 없습니다")
                    .font(WritFont.caption)
                    .foregroundStyle(WritColor.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            }
        }
    }

    // MARK: - Playback

    private func togglePlayback() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            if player == nil {
                player = try? AVAudioPlayer(contentsOf: recording.audioURL)
                player?.enableRate = true
                player?.rate = playbackSpeed
            }
            player?.play()
            isPlaying = true
            startTimer()
        }
    }

    private func seek(to time: TimeInterval) {
        currentPlaybackTime = time
        player?.currentTime = time
    }

    private func startTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            guard let player, player.isPlaying else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                currentPlaybackTime = player.currentTime
                if player.currentTime >= recording.duration {
                    isPlaying = false
                }
            }
        }
    }

    private var speedLabel: String {
        if playbackSpeed == 1.0 { return "1.0x" }
        if playbackSpeed.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(playbackSpeed)).0x"
        }
        return String(format: "%.1fx", playbackSpeed)
    }

    private func cycleSpeed() {
        guard let currentIndex = speeds.firstIndex(of: playbackSpeed) else {
            playbackSpeed = 1.0
            return
        }
        let nextIndex = (currentIndex + 1) % speeds.count
        playbackSpeed = speeds[nextIndex]
        player?.rate = playbackSpeed
    }

    private func isSegmentHighlighted(_ segment: WritSegment) -> Bool {
        currentPlaybackTime >= segment.startTime && currentPlaybackTime < segment.endTime
    }

    // MARK: - Actions

    private func copyFullText() {
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

    private func shareText() {
        guard let text = recording.transcription?.text else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("transcription.txt")
        try? text.write(to: tempURL, atomically: true, encoding: .utf8)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "transcription.txt"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.copyItem(at: tempURL, to: url)
            }
        }
    }

    private func exportTXT() {
        guard let segments = recording.transcription?.segments else { return }
        let segmentOutputs = segments.sorted(by: { $0.orderIndex < $1.orderIndex }).map {
            SegmentOutput(text: $0.text, startTime: $0.startTime, endTime: $0.endTime, speaker: $0.speaker)
        }
        let text = TXTExporter.export(segments: segmentOutputs, includeTimestamps: true)
        saveWithPanel(text, fileName: "transcription.txt")
    }

    private func exportSRT() {
        guard let segments = recording.transcription?.segments else { return }
        let segmentOutputs = segments.sorted(by: { $0.orderIndex < $1.orderIndex }).map {
            SegmentOutput(text: $0.text, startTime: $0.startTime, endTime: $0.endTime, speaker: $0.speaker)
        }
        let text = SRTExporter.export(segments: segmentOutputs)
        saveWithPanel(text, fileName: "transcription.srt")
    }

    private func saveWithPanel(_ content: String, fileName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func deleteRecording() {
        try? FileManager.default.removeItem(at: recording.audioURL)
        modelContext.delete(recording)
        try? modelContext.save()
        onDelete?()
    }

    // MARK: - Formatting

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d시간 %d분", hours, minutes)
        }
        return String(format: "%d분 %d초", minutes, seconds)
    }
}
#endif
