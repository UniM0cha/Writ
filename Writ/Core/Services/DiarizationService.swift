#if os(iOS)
import Foundation
import os
import SpeechVAD
import AudioCommon

private let logger = Logger(subsystem: AppGroupConstants.logSubsystem, category: "Diarization")

/// 발화자 구분 서비스. pyannote segmentation + WeSpeaker 임베딩 파이프라인.
/// WhisperKit과 Qwen3-ASR 양쪽 엔진 공용으로 사용.
@MainActor
final class DiarizationService: ObservableObject {
    @Published var isLoaded = false
    @Published var isLoading = false

    private var pipeline: PyannoteDiarizationPipeline?

    /// 발화자 구분 모델 로드 (~32MB: Silero VAD + pyannote + WeSpeaker)
    func loadModels(progressHandler: ((Double, String) -> Void)? = nil) async throws {
        guard !isLoaded, !isLoading else { return }
        isLoading = true

        do {
            let loaded = try await PyannoteDiarizationPipeline.fromPretrained(
                segModelId: "aufklarer/Pyannote-Segmentation-MLX",
                embModelId: "aufklarer/WeSpeaker-ResNet34-LM-MLX",
                progressHandler: { progress, status in
                    logger.debug("diarization model progress: \(progress) - \(status)")
                    progressHandler?(progress, status)
                }
            )
            self.pipeline = loaded
            isLoaded = true
            isLoading = false
            logger.info("Diarization models loaded successfully")
        } catch {
            isLoading = false
            logger.error("Failed to load diarization models: \(error)")
            throw error
        }
    }

    /// 오디오에서 발화자 구분 수행
    func diarize(audioURL: URL) async throws -> DiarizationResult {
        guard let pipeline else {
            throw DiarizationServiceError.modelsNotLoaded
        }

        let samples = try AudioSampleLoader.load(url: audioURL)

        return pipeline.diarize(
            audio: samples,
            sampleRate: 16000,
            config: DiarizationConfig(
                onset: 0.5,
                offset: 0.3,
                minSpeechDuration: 0.3,
                minSilenceDuration: 0.15,
                clusteringThreshold: 0.715
            )
        )
    }

    /// 전사 세그먼트에 발화자 정보를 병합
    func merge(transcription: TranscriptionOutput, diarization: DiarizationResult) -> TranscriptionOutput {
        guard !transcription.segments.isEmpty, !diarization.segments.isEmpty else {
            return transcription
        }

        let mergedSegments = transcription.segments.map { segment in
            let speaker = findBestSpeaker(
                segmentStart: segment.startTime,
                segmentEnd: segment.endTime,
                diarizationSegments: diarization.segments
            )
            return SegmentOutput(
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime,
                speaker: speaker
            )
        }

        return TranscriptionOutput(
            text: transcription.text,
            segments: mergedSegments,
            language: transcription.language
        )
    }

    func unload() {
        pipeline = nil
        isLoaded = false
    }

    // MARK: - Private

    /// 전사 세그먼트 시간 범위와 겹치는 시간이 가장 긴 발화자를 찾음
    private func findBestSpeaker(
        segmentStart: TimeInterval,
        segmentEnd: TimeInterval,
        diarizationSegments: [DiarizedSegment]
    ) -> String? {
        var bestSpeaker: String?
        var maxOverlap: TimeInterval = 0

        for diarSeg in diarizationSegments {
            let overlapStart = max(segmentStart, TimeInterval(diarSeg.startTime))
            let overlapEnd = min(segmentEnd, TimeInterval(diarSeg.endTime))
            let overlap = overlapEnd - overlapStart

            if overlap > maxOverlap {
                maxOverlap = overlap
                bestSpeaker = "화자 \(diarSeg.speakerId + 1)"
            }
        }

        return bestSpeaker
    }
}

enum DiarizationServiceError: LocalizedError {
    case modelsNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelsNotLoaded: "발화자 구분 모델이 로드되지 않았습니다."
        }
    }
}
#endif
