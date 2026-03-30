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

    // MARK: - Speaker Labels (with Timestamps)

    func testExportWithTimestamps_singleSegmentWithSpeaker_includesSpeakerLabel() {
        let segments = [
            SegmentOutput(text: "안녕하세요", startTime: 0.0, endTime: 2.0, speaker: "화자 1")
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        XCTAssertEqual(result, "[00:00] [화자 1] 안녕하세요")
    }

    func testExportWithTimestamps_segmentWithoutSpeaker_noSpeakerLabel() {
        let segments = [
            SegmentOutput(text: "Hello", startTime: 0.0, endTime: 1.0)
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        XCTAssertEqual(result, "[00:00] Hello")
        // 발화자 정보가 없으면 대괄호가 타임스탬프 이후에 나오면 안 됨
        XCTAssertFalse(result.contains("[00:00] ["))
    }

    func testExportWithTimestamps_mixedSpeakerSegments() {
        let segments = [
            SegmentOutput(text: "Hi", startTime: 0.0, endTime: 1.0, speaker: "화자 1"),
            SegmentOutput(text: "Hello", startTime: 1.0, endTime: 2.0),
            SegmentOutput(text: "Bye", startTime: 2.0, endTime: 3.0, speaker: "화자 2"),
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        let expected = "[00:00] [화자 1] Hi\n[00:01] Hello\n[00:02] [화자 2] Bye"
        XCTAssertEqual(result, expected)
    }

    func testExportWithTimestamps_multipleSpeakers_allWithSpeakers() {
        let segments = [
            SegmentOutput(text: "First", startTime: 0.0, endTime: 1.0, speaker: "화자 1"),
            SegmentOutput(text: "Second", startTime: 1.0, endTime: 2.0, speaker: "화자 2"),
            SegmentOutput(text: "Third", startTime: 2.0, endTime: 3.0, speaker: "화자 1"),
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        XCTAssertTrue(result.contains("[화자 1] First"))
        XCTAssertTrue(result.contains("[화자 2] Second"))
        XCTAssertTrue(result.contains("[화자 1] Third"))
    }

    func testExportWithTimestamps_speakerWithWhitespaceText_trimmingStillApplied() {
        let segments = [
            SegmentOutput(text: "  spaced  ", startTime: 0.0, endTime: 1.0, speaker: "화자 1")
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        XCTAssertEqual(result, "[00:00] [화자 1] spaced")
        // 화자 라벨과 텍스트 사이에 여분의 공백이 없어야 함
        XCTAssertFalse(result.contains("[화자 1]  spaced"))
    }

    func testExportWithTimestamps_speakerLabel_timestampFormatting() {
        // 65초 = 1분 5초 지점에서 화자 라벨 포함
        let segments = [
            SegmentOutput(text: "Late segment", startTime: 65.0, endTime: 70.0, speaker: "화자 2")
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        XCTAssertEqual(result, "[01:05] [화자 2] Late segment")
    }

    func testExportWithTimestamps_nilSpeaker_explicitNil() {
        let segments = [
            SegmentOutput(text: "Test", startTime: 0.0, endTime: 1.0, speaker: nil)
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        XCTAssertEqual(result, "[00:00] Test")
    }

    // MARK: - Speaker Labels (without Timestamps)

    func testExportWithoutTimestamps_speakerIsIgnored() {
        // 타임스탬프 없이 내보내기 시 화자 정보는 포함되지 않음
        let segments = [
            SegmentOutput(text: "Hello", startTime: 0.0, endTime: 1.0, speaker: "화자 1"),
            SegmentOutput(text: "World", startTime: 1.0, endTime: 2.0, speaker: "화자 2"),
        ]

        let result = TXTExporter.export(segments: segments)

        XCTAssertEqual(result, "Hello World")
        XCTAssertFalse(result.contains("화자"), "타임스탬프 없는 모드에서는 화자 라벨이 포함되면 안 됨")
    }

    // MARK: - Speaker Edge Cases

    func testExportWithTimestamps_emptyStringSpeaker_stillShowsBrackets() {
        // 빈 문자열 speaker는 기술적으로 nil이 아니므로 빈 대괄호가 나올 수 있음
        let segments = [
            SegmentOutput(text: "Text", startTime: 0.0, endTime: 1.0, speaker: "")
        ]

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)

        // 빈 speaker가 non-nil이면 [] 포맷이 적용됨
        XCTAssertEqual(result, "[00:00] [] Text")
    }

    func testExportWithTimestamps_manySpeakers_correctLabeling() {
        // 다수의 화자가 있는 대화
        let segments = (1...5).map { i in
            SegmentOutput(
                text: "Segment \(i)",
                startTime: TimeInterval(i - 1),
                endTime: TimeInterval(i),
                speaker: "화자 \(i)"
            )
        }

        let result = TXTExporter.export(segments: segments, includeTimestamps: true)
        let lines = result.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 5)
        for i in 1...5 {
            XCTAssertTrue(lines[i - 1].contains("[화자 \(i)]"),
                          "Line \(i)에 화자 \(i) 라벨이 있어야 함")
        }
    }
}
