#if os(iOS)
import Foundation
import os
import Qwen3ASR
import AudioCommon

private let logger = Logger(subsystem: AppGroupConstants.logSubsystem, category: "Qwen3ASR")

/// ForcedAligner가 지원하는 언어 목록 (타임스탬프 생성 가능)
private let forcedAlignerSupportedLanguages: Set<String> = [
    "korean", "english", "chinese", "japanese", "french",
    "german", "italian", "portuguese", "russian", "spanish", "cantonese",
    "ko", "en", "zh", "ja", "fr", "de", "it", "pt", "ru", "es"
]

/// Qwen3-ASR 기반 전사 엔진 구현체
final class Qwen3ASREngine: TranscriptionEngine, @unchecked Sendable {
    private var model: Qwen3ASRModel?
    private var aligner: Qwen3ForcedAligner?
    private var _currentModel: ModelIdentifier?
    private let lock = NSLock()

    var currentModel: ModelIdentifier? {
        lock.withLock { _currentModel }
    }

    init() {}

    func loadModel(
        _ model: ModelIdentifier,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws {
        logger.debug("loadModel: \(model.variantKey)")

        let asrModel = try await Qwen3ASRModel.fromPretrained(
            modelId: model.variantKey,
            progressHandler: { progress, status in
                logger.debug("loadModel progress: \(progress) - \(status)")
                progressCallback?(Float(progress))
            }
        )

        // ForcedAligner도 함께 로드 (타임스탬프 생성용)
        let forcedAligner = try await Qwen3ForcedAligner.fromPretrained(
            modelId: ForcedAlignerVariant.mlx4bit.rawValue,
            progressHandler: { progress, status in
                logger.debug("aligner progress: \(progress) - \(status)")
            }
        )

        lock.withLock {
            self.model = asrModel
            self.aligner = forcedAligner
            self._currentModel = model
        }
    }

    func unloadModel() async {
        let modelToUnload = lock.withLock { () -> Qwen3ASRModel? in
            let m = self.model
            self.model = nil
            self.aligner = nil
            self._currentModel = nil
            return m
        }
        modelToUnload?.unload()
    }

    func transcribe(
        audioURL: URL,
        language: String?,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws -> TranscriptionOutput {
        logger.debug("transcribe: audioURL = \(audioURL.path)")

        guard let asrModel = lock.withLock({ self.model }) else {
            throw Qwen3ASREngineError.modelNotLoaded
        }

        // 1. 오디오 파일 → Float 배열
        let samples = try AudioSampleLoader.load(url: audioURL)
        progressCallback?(0.2)

        // 2. 전사 (텍스트만 반환)
        let text = asrModel.transcribe(
            audio: samples,
            sampleRate: 16000,
            language: language,
            maxTokens: 448
        )
        progressCallback?(0.7)

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return TranscriptionOutput(text: "", segments: [], language: language)
        }

        // 3. ForcedAligner로 타임스탬프 생성 (지원 언어인 경우)
        var segments: [SegmentOutput] = []
        let currentAligner = lock.withLock { self.aligner }

        if let aligner = currentAligner, isAlignerSupported(language: language) {
            let alignerLanguage = mapLanguageForAligner(language)
            let alignedWords = aligner.align(
                audio: samples,
                text: text,
                sampleRate: 16000,
                language: alignerLanguage
            )
            progressCallback?(0.9)

            // AlignedWord → SegmentOutput 변환 (단어를 문장 단위로 그룹핑)
            segments = groupAlignedWordsIntoSegments(alignedWords)
        }

        progressCallback?(1.0)

        return TranscriptionOutput(
            text: text,
            segments: segments,
            language: language
        )
    }

    func supportedModels() -> [ModelIdentifier] {
        ModelIdentifier.allModels(for: .qwen3ASR)
            .filter { DeviceCapability.current.supports($0) }
    }

    // MARK: - Private

    /// ForcedAligner가 해당 언어를 지원하는지 확인
    private func isAlignerSupported(language: String?) -> Bool {
        guard let language else { return true } // nil이면 자동 감지 → 시도
        return forcedAlignerSupportedLanguages.contains(language.lowercased())
    }

    /// Qwen3-ASR 언어 코드를 ForcedAligner 언어명으로 매핑
    private func mapLanguageForAligner(_ language: String?) -> String {
        guard let language else { return "Korean" }
        let mapping: [String: String] = [
            "ko": "Korean", "en": "English", "zh": "Chinese",
            "ja": "Japanese", "fr": "French", "de": "German",
            "it": "Italian", "pt": "Portuguese", "ru": "Russian",
            "es": "Spanish",
            "korean": "Korean", "english": "English", "chinese": "Chinese",
            "japanese": "Japanese", "french": "French", "german": "German",
            "italian": "Italian", "portuguese": "Portuguese", "russian": "Russian",
            "spanish": "Spanish", "cantonese": "Cantonese"
        ]
        return mapping[language.lowercased()] ?? "Korean"
    }

    /// AlignedWord 배열을 문장 단위 SegmentOutput으로 그룹핑
    /// 구두점(. ! ? 등) 또는 일정 시간 간격을 기준으로 분할
    private func groupAlignedWordsIntoSegments(_ words: [AlignedWord]) -> [SegmentOutput] {
        guard !words.isEmpty else { return [] }

        var segments: [SegmentOutput] = []
        var currentWords: [AlignedWord] = []
        let maxSegmentDuration: Float = 10.0

        for word in words {
            currentWords.append(word)

            let segmentDuration = word.endTime - (currentWords.first?.startTime ?? 0)
            let endsWithPunctuation = word.text.last.map {
                ".!?。！？".contains($0)
            } ?? false

            if endsWithPunctuation || segmentDuration >= maxSegmentDuration {
                let segText = currentWords.map(\.text).joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                let start = TimeInterval(currentWords.first!.startTime)
                let end = TimeInterval(currentWords.last!.endTime)
                segments.append(SegmentOutput(text: segText, startTime: start, endTime: end))
                currentWords = []
            }
        }

        if !currentWords.isEmpty {
            let segText = currentWords.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            let start = TimeInterval(currentWords.first!.startTime)
            let end = TimeInterval(currentWords.last!.endTime)
            segments.append(SegmentOutput(text: segText, startTime: start, endTime: end))
        }

        return segments
    }
}

enum Qwen3ASREngineError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: "Qwen3-ASR 모델이 로드되지 않았습니다."
        }
    }
}
#endif
