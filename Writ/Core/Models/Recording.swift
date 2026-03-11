import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID
    var createdAt: Date
    var duration: TimeInterval
    var audioFileName: String
    var languageCode: String?
    var sourceDevice: SourceDevice

    @Relationship(deleteRule: .cascade)
    var transcription: Transcription?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        audioFileName: String,
        languageCode: String? = nil,
        sourceDevice: SourceDevice = .iPhone
    ) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.audioFileName = audioFileName
        self.languageCode = languageCode
        self.sourceDevice = sourceDevice
    }

    /// 오디오 파일 URL
    var audioURL: URL {
        AppGroupConstants.recordingsDirectory.appendingPathComponent(audioFileName)
    }
}

enum SourceDevice: String, Codable, Sendable {
    case iPhone
    case iPad
    case mac
    case watch
    case keyboard
}
