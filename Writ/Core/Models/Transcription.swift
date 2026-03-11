import Foundation
import SwiftData

@Model
final class Transcription {
    var id: UUID
    var text: String
    var modelUsed: String
    var createdAt: Date
    var status: TranscriptionStatus

    @Relationship(deleteRule: .cascade)
    var segments: [WritSegment]

    @Relationship(inverse: \Recording.transcription)
    var recording: Recording?

    init(
        id: UUID = UUID(),
        text: String = "",
        modelUsed: String = "",
        createdAt: Date = Date(),
        status: TranscriptionStatus = .pending,
        segments: [WritSegment] = []
    ) {
        self.id = id
        self.text = text
        self.modelUsed = modelUsed
        self.createdAt = createdAt
        self.status = status
        self.segments = segments
    }
}

enum TranscriptionStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case failed
}
