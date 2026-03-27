import Foundation
import SwiftData

@Model
final class WritSegment {
    var id: UUID = UUID()
    var text: String = ""
    var startTime: TimeInterval = 0
    var endTime: TimeInterval = 0
    var orderIndex: Int = 0
    /// 발화자 ("화자 1", "화자 2" 등). nil이면 미구분.
    var speaker: String?

    @Relationship(inverse: \Transcription.segments)
    var transcription: Transcription?

    init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        orderIndex: Int = 0,
        speaker: String? = nil
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.orderIndex = orderIndex
        self.speaker = speaker
    }
}
