import XCTest
@testable import Writ

final class SegmentOutputTests: XCTestCase {

    // MARK: - Init Defaults

    func testInit_defaultSpeakerIsNil() {
        let segment = SegmentOutput(text: "Hello", startTime: 0.0, endTime: 1.0)
        XCTAssertNil(segment.speaker)
    }

    func testInit_storesTextAndTimes() {
        let segment = SegmentOutput(text: "Test text", startTime: 1.5, endTime: 3.0)
        XCTAssertEqual(segment.text, "Test text")
        XCTAssertEqual(segment.startTime, 1.5, accuracy: 0.001)
        XCTAssertEqual(segment.endTime, 3.0, accuracy: 0.001)
    }

    // MARK: - Init with Speaker

    func testInit_withExplicitSpeaker() {
        let segment = SegmentOutput(text: "Hello", startTime: 0.0, endTime: 1.0, speaker: "화자 1")
        XCTAssertEqual(segment.speaker, "화자 1")
    }

    func testInit_withExplicitNilSpeaker() {
        let segment = SegmentOutput(text: "Hello", startTime: 0.0, endTime: 1.0, speaker: nil)
        XCTAssertNil(segment.speaker)
    }

    func testInit_withEmptyStringSpeaker() {
        let segment = SegmentOutput(text: "Hello", startTime: 0.0, endTime: 1.0, speaker: "")
        XCTAssertEqual(segment.speaker, "")
    }

    // MARK: - Edge Cases

    func testInit_zeroTimes() {
        let segment = SegmentOutput(text: "", startTime: 0.0, endTime: 0.0)
        XCTAssertEqual(segment.startTime, 0.0)
        XCTAssertEqual(segment.endTime, 0.0)
    }

    func testInit_emptyText() {
        let segment = SegmentOutput(text: "", startTime: 0.0, endTime: 1.0)
        XCTAssertEqual(segment.text, "")
    }

    func testInit_largeTimes() {
        let segment = SegmentOutput(text: "Long audio", startTime: 3600.0, endTime: 7200.0)
        XCTAssertEqual(segment.startTime, 3600.0, accuracy: 0.001)
        XCTAssertEqual(segment.endTime, 7200.0, accuracy: 0.001)
    }
}

// MARK: - TranscriptionOutput Tests

final class TranscriptionOutputTests: XCTestCase {

    func testInit_storesProperties() {
        let segments = [
            SegmentOutput(text: "Hello", startTime: 0.0, endTime: 1.0),
            SegmentOutput(text: "World", startTime: 1.0, endTime: 2.0, speaker: "화자 1"),
        ]
        let output = TranscriptionOutput(text: "Hello World", segments: segments, language: "ko")

        XCTAssertEqual(output.text, "Hello World")
        XCTAssertEqual(output.segments.count, 2)
        XCTAssertEqual(output.language, "ko")
    }

    func testInit_nilLanguage() {
        let output = TranscriptionOutput(text: "Test", segments: [], language: nil)
        XCTAssertNil(output.language)
    }

    func testInit_emptySegments() {
        let output = TranscriptionOutput(text: "", segments: [], language: nil)
        XCTAssertTrue(output.segments.isEmpty)
    }

    func testInit_segmentsWithMixedSpeakers() {
        let segments = [
            SegmentOutput(text: "A", startTime: 0, endTime: 1, speaker: "화자 1"),
            SegmentOutput(text: "B", startTime: 1, endTime: 2),
            SegmentOutput(text: "C", startTime: 2, endTime: 3, speaker: "화자 2"),
        ]
        let output = TranscriptionOutput(text: "A B C", segments: segments, language: "ko")

        XCTAssertEqual(output.segments[0].speaker, "화자 1")
        XCTAssertNil(output.segments[1].speaker)
        XCTAssertEqual(output.segments[2].speaker, "화자 2")
    }
}
