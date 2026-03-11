import SwiftUI

struct WaveformView: View {
    let power: Float
    let isRecording: Bool

    @State private var bars: [CGFloat] = Array(repeating: 0.1, count: 40)

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            HStack(spacing: WritDimension.waveformBarWidth) {
                ForEach(0..<bars.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: WritDimension.waveformBarRadius)
                        .fill(WritColor.accent)
                        .frame(width: WritDimension.waveformBarWidth, height: max(4, bars[index] * 120))
                        .opacity(isRecording ? 1.0 : 0.3)
                        .animation(
                            isRecording
                                ? .easeInOut(duration: 0.6 + Double(index % 5) * 0.04)
                                : .easeOut(duration: 0.3),
                            value: bars[index]
                        )
                }
            }
            .onChange(of: timeline.date) { _, _ in
                updateBars()
            }
        }
        .onChange(of: isRecording) { _, recording in
            if !recording {
                withAnimation(.easeOut(duration: 0.3)) {
                    bars = Array(repeating: 0.1, count: 40)
                }
            }
        }
    }

    private func updateBars() {
        guard isRecording else { return }
        bars.removeFirst()
        let normalized = CGFloat(max(0, (power + 50) / 50))
        bars.append(normalized)
    }
}
