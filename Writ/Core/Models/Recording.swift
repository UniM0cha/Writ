import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var duration: TimeInterval = 0
    var audioFileName: String = ""
    var languageCode: String?
    var sourceDevice: SourceDevice = SourceDevice.iPhone

    /// 오디오 파일 데이터 (CloudKit 동기화용, SwiftData가 외부 파일로 자동 관리)
    @Attribute(.externalStorage) var audioData: Data?

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

enum SourceDevice: String, Sendable {
    case iPhone
    case iPad
    case mac
    case watch
}

extension SourceDevice: Codable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        // "keyboard" → .iPhone 폴백 (키보드 확장 제거 후 마이그레이션)
        self = SourceDevice(rawValue: rawValue) ?? .iPhone
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
