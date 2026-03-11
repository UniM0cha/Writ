import Foundation
@testable import Writ

/// TranscriptionEngine 프로토콜의 테스트용 Mock 구현체.
/// 각 메서드 호출을 기록하고, 테스트에서 지정한 결과를 반환한다.
final class MockTranscriptionEngine: TranscriptionEngine, @unchecked Sendable {

    // MARK: - Call Tracking

    private(set) var loadModelCallCount = 0
    private(set) var loadModelLastVariant: WhisperModelVariant?
    private(set) var unloadModelCallCount = 0
    private(set) var transcribeCallCount = 0
    private(set) var transcribeLastAudioURL: URL?
    private(set) var transcribeLastLanguage: String?

    // MARK: - Configurable Behavior

    /// loadModel 호출 시 던질 에러. nil이면 성공.
    var loadModelError: Error?

    /// transcribe 호출 시 반환할 결과. nil이면 에러를 던진다.
    var transcribeResult: TranscriptionOutput?

    /// transcribe 호출 시 던질 에러. transcribeResult가 nil일 때 사용.
    var transcribeError: Error?

    /// currentModel 반환값
    var stubbedCurrentModel: WhisperModelVariant?

    /// supportedModels 반환값
    var stubbedSupportedModels: [WhisperModelVariant] = WhisperModelVariant.allCases

    // MARK: - TranscriptionEngine

    var currentModel: WhisperModelVariant? {
        stubbedCurrentModel
    }

    func loadModel(
        _ model: WhisperModelVariant,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws {
        loadModelCallCount += 1
        loadModelLastVariant = model

        // 진행률 콜백 시뮬레이션
        progressCallback?(0.5)
        progressCallback?(1.0)

        if let error = loadModelError {
            throw error
        }
        stubbedCurrentModel = model
    }

    func unloadModel() async {
        unloadModelCallCount += 1
        stubbedCurrentModel = nil
    }

    func transcribe(
        audioURL: URL,
        language: String?,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws -> TranscriptionOutput {
        transcribeCallCount += 1
        transcribeLastAudioURL = audioURL
        transcribeLastLanguage = language

        progressCallback?(1.0)

        if let result = transcribeResult {
            return result
        }
        if let error = transcribeError {
            throw error
        }
        // 기본 빈 결과
        return TranscriptionOutput(text: "", segments: [], language: nil)
    }

    func supportedModels() -> [WhisperModelVariant] {
        stubbedSupportedModels
    }

    // MARK: - Helpers

    func reset() {
        loadModelCallCount = 0
        loadModelLastVariant = nil
        unloadModelCallCount = 0
        transcribeCallCount = 0
        transcribeLastAudioURL = nil
        transcribeLastLanguage = nil
        loadModelError = nil
        transcribeResult = nil
        transcribeError = nil
        stubbedCurrentModel = nil
        stubbedSupportedModels = WhisperModelVariant.allCases
    }
}
