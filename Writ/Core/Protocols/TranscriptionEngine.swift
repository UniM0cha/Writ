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
    let speaker: String?

    init(text: String, startTime: TimeInterval, endTime: TimeInterval, speaker: String? = nil) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.speaker = speaker
    }
}

/// 전사 엔진 추상화. WhisperKit, Qwen3-ASR 등 다양한 엔진 지원.
protocol TranscriptionEngine: Sendable {
    func transcribe(
        audioURL: URL,
        language: String?,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws -> TranscriptionOutput

    func supportedModels() -> [ModelIdentifier]

    func loadModel(
        _ model: ModelIdentifier,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws

    func unloadModel() async

    var currentModel: ModelIdentifier? { get }
}
