import Foundation

enum TXTExporter {
    /// 전사 텍스트를 타임스탬프 포함 TXT로 변환
    static func export(segments: [SegmentOutput], includeTimestamps: Bool = false) -> String {
        if includeTimestamps {
            return segments.map { segment in
                let time = formatTimestamp(segment.startTime)
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if let speaker = segment.speaker {
                    return "[\(time)] [\(speaker)] \(text)"
                } else {
                    return "[\(time)] \(text)"
                }
            }.joined(separator: "\n")
        } else {
            return segments.map {
                $0.text.trimmingCharacters(in: .whitespacesAndNewlines)
            }.joined(separator: " ")
        }
    }

    private static func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
