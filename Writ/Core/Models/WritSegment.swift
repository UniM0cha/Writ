import Foundation
import SwiftData

@Model
final class WritSegment {
    var id: UUID = UUID()
    var text: String = ""
    var startTime: TimeInterval = 0
    var endTime: TimeInterval = 0
    var orderIndex: Int = 0

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
