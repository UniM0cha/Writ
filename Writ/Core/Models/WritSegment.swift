import Foundation
import SwiftData

@Model
final class WritSegment {
    var id: UUID
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var orderIndex: Int

    @Relationship(inverse: \Transcription.segments)
    var transcription: Transcription?

    init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.orderIndex = orderIndex
    }
}
