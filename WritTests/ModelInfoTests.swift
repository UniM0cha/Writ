import XCTest
@testable import Writ

final class ModelInfoTests: XCTestCase {

    // MARK: - Init Defaults

    func testInit_defaultValues() {
        let identifier = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "test",
            displayName: "Test",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )
        let info = ModelInfo(identifier: identifier)

        XCTAssertEqual(info.identifier, identifier)
        XCTAssertTrue(info.isSupported)
        XCTAssertNil(info.unsupportedReason)
        if case .notDownloaded = info.state {
            // expected
        } else {
            XCTFail("Default state should be .notDownloaded, got \(info.state)")
        }
    }

    // MARK: - Init Custom Values

    func testInit_customValues() {
        let identifier = ModelIdentifier.qwen3_0_6B_int8
        let info = ModelInfo(
            identifier: identifier,
            state: .downloaded,
            isSupported: false,
            unsupportedReason: "Not enough RAM"
        )

        XCTAssertEqual(info.identifier, identifier)
        XCTAssertFalse(info.isSupported)
        XCTAssertEqual(info.unsupportedReason, "Not enough RAM")
        if case .downloaded = info.state {
            // expected
        } else {
            XCTFail("State should be .downloaded, got \(info.state)")
        }
    }

    // MARK: - Identifiable

    func testId_delegatesToIdentifier() {
        let identifier = ModelIdentifier(
            engine: .qwen3ASR,
            variantKey: "some/key",
            displayName: "Display",
            diskSizeMB: 50,
            minimumRAMGB: 1
        )
        let info = ModelInfo(identifier: identifier)
        XCTAssertEqual(info.id, identifier.id)
    }

    func testId_whisperModel() {
        let identifier = WhisperModelVariant.small.modelIdentifier
        let info = ModelInfo(identifier: identifier)
        XCTAssertEqual(info.id, "whisperKit/openai_whisper-small")
    }

    func testId_qwenModel() {
        let identifier = ModelIdentifier.qwen3_0_6B_int8
        let info = ModelInfo(identifier: identifier)
        XCTAssertEqual(info.id, "qwen3ASR/UniMocha/Qwen3-ASR-0.6B-CoreML-INT8")
    }

    // MARK: - State Mutation

    func testState_canBeUpdated() {
        let identifier = WhisperModelVariant.base.modelIdentifier
        var info = ModelInfo(identifier: identifier)

        info.state = .downloading(progress: 0.5)
        if case .downloading(let progress, _) = info.state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.001)
        } else {
            XCTFail("State should be .downloading")
        }

        info.state = .downloaded
        if case .downloaded = info.state {
            // expected
        } else {
            XCTFail("State should be .downloaded")
        }

        info.state = .loading
        if case .loading = info.state {
            // expected
        } else {
            XCTFail("State should be .loading")
        }

        info.state = .loaded
        if case .loaded = info.state {
            // expected
        } else {
            XCTFail("State should be .loaded")
        }

        info.state = .error("Test error")
        if case .error(let message) = info.state {
            XCTAssertEqual(message, "Test error")
        } else {
            XCTFail("State should be .error")
        }
    }

    // MARK: - isSupported Mutation

    func testIsSupported_canBeUpdated() {
        let identifier = ModelIdentifier.qwen3_0_6B_int8
        var info = ModelInfo(identifier: identifier)

        XCTAssertTrue(info.isSupported)
        info.isSupported = false
        XCTAssertFalse(info.isSupported)
    }

    // MARK: - unsupportedReason Mutation

    func testUnsupportedReason_canBeSetAndCleared() {
        let identifier = ModelIdentifier.qwen3_0_6B_int8
        var info = ModelInfo(identifier: identifier)

        XCTAssertNil(info.unsupportedReason)
        info.unsupportedReason = "RAM 부족"
        XCTAssertEqual(info.unsupportedReason, "RAM 부족")
        info.unsupportedReason = nil
        XCTAssertNil(info.unsupportedReason)
    }

    // MARK: - Various Identifiers

    func testInit_withAllQwenModels() {
        for model in ModelIdentifier.allModels(for: .qwen3ASR) {
            let info = ModelInfo(identifier: model)
            XCTAssertEqual(info.identifier.engine, .qwen3ASR)
            XCTAssertTrue(info.isSupported)
            XCTAssertNil(info.unsupportedReason)
        }
    }

    func testInit_withAllWhisperModels() {
        for variant in WhisperModelVariant.allCases {
            let info = ModelInfo(identifier: variant.modelIdentifier)
            XCTAssertEqual(info.identifier.engine, .whisperKit)
            XCTAssertTrue(info.isSupported)
        }
    }
}
