import Foundation

/// 전사 결과
struct TranscriptionOutput: Sendable {
    let text: String
    let segments: [SegmentOutput]
    let language: String?

    init(text: String, segments: [SegmentOutput], language: String?) {
        self.text = text
        self.segments = segments
        self.language = language
    }
}

struct SegmentOutput: Sendable {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval

    init(text: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}

/// 전사 엔진 추상화. v1: WhisperKit, 향후 다른 엔진으로 교체 가능.
protocol TranscriptionEngine: Sendable {
    func transcribe(
        audioURL: URL,
        language: String?,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws -> TranscriptionOutput

    func supportedModels() -> [WhisperModelVariant]

    func loadModel(
        _ model: WhisperModelVariant,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws

    func unloadModel() async

    var currentModel: WhisperModelVariant? { get }
}
