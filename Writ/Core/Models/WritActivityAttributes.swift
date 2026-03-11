#if os(iOS)
import ActivityKit
import Foundation

struct WritActivityAttributes: ActivityAttributes {
    public struct ContentState: Sendable {
        var recordingDuration: Double
        var recordingStartDate: Date
        var isTranscribing: Bool
        var averagePower: Float
    }
}

extension WritActivityAttributes.ContentState: Codable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.recordingDuration = try container.decode(Double.self, forKey: .recordingDuration)
        self.recordingStartDate = try container.decode(Date.self, forKey: .recordingStartDate)
        self.isTranscribing = try container.decode(Bool.self, forKey: .isTranscribing)
        self.averagePower = try container.decode(Float.self, forKey: .averagePower)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recordingDuration, forKey: .recordingDuration)
        try container.encode(recordingStartDate, forKey: .recordingStartDate)
        try container.encode(isTranscribing, forKey: .isTranscribing)
        try container.encode(averagePower, forKey: .averagePower)
    }

    private enum CodingKeys: String, CodingKey {
        case recordingDuration, recordingStartDate, isTranscribing, averagePower
    }
}

extension WritActivityAttributes.ContentState: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(recordingDuration)
        hasher.combine(recordingStartDate)
        hasher.combine(isTranscribing)
        hasher.combine(averagePower)
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.recordingDuration == rhs.recordingDuration && lhs.recordingStartDate == rhs.recordingStartDate && lhs.isTranscribing == rhs.isTranscribing && lhs.averagePower == rhs.averagePower
    }
}
#endif
