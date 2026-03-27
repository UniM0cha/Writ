import XCTest
@testable import Writ

final class EngineTypeTests: XCTestCase {

    // MARK: - Cases & RawValue

    func testAllCasesCountIsTwo() {
        XCTAssertEqual(EngineType.allCases.count, 2)
    }

    func testRawValues() {
        XCTAssertEqual(EngineType.whisperKit.rawValue, "whisperKit")
        XCTAssertEqual(EngineType.qwen3ASR.rawValue, "qwen3ASR")
    }

    func testInitFromValidRawValue() {
        XCTAssertEqual(EngineType(rawValue: "whisperKit"), .whisperKit)
        XCTAssertEqual(EngineType(rawValue: "qwen3ASR"), .qwen3ASR)
    }

    func testInitFromInvalidRawValue() {
        XCTAssertNil(EngineType(rawValue: ""))
        XCTAssertNil(EngineType(rawValue: "WhisperKit"))
        XCTAssertNil(EngineType(rawValue: "whisper"))
        XCTAssertNil(EngineType(rawValue: "qwen3"))
        XCTAssertNil(EngineType(rawValue: "unknown"))
    }

    // MARK: - displayName

    func testDisplayNames() {
        XCTAssertEqual(EngineType.whisperKit.displayName, "Whisper")
        XCTAssertEqual(EngineType.qwen3ASR.displayName, "Qwen3-ASR")
    }

    func testDisplayNames_allCasesAreNonEmpty() {
        for engine in EngineType.allCases {
            XCTAssertFalse(engine.displayName.isEmpty, "\(engine) displayName should not be empty")
        }
    }

    func testDisplayNames_allCasesAreUnique() {
        let names = EngineType.allCases.map(\.displayName)
        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count, "All engine display names should be unique")
    }

    // MARK: - Identifiable

    func testIdentifiableIdMatchesRawValue() {
        for engine in EngineType.allCases {
            XCTAssertEqual(engine.id, engine.rawValue, "\(engine) id should match rawValue")
        }
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip() throws {
        for engine in EngineType.allCases {
            let data = try JSONEncoder().encode(engine)
            let decoded = try JSONDecoder().decode(EngineType.self, from: data)
            XCTAssertEqual(decoded, engine, "\(engine) should survive Codable roundtrip")
        }
    }

    func testDecodingFromRawString() throws {
        let json = Data("\"whisperKit\"".utf8)
        let decoded = try JSONDecoder().decode(EngineType.self, from: json)
        XCTAssertEqual(decoded, .whisperKit)
    }

    func testDecodingFromRawString_qwen() throws {
        let json = Data("\"qwen3ASR\"".utf8)
        let decoded = try JSONDecoder().decode(EngineType.self, from: json)
        XCTAssertEqual(decoded, .qwen3ASR)
    }

    func testDecodingInvalidRawValueThrows() {
        let json = Data("\"invalid-engine\"".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(EngineType.self, from: json))
    }

    func testDecodingEmptyStringThrows() {
        let json = Data("\"\"".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(EngineType.self, from: json))
    }

    func testEncodingProducesRawValue() throws {
        let data = try JSONEncoder().encode(EngineType.whisperKit)
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertEqual(jsonString, "\"whisperKit\"")
    }

    // MARK: - Equatable

    func testEquatable_sameCases() {
        XCTAssertEqual(EngineType.whisperKit, EngineType.whisperKit)
        XCTAssertEqual(EngineType.qwen3ASR, EngineType.qwen3ASR)
    }

    func testEquatable_differentCases() {
        XCTAssertNotEqual(EngineType.whisperKit, EngineType.qwen3ASR)
    }
}
