import XCTest
@testable import Writ

final class TXTExporterTests: XCTestCase {

    // MARK: - Empty Input

    func testExportEmptySegments_withoutTimestamps_returnsEmptyString() {
        let result = TXTExporter.export(segments: [])
        XCTAssertEqual(result, "")
    }

    func testExportEmptySegments_withTimestamps_returnsEmptyString() {
        let result = TXTExporter.export(segments: [], includeTimestamps: true)
        XCTAssertEqual(result, "")
    }

    // MARK: - Without Timestamps

    func testExportWithoutTimestamps_singleSegment() {
        let segments = [
            SegmentOutput(text: "Hello world", startTime: 0.0, endTime: 1.0)
        ]

        let result = TXTExporter.export(segments: segments)

        XCTAssertEqual(result, "Hello world")
    }

    func testExportWithoutTimestamps_multipleSegments_joinedBySpace() {
        let segments = [
            SegmentOutput(text: "Hello", startTime: 0.0, endTime: 1.0),
            SegmentOutput(text: "beautiful", startTime: 1.0, endTime: 2.0),
            SegmentOutput(text: "world", startTime: 2.0, endTime: 3.0),
        ]

        let result = TXTExporter.export(segments: segments)

        XCTAssertEqual(result, "Hello beautiful world")
    }

    func testExportWithoutTimestamps_defaultParameter() {
        // includeTimestamps defaults to false
        let segments = [
            SegmentOutput(text: "Test", startTime: 0.0, endTime: 1.0)
        ]

        let withDefault = TXTExporter.export(segments: segments)
        let withExplicitFalse = TXTExporter.export(segments: segments, includeTimestamps: false)

        XCTAssertEqual(withDefault, withExplicitFalse)
    }

    // MARK: - With Timestamps

    func testExportWithTimestamps_singleSegment() {
        let segments = [
            SegmentOutput(text: "Hello", startTime: 0.0, endTime: 1.0)
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        XCTAssertEqual(result, "[00:00] Hello")
    }

    func testExportWithTimestamps_multipleSegments_separatedByNewline() {
        let segments = [
            SegmentOutput(text: "First line", startTime: 0.0, endTime: 5.0),
            SegmentOutput(text: "Second line", startTime: 5.0, endTime: 10.0),
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        let expected = "[00:00] First line\n[00:05] Second line"
        XCTAssertEqual(result, expected)
    }

    // MARK: - Timestamp Formatting

    func testTimestampFormatting_zeroSeconds() {
        let segments = [
            SegmentOutput(text: "Start", startTime: 0.0, endTime: 1.0)
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        XCTAssertTrue(result.hasPrefix("[00:00]"))
    }

    func testTimestampFormatting_65seconds_showsOneMinuteFiveSeconds() {
        let segments = [
            SegmentOutput(text: "Text", startTime: 65.0, endTime: 70.0)
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        XCTAssertTrue(result.hasPrefix("[01:05]"))
    }

    func testTimestampFormatting_3661seconds_showsTotalMinutes() {
        // 3661 seconds = 61 minutes and 1 second
        // TXTExporter uses total minutes (not hours:minutes), so this should be 61:01
        let segments = [
            SegmentOutput(text: "Long", startTime: 3661.0, endTime: 3662.0)
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        XCTAssertTrue(result.hasPrefix("[61:01]"))
    }

    func testTimestampFormatting_59seconds() {
        let segments = [
            SegmentOutput(text: "Almost a minute", startTime: 59.0, endTime: 60.0)
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        XCTAssertTrue(result.hasPrefix("[00:59]"))
    }

    // MARK: - Whitespace Trimming

    func testExportWithoutTimestamps_trimsWhitespace() {
        let segments = [
            SegmentOutput(text: "  hello  ", startTime: 0.0, endTime: 1.0),
            SegmentOutput(text: " world ", startTime: 1.0, endTime: 2.0),
        ]

        let result = TXTExporter.export(segments: segments)

        XCTAssertEqual(result, "hello world")
    }

    func testExportWithTimestamps_trimsWhitespace() {
        let segments = [
            SegmentOutput(text: "  hello  ", startTime: 0.0, endTime: 1.0),
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        XCTAssertEqual(result, "[00:00] hello")
    }

    func testExportTrimsNewlines() {
        let segments = [
            SegmentOutput(text: "\nhello\n", startTime: 0.0, endTime: 1.0)
        ]

        let result = TXTExporter.export(segments: segments)

        XCTAssertEqual(result, "hello")
    }
}
