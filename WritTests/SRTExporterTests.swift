import XCTest
@testable import Writ

final class SRTExporterTests: XCTestCase {

    // MARK: - Empty Input

    func testExportEmptySegments_returnsEmptyString() {
        let result = SRTExporter.export(segments: [])
        XCTAssertEqual(result, "")
    }

    // MARK: - Single Segment

    func testExportSingleSegment_producesCorrectSRTFormat() {
        let segments = [
            SegmentOutput(text: "Hello world", startTime: 0.0, endTime: 2.5)
        ]

        let result = SRTExporter.export(segments: segments)

        let expected = """
        1
        00:00:00,000 --> 00:00:02,500
        Hello world
        """
        XCTAssertEqual(result, trimmedLines(expected))
    }

    // MARK: - Multiple Segments

    func testExportMultipleSegments_correctNumberingAndSeparation() {
        let segments = [
            SegmentOutput(text: "First", startTime: 0.0, endTime: 1.0),
            SegmentOutput(text: "Second", startTime: 1.0, endTime: 2.0),
            SegmentOutput(text: "Third", startTime: 2.0, endTime: 3.0),
        ]

        let result = SRTExporter.export(segments: segments)

        let expected = """
        1
        00:00:00,000 --> 00:00:01,000
        First

        2
        00:00:01,000 --> 00:00:02,000
        Second

        3
        00:00:02,000 --> 00:00:03,000
        Third
        """
        XCTAssertEqual(result, trimmedLines(expected))
    }

    // MARK: - Timestamp Formatting

    func testTimestampFormatting_hours() {
        let segments = [
            SegmentOutput(text: "Long audio", startTime: 3661.5, endTime: 7322.75)
        ]

        let result = SRTExporter.export(segments: segments)

        XCTAssertTrue(result.contains("01:01:01,500"))
        XCTAssertTrue(result.contains("02:02:02,750"))
    }

    func testTimestampFormatting_zeroTime() {
        let segments = [
            SegmentOutput(text: "Start", startTime: 0.0, endTime: 0.0)
        ]

        let result = SRTExporter.export(segments: segments)

        XCTAssertTrue(result.contains("00:00:00,000 --> 00:00:00,000"))
    }

    func testTimestampFormatting_minutesAndSeconds() {
        let segments = [
            SegmentOutput(text: "Mid", startTime: 65.0, endTime: 130.75)
        ]

        let result = SRTExporter.export(segments: segments)

        XCTAssertTrue(result.contains("00:01:05,000"))
        XCTAssertTrue(result.contains("00:02:10,750"))
    }

    func testTimestampFormatting_usesCommaForMilliseconds() {
        let segments = [
            SegmentOutput(text: "Test", startTime: 1.234, endTime: 2.567)
        ]

        let result = SRTExporter.export(segments: segments)

        // SRT standard uses comma, not period
        XCTAssertTrue(result.contains("00:00:01,234"))
        XCTAssertTrue(result.contains("00:00:02,567"))
    }

    // MARK: - Whitespace Trimming

    func testExport_trimsWhitespaceFromText() {
        let segments = [
            SegmentOutput(text: "  padded text  ", startTime: 0.0, endTime: 1.0)
        ]

        let result = SRTExporter.export(segments: segments)

        XCTAssertTrue(result.contains("padded text"))
        XCTAssertFalse(result.contains("  padded"))
    }

    func testExport_trimsNewlinesFromText() {
        let segments = [
            SegmentOutput(text: "\nhello\n", startTime: 0.0, endTime: 1.0)
        ]

        let result = SRTExporter.export(segments: segments)
        let lines = result.components(separatedBy: "\n")

        // Index, timestamp, text - the text line should be "hello" with no extra newlines
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[2], "hello")
    }

    // MARK: - Helpers

    /// Strips leading indentation from multiline string literal so we can write readable expectations.
    private func trimmedLines(_ string: String) -> String {
        string.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .init(charactersIn: " ")) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
    }
}
