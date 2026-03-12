import Foundation
import SwiftData

@Model
final class Transcription {
    var id: UUID = UUID()
    var text: String = ""
    var modelUsed: String = ""
    var createdAt: Date = Date()
    var status: TranscriptionStatus = TranscriptionStatus.pending
    var progress: Float = 0

    @Relationship(deleteRule: .cascade)
    var segments: [WritSegment]?

    @Relationship(inverse: \Recording.transcription)
    var recording: Recording?

    init(
        id: UUID = UUID(),
        text: String = "",
        modelUsed: String = "",
        createdAt: Date = Date(),
        status: TranscriptionStatus = .pending,
        segments: [WritSegment]? = nil
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
