#if os(iOS)
import ActivityKit
import Foundation

/// Live Activity 단계
enum ActivityPhase: String, Sendable {
    case recording      // 녹음 중
    case transcribing   // 전사 중
    case completed      // 완료 (클립보드 복사됨)
}

extension ActivityPhase: Codable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ActivityPhase(rawValue: rawValue) ?? .recording
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension ActivityPhase: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

struct WritActivityAttributes: ActivityAttributes {
    public struct ContentState: Sendable {
        var phase: ActivityPhase
        var recordingDuration: Double
        var recordingStartDate: Date
        var averagePower: Float
        var transcriptionProgress: Float
    }
}

extension WritActivityAttributes.ContentState: Codable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.phase = try container.decode(ActivityPhase.self, forKey: .phase)
        self.recordingDuration = try container.decode(Double.self, forKey: .recordingDuration)
        self.recordingStartDate = try container.decode(Date.self, forKey: .recordingStartDate)
        self.averagePower = try container.decode(Float.self, forKey: .averagePower)
        self.transcriptionProgress = try container.decode(Float.self, forKey: .transcriptionProgress)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phase, forKey: .phase)
        try container.encode(recordingDuration, forKey: .recordingDuration)
        try container.encode(recordingStartDate, forKey: .recordingStartDate)
        try container.encode(averagePower, forKey: .averagePower)
        try container.encode(transcriptionProgress, forKey: .transcriptionProgress)
    }

    private enum CodingKeys: String, CodingKey {
        case phase, recordingDuration, recordingStartDate, averagePower, transcriptionProgress
    }
}

extension WritActivityAttributes.ContentState: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(phase)
        hasher.combine(recordingDuration)
        hasher.combine(recordingStartDate)
        hasher.combine(averagePower)
        hasher.combine(transcriptionProgress)
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.phase == rhs.phase
            && lhs.recordingDuration == rhs.recordingDuration
            && lhs.recordingStartDate == rhs.recordingStartDate
            && lhs.averagePower == rhs.averagePower
            && lhs.transcriptionProgress == rhs.transcriptionProgress
    }
}

// MARK: - Factory Methods

extension WritActivityAttributes.ContentState {
    static func recording(duration: Double, startDate: Date, power: Float) -> Self {
        .init(phase: .recording, recordingDuration: duration, recordingStartDate: startDate, averagePower: power, transcriptionProgress: 0)
    }

    static func transcribing(progress: Float = 0) -> Self {
        .init(phase: .transcribing, recordingDuration: 0, recordingStartDate: Date(), averagePower: 0, transcriptionProgress: progress)
    }

    static func completed() -> Self {
        .init(phase: .completed, recordingDuration: 0, recordingStartDate: Date(), averagePower: 0, transcriptionProgress: 1)
    }
}
#endif
