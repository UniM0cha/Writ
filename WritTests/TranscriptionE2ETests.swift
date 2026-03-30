import XCTest
@testable import Writ

/// E2E 통합 테스트. 실 모델 다운로드 + 전사 수행.
/// 네트워크 + 시간이 필요하므로 일반 테스트와 분리 실행 권장:
///   xcodebuild test -scheme Writ -destination '...' -only-testing:WritTests/TranscriptionE2ETests
@MainActor
final class TranscriptionE2ETests: XCTestCase {

    // MARK: - Setup

    private var whisperEngine: WhisperKitEngine!
    private var modelManager: ModelManager!

    override func setUp() {
        super.setUp()
        whisperEngine = WhisperKitEngine()
        modelManager = ModelManager(whisperEngine: whisperEngine)
    }

    override func tearDown() {
        modelManager = nil
        whisperEngine = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func audioURL(for name: String) throws -> URL {
        guard let url = Bundle(for: type(of: self)).url(forResource: name, withExtension: "m4a") else {
            throw XCTSkip("테스트 오디오 파일 '\(name).m4a'를 번들에서 찾을 수 없음")
        }
        return url
    }

    private func transcribe(
        model: ModelIdentifier,
        audioName: String,
        language: String?
    ) async throws -> String {
        try await modelManager.loadModel(model)
        XCTAssertEqual(modelManager.activeModel, model, "모델 로드 실패: \(model.displayName)")

        let url = try audioURL(for: audioName)
        let output = try await modelManager.transcribe(
            audioURL: url,
            language: language,
            progressCallback: nil
        )
        return output.text
    }

    // MARK: - WhisperKit small — 한국어

    func test_whisperKit_small_korean1() async throws {
        let text = try await transcribe(
            model: WhisperModelVariant.small.modelIdentifier,
            audioName: "sample_ko1",
            language: "ko"
        )
        XCTAssertFalse(text.isEmpty, "전사 결과가 비어있음")
        XCTAssertTrue(
            text.contains("안녕") || text.contains("반갑"),
            "핵심 단어 미포함. 전사 결과: \(text)"
        )
    }

    func test_whisperKit_small_korean2() async throws {
        let text = try await transcribe(
            model: WhisperModelVariant.small.modelIdentifier,
            audioName: "sample_ko2",
            language: "ko"
        )
        XCTAssertFalse(text.isEmpty, "전사 결과가 비어있음")
        XCTAssertTrue(
            text.contains("날씨") || text.contains("좋"),
            "핵심 단어 미포함. 전사 결과: \(text)"
        )
    }

    func test_whisperKit_small_korean3() async throws {
        let text = try await transcribe(
            model: WhisperModelVariant.small.modelIdentifier,
            audioName: "sample_ko3",
            language: "ko"
        )
        XCTAssertFalse(text.isEmpty, "전사 결과가 비어있음")
        XCTAssertTrue(
            text.contains("음성") || text.contains("테스트") || text.contains("인식"),
            "핵심 단어 미포함. 전사 결과: \(text)"
        )
    }

    // MARK: - WhisperKit small — 영어

    func test_whisperKit_small_english1() async throws {
        let text = try await transcribe(
            model: WhisperModelVariant.small.modelIdentifier,
            audioName: "sample_en1",
            language: "en"
        )
        XCTAssertFalse(text.isEmpty, "전사 결과가 비어있음")
        XCTAssertTrue(
            text.lowercased().contains("hello") || text.lowercased().contains("how"),
            "핵심 단어 미포함. 전사 결과: \(text)"
        )
    }

    func test_whisperKit_small_english2() async throws {
        let text = try await transcribe(
            model: WhisperModelVariant.small.modelIdentifier,
            audioName: "sample_en2",
            language: "en"
        )
        XCTAssertFalse(text.isEmpty, "전사 결과가 비어있음")
        XCTAssertTrue(
            text.lowercased().contains("weather") || text.lowercased().contains("nice"),
            "핵심 단어 미포함. 전사 결과: \(text)"
        )
    }

    // MARK: - Qwen3-ASR 0.6B INT8 — 한국어

    #if os(iOS)
    func test_qwen3_0_6B_int8_korean1() async throws {
        let text = try await transcribe(
            model: .qwen3_0_6B_int8,
            audioName: "sample_ko1",
            language: "ko"
        )
        XCTAssertFalse(text.isEmpty, "전사 결과가 비어있음")
        XCTAssertTrue(
            text.contains("안녕") || text.contains("반갑"),
            "핵심 단어 미포함. 전사 결과: \(text)"
        )
    }

    func test_qwen3_0_6B_int8_korean2() async throws {
        let text = try await transcribe(
            model: .qwen3_0_6B_int8,
            audioName: "sample_ko2",
            language: "ko"
        )
        XCTAssertFalse(text.isEmpty, "전사 결과가 비어있음")
        XCTAssertTrue(
            text.contains("날씨") || text.contains("좋"),
            "핵심 단어 미포함. 전사 결과: \(text)"
        )
    }

    func test_qwen3_0_6B_int8_korean3() async throws {
        let text = try await transcribe(
            model: .qwen3_0_6B_int8,
            audioName: "sample_ko3",
            language: "ko"
        )
        XCTAssertFalse(text.isEmpty, "전사 결과가 비어있음")
        XCTAssertTrue(
            text.contains("음성") || text.contains("테스트") || text.contains("인식"),
            "핵심 단어 미포함. 전사 결과: \(text)"
        )
    }

    // MARK: - Qwen3-ASR 0.6B INT8 — 영어

    func test_qwen3_0_6B_int8_english1() async throws {
        let text = try await transcribe(
            model: .qwen3_0_6B_int8,
            audioName: "sample_en1",
            language: "en"
        )
        XCTAssertFalse(text.isEmpty, "전사 결과가 비어있음")
        XCTAssertTrue(
            text.lowercased().contains("hello") || text.lowercased().contains("how"),
            "핵심 단어 미포함. 전사 결과: \(text)"
        )
    }

    func test_qwen3_0_6B_int8_english2() async throws {
        let text = try await transcribe(
            model: .qwen3_0_6B_int8,
            audioName: "sample_en2",
            language: "en"
        )
        XCTAssertFalse(text.isEmpty, "전사 결과가 비어있음")
        XCTAssertTrue(
            text.lowercased().contains("weather") || text.lowercased().contains("nice"),
            "핵심 단어 미포함. 전사 결과: \(text)"
        )
    }
    #endif
}
