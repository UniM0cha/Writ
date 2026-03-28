import XCTest
@testable import Writ

final class WhisperModelVariantTests: XCTestCase {

    // MARK: - Cases & RawValue

    func testAllCasesCountIsFive() {
        XCTAssertEqual(WhisperModelVariant.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(WhisperModelVariant.tiny.rawValue, "openai_whisper-tiny")
        XCTAssertEqual(WhisperModelVariant.base.rawValue, "openai_whisper-base")
        XCTAssertEqual(WhisperModelVariant.small.rawValue, "openai_whisper-small")
        XCTAssertEqual(WhisperModelVariant.largeV3.rawValue, "openai_whisper-large-v3")
        XCTAssertEqual(WhisperModelVariant.largeV3Turbo.rawValue, "openai_whisper-large-v3_turbo")
    }

    // MARK: - displayName

    func testDisplayNames() {
        XCTAssertEqual(WhisperModelVariant.tiny.displayName, "Tiny")
        XCTAssertEqual(WhisperModelVariant.base.displayName, "Base")
        XCTAssertEqual(WhisperModelVariant.small.displayName, "Small")
        XCTAssertEqual(WhisperModelVariant.largeV3.displayName, "Large v3")
        XCTAssertEqual(WhisperModelVariant.largeV3Turbo.displayName, "Large v3 Turbo")
    }

    // MARK: - diskSizeMB

    func testDiskSizeMBReturnsPositiveValues() {
        for variant in WhisperModelVariant.allCases {
            XCTAssertGreaterThan(variant.diskSizeMB, 0, "\(variant) diskSizeMB should be positive")
        }
    }

    func testDiskSizeMBSpecificValues() {
        XCTAssertEqual(WhisperModelVariant.tiny.diskSizeMB, 75)
        XCTAssertEqual(WhisperModelVariant.base.diskSizeMB, 142)
        XCTAssertEqual(WhisperModelVariant.small.diskSizeMB, 466)
        XCTAssertEqual(WhisperModelVariant.largeV3.diskSizeMB, 947)
        XCTAssertEqual(WhisperModelVariant.largeV3Turbo.diskSizeMB, 954)
    }

    func testDiskSizeIncreasesByModelComplexity() {
        XCTAssertLessThan(WhisperModelVariant.tiny.diskSizeMB, WhisperModelVariant.base.diskSizeMB)
        XCTAssertLessThan(WhisperModelVariant.base.diskSizeMB, WhisperModelVariant.small.diskSizeMB)
        XCTAssertLessThan(WhisperModelVariant.small.diskSizeMB, WhisperModelVariant.largeV3.diskSizeMB)
    }

    // MARK: - minimumRAMGB

    func testMinimumRAMGBReturnsPositiveValues() {
        for variant in WhisperModelVariant.allCases {
            XCTAssertGreaterThan(variant.minimumRAMGB, 0, "\(variant) minimumRAMGB should be positive")
        }
    }

    func testMinimumRAMGBSpecificValues() {
        XCTAssertEqual(WhisperModelVariant.tiny.minimumRAMGB, 1)
        XCTAssertEqual(WhisperModelVariant.base.minimumRAMGB, 1)
        XCTAssertEqual(WhisperModelVariant.small.minimumRAMGB, 2)
        XCTAssertEqual(WhisperModelVariant.largeV3.minimumRAMGB, 4)
        XCTAssertEqual(WhisperModelVariant.largeV3Turbo.minimumRAMGB, 4)
    }

    // MARK: - Identifiable

    func testIdentifiableIdMatchesRawValue() {
        for variant in WhisperModelVariant.allCases {
            XCTAssertEqual(variant.id, variant.rawValue, "\(variant) id should match rawValue")
        }
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip() throws {
        for variant in WhisperModelVariant.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(variant)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(WhisperModelVariant.self, from: data)
            XCTAssertEqual(decoded, variant, "\(variant) should survive Codable roundtrip")
        }
    }

    func testDecodingFromRawString() throws {
        let json = Data("\"openai_whisper-small\"".utf8)
        let decoded = try JSONDecoder().decode(WhisperModelVariant.self, from: json)
        XCTAssertEqual(decoded, .small)
    }

    func testDecodingInvalidRawValueThrows() {
        let json = Data("\"invalid-model\"".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(WhisperModelVariant.self, from: json))
    }
}

// MARK: - ModelInfo Tests (WhisperModelInfo → ModelInfo 마이그레이션)

final class ModelInfoFromWhisperTests: XCTestCase {

    func testInitWithDefaultValues() {
        let info = ModelInfo(identifier: WhisperModelVariant.tiny.modelIdentifier)
        XCTAssertEqual(info.identifier.whisperVariant, .tiny)
        XCTAssertTrue(info.isSupported)
        XCTAssertNil(info.unsupportedReason)
        if case .notDownloaded = info.state {
        } else {
            XCTFail("Default state should be .notDownloaded, got \(info.state)")
        }
    }

    func testInitWithCustomValues() {
        let info = ModelInfo(
            identifier: WhisperModelVariant.largeV3.modelIdentifier,
            state: .downloaded,
            isSupported: false,
            unsupportedReason: "Not enough RAM"
        )
        XCTAssertEqual(info.identifier.whisperVariant, .largeV3)
        XCTAssertFalse(info.isSupported)
        XCTAssertEqual(info.unsupportedReason, "Not enough RAM")
        if case .downloaded = info.state {
        } else {
            XCTFail("State should be .downloaded, got \(info.state)")
        }
    }

    func testIdReturnsIdentifierId() {
        for variant in WhisperModelVariant.allCases {
            let info = ModelInfo(identifier: variant.modelIdentifier)
            XCTAssertEqual(info.id, variant.modelIdentifier.id)
        }
    }

    func testStateCanBeUpdated() {
        var info = ModelInfo(identifier: WhisperModelVariant.base.modelIdentifier)
        info.state = .downloading(progress: 0.5)
        if case .downloading(let progress, _) = info.state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.001)
        } else {
            XCTFail("State should be .downloading")
        }

        info.state = .loaded
        if case .loaded = info.state {
        } else {
            XCTFail("State should be .loaded")
        }
    }
}
