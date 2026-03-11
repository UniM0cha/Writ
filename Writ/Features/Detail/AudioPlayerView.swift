import SwiftUI
import AVFoundation

struct AudioPlayerView: View {
    let audioURL: URL
    let duration: TimeInterval
    @Binding var isPlaying: Bool
    @Binding var currentTime: TimeInterval

    @State private var player: AVAudioPlayer?
    @State private var playbackSpeed: Float = 1.0

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(spacing: WritSpacing.sm) {
            // 파형 시크바
            waveformSeekBar

            // 시간 표시
            HStack {
                Text(formatTime(currentTime))
                    .font(WritFont.timestamp)
                    .foregroundStyle(WritColor.secondaryText)
                Spacer()
                Text("-\(formatTime(max(0, duration - currentTime)))")
                    .font(WritFont.timestamp)
                    .foregroundStyle(WritColor.secondaryText)
            }

            // 재생 컨트롤
            HStack(spacing: WritSpacing.lg) {
                // 속도 버튼
                Button {
                    cycleSpeed()
                } label: {
                    Text(speedLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WritColor.accent)
                        .padding(.horizontal, WritSpacing.xs)
                        .padding(.vertical, WritSpacing.xxs)
                        .background(WritColor.accentLight, in: RoundedRectangle(cornerRadius: WritRadius.small))
                }

                Spacer()

                // 15초 뒤로
                Button(action: skip(-15)) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 20))
                        .foregroundStyle(WritColor.primaryText.opacity(0.6))
                }

                // 재생/일시정지
                Button(action: togglePlayback) {
                    ZStack {
                        Circle()
                            .fill(WritColor.accent)
                            .frame(
                                width: WritDimension.playButtonSize,
                                height: WritDimension.playButtonSize
                            )
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }

                // 15초 앞으로
                Button(action: skip(15)) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 20))
                        .foregroundStyle(WritColor.primaryText.opacity(0.6))
                }

                Spacer()

                // 속도 플레이스홀더 (좌우 대칭)
                Color.clear
                    .frame(width: 44, height: 1)
            }
        }
        .padding(WritSpacing.md)
        .background(WritColor.cardBackground, in: RoundedRectangle(cornerRadius: WritRadius.card))
    }

    // MARK: - Waveform Seek Bar

    private var waveformSeekBar: some View {
        GeometryReader { geometry in
            let barCount = Int(geometry.size.width / (WritDimension.waveformBarWidth + 1.5))
            let playedBars = duration > 0 ? Int(CGFloat(barCount) * CGFloat(currentTime / duration)) : 0

            HStack(spacing: 1.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index < playedBars ? WritColor.waveformPlayed : WritColor.waveformUnplayed)
                        .frame(width: WritDimension.waveformBarWidth)
                        .frame(height: waveformBarHeight(index: index, total: barCount))
                }
            }
            .frame(maxHeight: .infinity)
            .overlay(alignment: .leading) {
                // 현재 위치 마커
                if duration > 0 {
                    let markerX = geometry.size.width * CGFloat(currentTime / duration)
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(WritColor.accent)
                            .frame(width: WritDimension.seekMarkerWidth)
                        Circle()
                            .fill(WritColor.accent)
                            .frame(
                                width: WritDimension.seekMarkerDotSize,
                                height: WritDimension.seekMarkerDotSize
                            )
                    }
                    .offset(x: markerX - 1)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = value.location.x / geometry.size.width
                        let time = TimeInterval(max(0, min(fraction, 1))) * duration
                        seek(to: time)
                    }
            )
        }
        .frame(height: WritDimension.waveformSeekHeight)
    }

    private func waveformBarHeight(index: Int, total: Int) -> CGFloat {
        // 파형 모양 시뮬레이션 (실제 오디오 데이터 없이)
        let normalized = Double(index) / Double(max(total, 1))
        let height = sin(normalized * .pi * 4) * 0.3 + 0.5
            + sin(normalized * .pi * 7) * 0.15
            + sin(normalized * .pi * 13) * 0.05
        return CGFloat(max(0.15, min(height, 1.0))) * WritDimension.waveformSeekHeight
    }

    // MARK: - Speed

    private var speedLabel: String {
        if playbackSpeed == 1.0 { return "1x" }
        if playbackSpeed.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(playbackSpeed))x"
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

    // MARK: - Playback

    private func togglePlayback() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            if player == nil {
                player = try? AVAudioPlayer(contentsOf: audioURL)
                player?.enableRate = true
                player?.rate = playbackSpeed
            }
            player?.play()
            isPlaying = true
            startTimer()
        }
    }

    private func skip(_ seconds: TimeInterval) -> () -> Void {
        return {
            let newTime = max(0, min(currentTime + seconds, duration))
            seek(to: newTime)
        }
    }

    private func seek(to time: TimeInterval) {
        currentTime = time
        player?.currentTime = time
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            guard let player, player.isPlaying else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                currentTime = player.currentTime
                if player.currentTime >= duration {
                    isPlaying = false
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
