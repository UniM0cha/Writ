import Foundation

enum SRTExporter {
    /// 세그먼트 배열을 SRT 형식 문자열로 변환
    static func export(segments: [SegmentOutput]) -> String {
        segments.enumerated().map { index, segment in
            let start = formatTimestamp(segment.startTime)
            let end = formatTimestamp(segment.endTime)
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let line = if let speaker = segment.speaker {
                "[\(speaker)] \(text)"
            } else {
                text
            }
            return "\(index + 1)\n\(start) --> \(end)\n\(line)"
        }.joined(separator: "\n\n")
    }

    private static func formatTimestamp(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
}
