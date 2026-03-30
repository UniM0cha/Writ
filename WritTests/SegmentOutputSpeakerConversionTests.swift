import XCTest
@testable import Writ

/// WritSegment -> SegmentOutput 변환 시 speaker 필드가 정확히 전달되는지 검증한다.
///
/// ExportSheet와 MacDetailView에서 WritSegment를 SegmentOutput으로 변환할 때
/// speaker 파라미터가 누락되면 내보내기 결과에서 발화자 정보가 사라지는 버그가 있었다.
/// 이 테스트는 변환 패턴 자체의 정확성을 검증한다.
final class SegmentOutputSpeakerConversionTests: XCTestCase {

    // MARK: - WritSegment -> SegmentOutput 변환 (speaker 포함)

    func testConversion_withSpeaker_preservesSpeaker() {
        // Given: speaker가 있는 WritSegment
        let writSegment = WritSegment(
            text: "안녕하세요",
            startTime: 0.0,
            endTime: 2.0,
            orderIndex: 0,
            speaker: "화자 1"
        )

        // When: ExportSheet/MacDetailView에서 사용하는 변환 패턴
        let output = SegmentOutput(
            text: writSegment.text,
            startTime: writSegment.startTime,
            endTime: writSegment.endTime,
            speaker: writSegment.speaker
        )

        // Then: speaker가 보존됨
        XCTAssertEqual(output.speaker, "화자 1",
                       "WritSegment의 speaker가 SegmentOutput으로 정확히 전달되어야 함")
    }

    func testConversion_withoutSpeaker_speakerIsNil() {
        // Given: speaker가 nil인 WritSegment
        let writSegment = WritSegment(
            text: "Hello",
            startTime: 0.0,
            endTime: 1.0,
            orderIndex: 0,
            speaker: nil
        )

        // When
        let output = SegmentOutput(
            text: writSegment.text,
            startTime: writSegment.startTime,
            endTime: writSegment.endTime,
            speaker: writSegment.speaker
        )

        // Then
        XCTAssertNil(output.speaker, "speaker가 nil인 WritSegment 변환 시 SegmentOutput.speaker도 nil이어야 함")
    }

    func testConversion_multipleSegments_preservesAllSpeakers() {
        // Given: 다양한 speaker를 가진 WritSegment 배열
        let writSegments = [
            WritSegment(text: "First", startTime: 0.0, endTime: 1.0, orderIndex: 0, speaker: "화자 1"),
            WritSegment(text: "Second", startTime: 1.0, endTime: 2.0, orderIndex: 1, speaker: nil),
            WritSegment(text: "Third", startTime: 2.0, endTime: 3.0, orderIndex: 2, speaker: "화자 2"),
            WritSegment(text: "Fourth", startTime: 3.0, endTime: 4.0, orderIndex: 3, speaker: "화자 1"),
        ]

        // When: ExportSheet에서 사용하는 변환 패턴과 동일
        let outputs = writSegments.sorted(by: { $0.orderIndex < $1.orderIndex }).map {
            SegmentOutput(text: $0.text, startTime: $0.startTime, endTime: $0.endTime, speaker: $0.speaker)
        }

        // Then: 모든 speaker가 정확히 보존됨
        XCTAssertEqual(outputs.count, 4)
        XCTAssertEqual(outputs[0].speaker, "화자 1")
        XCTAssertNil(outputs[1].speaker)
        XCTAssertEqual(outputs[2].speaker, "화자 2")
        XCTAssertEqual(outputs[3].speaker, "화자 1")
    }

    func testConversion_preservesTextAndTimes() {
        // Given
        let writSegment = WritSegment(
            text: "Test text",
            startTime: 10.5,
            endTime: 15.3,
            orderIndex: 5,
            speaker: "화자 3"
        )

        // When
        let output = SegmentOutput(
            text: writSegment.text,
            startTime: writSegment.startTime,
            endTime: writSegment.endTime,
            speaker: writSegment.speaker
        )

        // Then: 모든 필드가 정확히 전달됨
        XCTAssertEqual(output.text, "Test text")
        XCTAssertEqual(output.startTime, 10.5, accuracy: 0.001)
        XCTAssertEqual(output.endTime, 15.3, accuracy: 0.001)
        XCTAssertEqual(output.speaker, "화자 3")
    }

    // MARK: - 정렬 후 변환

    func testConversion_unsortedSegments_sortedByOrderIndex() {
        // Given: orderIndex 순서가 뒤섞인 세그먼트
        let writSegments = [
            WritSegment(text: "Third", startTime: 2.0, endTime: 3.0, orderIndex: 2, speaker: "화자 2"),
            WritSegment(text: "First", startTime: 0.0, endTime: 1.0, orderIndex: 0, speaker: "화자 1"),
            WritSegment(text: "Second", startTime: 1.0, endTime: 2.0, orderIndex: 1, speaker: nil),
        ]

        // When: 정렬 후 변환 (ExportSheet 패턴)
        let outputs = writSegments.sorted(by: { $0.orderIndex < $1.orderIndex }).map {
            SegmentOutput(text: $0.text, startTime: $0.startTime, endTime: $0.endTime, speaker: $0.speaker)
        }

        // Then: orderIndex 순서대로 정렬되고 speaker 보존
        XCTAssertEqual(outputs[0].text, "First")
        XCTAssertEqual(outputs[0].speaker, "화자 1")
        XCTAssertEqual(outputs[1].text, "Second")
        XCTAssertNil(outputs[1].speaker)
        XCTAssertEqual(outputs[2].text, "Third")
        XCTAssertEqual(outputs[2].speaker, "화자 2")
    }

    // MARK: - End-to-End: 변환 후 TXT 내보내기

    func testConversionThenTXTExport_speakerLabelsAppearInOutput() {
        // Given: speaker가 있는 WritSegment를 변환
        let writSegments = [
            WritSegment(text: "Hello", startTime: 0.0, endTime: 1.0, orderIndex: 0, speaker: "화자 1"),
            WritSegment(text: "World", startTime: 1.0, endTime: 2.0, orderIndex: 1, speaker: "화자 2"),
        ]

        let outputs = writSegments.sorted(by: { $0.orderIndex < $1.orderIndex }).map {
            SegmentOutput(text: $0.text, startTime: $0.startTime, endTime: $0.endTime, speaker: $0.speaker)
        }

        // When: TXT 내보내기 (타임스탬프 포함)
        let result = TXTExporter.export(segments: outputs, includeTimestamps: true)

        // Then: 화자 라벨이 포함됨
        let expected = "[00:00] [화자 1] Hello\n[00:01] [화자 2] World"
        XCTAssertEqual(result, expected)
    }

    func testConversionThenSRTExport_speakerLabelsAppearInOutput() {
        // Given: speaker가 있는 WritSegment를 변환
        let writSegments = [
            WritSegment(text: "Hello", startTime: 0.0, endTime: 1.0, orderIndex: 0, speaker: "화자 1"),
            WritSegment(text: "World", startTime: 1.0, endTime: 2.0, orderIndex: 1, speaker: nil),
        ]

        let outputs = writSegments.sorted(by: { $0.orderIndex < $1.orderIndex }).map {
            SegmentOutput(text: $0.text, startTime: $0.startTime, endTime: $0.endTime, speaker: $0.speaker)
        }

        // When: SRT 내보내기
        let result = SRTExporter.export(segments: outputs)

        // Then: 화자 라벨이 포함됨
        XCTAssertTrue(result.contains("[화자 1] Hello"),
                      "SRT 내보내기에서 화자 라벨이 포함되어야 함")
        XCTAssertTrue(result.contains("World"),
                      "화자 없는 세그먼트는 텍스트만 포함")
        XCTAssertFalse(result.contains("[화자") && result.contains("World") && result.contains("[화자 1] World"),
                       "화자 nil인 세그먼트에 화자 라벨이 붙으면 안 됨")
    }

    // MARK: - End-to-End: 변환 후 TXT 내보내기 (타임스탬프 없음)

    func testConversionThenTXTExportWithoutTimestamps_speakerNotIncluded() {
        // Given: speaker가 있는 WritSegment를 변환
        let writSegments = [
            WritSegment(text: "Hello", startTime: 0.0, endTime: 1.0, orderIndex: 0, speaker: "화자 1"),
            WritSegment(text: "World", startTime: 1.0, endTime: 2.0, orderIndex: 1, speaker: "화자 2"),
        ]

        let outputs = writSegments.sorted(by: { $0.orderIndex < $1.orderIndex }).map {
            SegmentOutput(text: $0.text, startTime: $0.startTime, endTime: $0.endTime, speaker: $0.speaker)
        }

        // When: TXT 내보내기 (타임스탬프 없음)
        let result = TXTExporter.export(segments: outputs)

        // Then: 타임스탬프 없는 모드에서는 화자 정보 미포함 (텍스트만 공백으로 연결)
        XCTAssertEqual(result, "Hello World")
        XCTAssertFalse(result.contains("화자"))
    }

    // MARK: - Edge Cases

    func testConversion_emptySegmentArray() {
        let writSegments: [WritSegment] = []

        let outputs = writSegments.sorted(by: { $0.orderIndex < $1.orderIndex }).map {
            SegmentOutput(text: $0.text, startTime: $0.startTime, endTime: $0.endTime, speaker: $0.speaker)
        }

        XCTAssertTrue(outputs.isEmpty)
    }

    func testConversion_singleSegmentWithEmptyText_andSpeaker() {
        let writSegment = WritSegment(
            text: "",
            startTime: 0.0,
            endTime: 1.0,
            orderIndex: 0,
            speaker: "화자 1"
        )

        let output = SegmentOutput(
            text: writSegment.text,
            startTime: writSegment.startTime,
            endTime: writSegment.endTime,
            speaker: writSegment.speaker
        )

        XCTAssertEqual(output.text, "")
        XCTAssertEqual(output.speaker, "화자 1")
    }
}
