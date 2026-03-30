import XCTest
@testable import Writ

/// FormattingHelpers 유틸리티의 포맷팅 및 로직 테스트
final class FormattingHelpersTests: XCTestCase {

    // MARK: - formatRecordingTime (녹음 타이머, zero-padded MM:SS)

    func test_formatRecordingTime_zero() {
        XCTAssertEqual(FormattingHelpers.formatRecordingTime(0), "00:00")
    }

    func test_formatRecordingTime_oneSecond() {
        XCTAssertEqual(FormattingHelpers.formatRecordingTime(1), "00:01")
    }

    func test_formatRecordingTime_59seconds() {
        XCTAssertEqual(FormattingHelpers.formatRecordingTime(59), "00:59")
    }

    func test_formatRecordingTime_oneMinute() {
        XCTAssertEqual(FormattingHelpers.formatRecordingTime(60), "01:00")
    }

    func test_formatRecordingTime_oneMinuteOneSecond() {
        XCTAssertEqual(FormattingHelpers.formatRecordingTime(61), "01:01")
    }

    func test_formatRecordingTime_tenMinutes() {
        XCTAssertEqual(FormattingHelpers.formatRecordingTime(600), "10:00")
    }

    func test_formatRecordingTime_99minutes59seconds() {
        XCTAssertEqual(FormattingHelpers.formatRecordingTime(5999), "99:59")
    }

    func test_formatRecordingTime_overflowsGracefully() {
        // 100분 이상에서도 크래시 없이 동작해야 함
        XCTAssertEqual(FormattingHelpers.formatRecordingTime(6000), "100:00")
    }

    func test_formatRecordingTime_fractionalSecondsAreTruncated() {
        // 1.9초는 1초로 표시 (Int 변환)
        XCTAssertEqual(FormattingHelpers.formatRecordingTime(1.9), "00:01")
    }

    func test_formatRecordingTime_verySmallFractionIsZero() {
        XCTAssertEqual(FormattingHelpers.formatRecordingTime(0.001), "00:00")
    }

    // MARK: - formatPlaybackTime (재생 시간, M:SS)

    func test_formatPlaybackTime_zero() {
        XCTAssertEqual(FormattingHelpers.formatPlaybackTime(0), "0:00")
    }

    func test_formatPlaybackTime_oneSecond() {
        XCTAssertEqual(FormattingHelpers.formatPlaybackTime(1), "0:01")
    }

    func test_formatPlaybackTime_59seconds() {
        XCTAssertEqual(FormattingHelpers.formatPlaybackTime(59), "0:59")
    }

    func test_formatPlaybackTime_oneMinute() {
        XCTAssertEqual(FormattingHelpers.formatPlaybackTime(60), "1:00")
    }

    func test_formatPlaybackTime_tenMinutes() {
        // 분은 zero-pad 없이 표시
        XCTAssertEqual(FormattingHelpers.formatPlaybackTime(600), "10:00")
    }

    func test_formatPlaybackTime_noPaddingOnMinutes() {
        // 분에 zero-pad가 없는지 명시적 확인
        let result = FormattingHelpers.formatPlaybackTime(62)
        XCTAssertEqual(result, "1:02")
        XCTAssertFalse(result.hasPrefix("0"))
    }

    // MARK: - formatShortDuration

    func test_formatShortDuration_zero() {
        XCTAssertEqual(FormattingHelpers.formatShortDuration(0), "0:00")
    }

    func test_formatShortDuration_30seconds() {
        XCTAssertEqual(FormattingHelpers.formatShortDuration(30), "0:30")
    }

    func test_formatShortDuration_90seconds() {
        XCTAssertEqual(FormattingHelpers.formatShortDuration(90), "1:30")
    }

    // MARK: - formatDurationWithHours

    func test_formatDurationWithHours_zero() {
        XCTAssertEqual(FormattingHelpers.formatDurationWithHours(0), "0:00")
    }

    func test_formatDurationWithHours_lessThanOneHour() {
        XCTAssertEqual(FormattingHelpers.formatDurationWithHours(125), "2:05")
    }

    func test_formatDurationWithHours_exactlyOneHour() {
        XCTAssertEqual(FormattingHelpers.formatDurationWithHours(3600), "1:00:00")
    }

    func test_formatDurationWithHours_oneHourOneMinuteOneSecond() {
        XCTAssertEqual(FormattingHelpers.formatDurationWithHours(3661), "1:01:01")
    }

    func test_formatDurationWithHours_twoHoursFiftyNineMinutes() {
        // 2시간 59분 59초 = 10799초
        XCTAssertEqual(FormattingHelpers.formatDurationWithHours(10799), "2:59:59")
    }

    func test_formatDurationWithHours_noHoursOmitsHourPart() {
        // 59분 59초에서는 시간 부분이 없어야 함
        let result = FormattingHelpers.formatDurationWithHours(3599)
        XCTAssertFalse(result.contains(":00:"), "시간이 0이면 시간 부분이 생략되어야 함")
        XCTAssertEqual(result, "59:59")
    }

    func test_formatDurationWithHours_secondsZeroPadded() {
        XCTAssertEqual(FormattingHelpers.formatDurationWithHours(61), "1:01")
    }

    func test_formatDurationWithHours_minutesZeroPaddedWithHours() {
        // 1시간 2분 3초
        XCTAssertEqual(FormattingHelpers.formatDurationWithHours(3723), "1:02:03")
    }

    // MARK: - formatDurationKorean

    func test_formatDurationKorean_zero() {
        XCTAssertEqual(FormattingHelpers.formatDurationKorean(0), "0분 0초")
    }

    func test_formatDurationKorean_30seconds() {
        XCTAssertEqual(FormattingHelpers.formatDurationKorean(30), "0분 30초")
    }

    func test_formatDurationKorean_oneMinute30seconds() {
        XCTAssertEqual(FormattingHelpers.formatDurationKorean(90), "1분 30초")
    }

    func test_formatDurationKorean_exactlyOneHour() {
        XCTAssertEqual(FormattingHelpers.formatDurationKorean(3600), "1시간 0분")
    }

    func test_formatDurationKorean_oneHour30minutes() {
        XCTAssertEqual(FormattingHelpers.formatDurationKorean(5400), "1시간 30분")
    }

    func test_formatDurationKorean_twoHours15minutes() {
        // 2시간 15분 = 8100초 (남은 초는 무시됨)
        XCTAssertEqual(FormattingHelpers.formatDurationKorean(8100), "2시간 15분")
    }

    func test_formatDurationKorean_hoursOmitsSeconds() {
        // 1시간 2분 30초 - 초 정보는 표시되지 않음
        XCTAssertEqual(FormattingHelpers.formatDurationKorean(3750), "1시간 2분")
        XCTAssertFalse(FormattingHelpers.formatDurationKorean(3750).contains("초"))
    }

    // MARK: - formatSectionDate

    func test_formatSectionDate_today() {
        XCTAssertEqual(FormattingHelpers.formatSectionDate(Date()), "오늘")
    }

    func test_formatSectionDate_yesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertEqual(FormattingHelpers.formatSectionDate(yesterday), "어제")
    }

    func test_formatSectionDate_olderDate_isNotTodayOrYesterday() {
        let oldDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let result = FormattingHelpers.formatSectionDate(oldDate)
        XCTAssertNotEqual(result, "오늘")
        XCTAssertNotEqual(result, "어제")
        XCTAssertFalse(result.isEmpty, "오래된 날짜의 포맷 결과는 빈 문자열이 아니어야 함")
    }

    func test_formatSectionDate_futureDate_isNotTodayOrYesterday() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let result = FormattingHelpers.formatSectionDate(futureDate)
        XCTAssertNotEqual(result, "오늘")
        XCTAssertNotEqual(result, "어제")
    }

    func test_formatSectionDate_todayStartOfDay() {
        // 오늘 0시 0분 0초도 "오늘"
        let startOfToday = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(FormattingHelpers.formatSectionDate(startOfToday), "오늘")
    }

    // MARK: - speedLabel

    func test_speedLabel_1x() {
        XCTAssertEqual(FormattingHelpers.speedLabel(for: 1.0), "1.0x")
    }

    func test_speedLabel_0_5x() {
        XCTAssertEqual(FormattingHelpers.speedLabel(for: 0.5), "0.5x")
    }

    func test_speedLabel_0_75x() {
        XCTAssertEqual(FormattingHelpers.speedLabel(for: 0.75), "0.8x")
    }

    func test_speedLabel_1_25x() {
        // String(format: "%.1f", 1.25) rounds to "1.2" (banker's rounding)
        XCTAssertEqual(FormattingHelpers.speedLabel(for: 1.25), "1.2x")
    }

    func test_speedLabel_1_5x() {
        XCTAssertEqual(FormattingHelpers.speedLabel(for: 1.5), "1.5x")
    }

    func test_speedLabel_2x() {
        // 2.0은 정수이므로 "2.0x"
        XCTAssertEqual(FormattingHelpers.speedLabel(for: 2.0), "2.0x")
    }

    func test_speedLabel_3x() {
        XCTAssertEqual(FormattingHelpers.speedLabel(for: 3.0), "3.0x")
    }

    func test_speedLabel_containsXSuffix() {
        for speed: Float in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0] {
            XCTAssertTrue(
                FormattingHelpers.speedLabel(for: speed).hasSuffix("x"),
                "\(speed)의 라벨이 'x'로 끝나야 함"
            )
        }
    }

    // MARK: - nextSpeed

    func test_nextSpeed_fromFirst() {
        let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        XCTAssertEqual(FormattingHelpers.nextSpeed(current: 0.5, speeds: speeds), 0.75)
    }

    func test_nextSpeed_fromMiddle() {
        let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        XCTAssertEqual(FormattingHelpers.nextSpeed(current: 1.0, speeds: speeds), 1.25)
    }

    func test_nextSpeed_fromLast_wrapsToFirst() {
        let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        XCTAssertEqual(FormattingHelpers.nextSpeed(current: 2.0, speeds: speeds), 0.5)
    }

    func test_nextSpeed_unknownSpeed_returnDefault() {
        let speeds: [Float] = [0.5, 1.0, 2.0]
        XCTAssertEqual(FormattingHelpers.nextSpeed(current: 0.75, speeds: speeds), 1.0)
    }

    func test_nextSpeed_emptySpeedList_returnsDefault() {
        XCTAssertEqual(FormattingHelpers.nextSpeed(current: 1.0, speeds: []), 1.0)
    }

    func test_nextSpeed_singleSpeed_cyclesBack() {
        let speeds: [Float] = [1.0]
        XCTAssertEqual(FormattingHelpers.nextSpeed(current: 1.0, speeds: speeds), 1.0)
    }

    // MARK: - isSegmentHighlighted

    func test_isSegmentHighlighted_withinRange() {
        XCTAssertTrue(
            FormattingHelpers.isSegmentHighlighted(currentTime: 5.0, segmentStart: 3.0, segmentEnd: 8.0)
        )
    }

    func test_isSegmentHighlighted_atStart() {
        XCTAssertTrue(
            FormattingHelpers.isSegmentHighlighted(currentTime: 3.0, segmentStart: 3.0, segmentEnd: 8.0)
        )
    }

    func test_isSegmentHighlighted_atEnd_notHighlighted() {
        // endTime은 exclusive (< 사용)
        XCTAssertFalse(
            FormattingHelpers.isSegmentHighlighted(currentTime: 8.0, segmentStart: 3.0, segmentEnd: 8.0)
        )
    }

    func test_isSegmentHighlighted_beforeStart() {
        XCTAssertFalse(
            FormattingHelpers.isSegmentHighlighted(currentTime: 2.9, segmentStart: 3.0, segmentEnd: 8.0)
        )
    }

    func test_isSegmentHighlighted_afterEnd() {
        XCTAssertFalse(
            FormattingHelpers.isSegmentHighlighted(currentTime: 10.0, segmentStart: 3.0, segmentEnd: 8.0)
        )
    }

    func test_isSegmentHighlighted_zeroLengthSegment() {
        // start == end일 때 어떤 시간도 하이라이트되지 않아야 함
        XCTAssertFalse(
            FormattingHelpers.isSegmentHighlighted(currentTime: 5.0, segmentStart: 5.0, segmentEnd: 5.0)
        )
    }

    func test_isSegmentHighlighted_verySmallSegment() {
        XCTAssertTrue(
            FormattingHelpers.isSegmentHighlighted(currentTime: 1.0, segmentStart: 1.0, segmentEnd: 1.001)
        )
    }

    // MARK: - statusText

    func test_statusText_completed() {
        XCTAssertEqual(FormattingHelpers.statusText(for: .completed, progress: nil), "완료")
    }

    func test_statusText_pending() {
        XCTAssertEqual(FormattingHelpers.statusText(for: .pending, progress: nil), "대기")
    }

    func test_statusText_failed() {
        XCTAssertEqual(FormattingHelpers.statusText(for: .failed, progress: nil), "실패")
    }

    func test_statusText_inProgressWithNoProgress() {
        XCTAssertEqual(FormattingHelpers.statusText(for: .inProgress, progress: nil), "전사 중")
    }

    func test_statusText_inProgressWithZeroProgress() {
        XCTAssertEqual(FormattingHelpers.statusText(for: .inProgress, progress: 0), "전사 중")
    }

    func test_statusText_inProgressWithProgress() {
        XCTAssertEqual(FormattingHelpers.statusText(for: .inProgress, progress: 0.5), "전사 중 50%")
    }

    func test_statusText_inProgressWith100Percent() {
        XCTAssertEqual(FormattingHelpers.statusText(for: .inProgress, progress: 1.0), "전사 중 100%")
    }

    func test_statusText_inProgressWith75Percent() {
        XCTAssertEqual(FormattingHelpers.statusText(for: .inProgress, progress: 0.75), "전사 중 75%")
    }

    func test_statusText_nil() {
        XCTAssertEqual(FormattingHelpers.statusText(for: nil, progress: nil), "")
    }

    // MARK: - titleText

    func test_titleText_withNonEmptyText() {
        let result = FormattingHelpers.titleText(
            transcriptionText: "Hello world, this is a transcription",
            maxLength: 50,
            fallbackDate: Date()
        )
        XCTAssertEqual(result, "Hello world, this is a transcription")
    }

    func test_titleText_withLongText_isTruncated() {
        let longText = String(repeating: "a", count: 100)
        let result = FormattingHelpers.titleText(
            transcriptionText: longText,
            maxLength: 50,
            fallbackDate: Date()
        )
        XCTAssertEqual(result.count, 50)
    }

    func test_titleText_withNilText_returnsFormattedDate() {
        let date = Date(timeIntervalSince1970: 0)
        let result = FormattingHelpers.titleText(
            transcriptionText: nil,
            maxLength: 50,
            fallbackDate: date
        )
        XCTAssertFalse(result.isEmpty, "nil 텍스트일 때 날짜가 반환되어야 함")
    }

    func test_titleText_withEmptyText_returnsFormattedDate() {
        let date = Date(timeIntervalSince1970: 0)
        let result = FormattingHelpers.titleText(
            transcriptionText: "",
            maxLength: 50,
            fallbackDate: date
        )
        XCTAssertFalse(result.isEmpty, "빈 텍스트일 때 날짜가 반환되어야 함")
    }

    func test_titleText_withExactMaxLength() {
        let text = String(repeating: "x", count: 50)
        let result = FormattingHelpers.titleText(
            transcriptionText: text,
            maxLength: 50,
            fallbackDate: Date()
        )
        XCTAssertEqual(result.count, 50)
    }

    func test_titleText_withShortText_notTruncated() {
        let result = FormattingHelpers.titleText(
            transcriptionText: "short",
            maxLength: 50,
            fallbackDate: Date()
        )
        XCTAssertEqual(result, "short")
    }

    func test_titleText_differentMaxLengths() {
        let text = "Hello world"
        let result40 = FormattingHelpers.titleText(transcriptionText: text, maxLength: 40, fallbackDate: Date())
        let result60 = FormattingHelpers.titleText(transcriptionText: text, maxLength: 60, fallbackDate: Date())
        // 텍스트가 짧으므로 둘 다 동일
        XCTAssertEqual(result40, result60)

        let result5 = FormattingHelpers.titleText(transcriptionText: text, maxLength: 5, fallbackDate: Date())
        XCTAssertEqual(result5, "Hello")
    }

    // MARK: - groupByDate

    func test_groupByDate_emptyArray() {
        let result = FormattingHelpers.groupByDate(
            [Date](),
            dateExtractor: { $0 }
        )
        XCTAssertTrue(result.isEmpty)
    }

    func test_groupByDate_singleItem() {
        let date = Date()
        let result = FormattingHelpers.groupByDate([date], dateExtractor: { $0 })
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].value.count, 1)
    }

    func test_groupByDate_sameDay_groupedTogether() {
        let calendar = Calendar.current
        let today = Date()
        let laterToday = calendar.date(byAdding: .hour, value: 2, to: today)!

        let result = FormattingHelpers.groupByDate(
            [today, laterToday],
            dateExtractor: { $0 }
        )
        XCTAssertEqual(result.count, 1, "같은 날의 항목은 하나의 그룹으로 묶여야 함")
        XCTAssertEqual(result[0].value.count, 2)
    }

    func test_groupByDate_differentDays_separateGroups() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let result = FormattingHelpers.groupByDate(
            [today, yesterday],
            dateExtractor: { $0 }
        )
        XCTAssertEqual(result.count, 2, "다른 날의 항목은 별도 그룹이어야 함")
    }

    func test_groupByDate_sortedInReverseChronologicalOrder() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        // 의도적으로 섞인 순서로 입력
        let result = FormattingHelpers.groupByDate(
            [yesterday, twoDaysAgo, today],
            dateExtractor: { $0 }
        )
        XCTAssertEqual(result.count, 3)
        // 첫 번째 그룹이 가장 최근 날짜
        XCTAssertTrue(result[0].key > result[1].key)
        XCTAssertTrue(result[1].key > result[2].key)
    }

    func test_groupByDate_preservesItemsWithinGroup() {
        let calendar = Calendar.current
        // Use noon today to avoid midnight boundary issues
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let now = noon
        let oneHourAgo = calendar.date(byAdding: .hour, value: -1, to: noon)!
        let twoHoursAgo = calendar.date(byAdding: .hour, value: -2, to: noon)!

        struct Item {
            let date: Date
            let name: String
        }

        let items = [
            Item(date: now, name: "A"),
            Item(date: oneHourAgo, name: "B"),
            Item(date: twoHoursAgo, name: "C")
        ]

        let result = FormattingHelpers.groupByDate(items, dateExtractor: { $0.date })
        // 같은 날이면 하나의 그룹에 3개
        XCTAssertEqual(result[0].value.count, 3)
        let names = result[0].value.map(\.name)
        XCTAssertTrue(names.contains("A"))
        XCTAssertTrue(names.contains("B"))
        XCTAssertTrue(names.contains("C"))
    }

    // MARK: - safeFileExtension

    func test_safeFileExtension_emptyReturnsDefault() {
        XCTAssertEqual(FormattingHelpers.safeFileExtension(""), "m4a")
    }

    func test_safeFileExtension_nonEmptyReturnsOriginal() {
        XCTAssertEqual(FormattingHelpers.safeFileExtension("wav"), "wav")
    }

    func test_safeFileExtension_mp3() {
        XCTAssertEqual(FormattingHelpers.safeFileExtension("mp3"), "mp3")
    }

    func test_safeFileExtension_customDefault() {
        XCTAssertEqual(FormattingHelpers.safeFileExtension("", default: "wav"), "wav")
    }

    func test_safeFileExtension_nonEmptyIgnoresDefault() {
        XCTAssertEqual(FormattingHelpers.safeFileExtension("mp3", default: "wav"), "mp3")
    }

    func test_safeFileExtension_preservesCaseAsIs() {
        XCTAssertEqual(FormattingHelpers.safeFileExtension("M4A"), "M4A")
    }

    // MARK: - Negative / Edge Case Inputs

    func test_formatRecordingTime_negativeInput() {
        // 음수 입력이 크래시를 일으키지 않아야 함
        let result = FormattingHelpers.formatRecordingTime(-1)
        XCTAssertNotNil(result)
    }

    func test_formatPlaybackTime_negativeInput() {
        let result = FormattingHelpers.formatPlaybackTime(-1)
        XCTAssertNotNil(result)
    }

    func test_formatDurationWithHours_negativeInput() {
        let result = FormattingHelpers.formatDurationWithHours(-100)
        XCTAssertNotNil(result)
    }

    func test_formatDurationKorean_negativeInput() {
        let result = FormattingHelpers.formatDurationKorean(-100)
        XCTAssertNotNil(result)
    }

    func test_formatShortDuration_veryLargeValue() {
        // 매우 큰 값에서도 크래시 없이 동작
        let result = FormattingHelpers.formatShortDuration(100000)
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - formatRecordingTime vs formatPlaybackTime 차이 확인

    func test_recordingTimeVsPlaybackTime_zeroPadDifference() {
        // formatRecordingTime: "01:05" (분도 zero-padded)
        // formatPlaybackTime: "1:05" (분은 zero-pad 없음)
        XCTAssertEqual(FormattingHelpers.formatRecordingTime(65), "01:05")
        XCTAssertEqual(FormattingHelpers.formatPlaybackTime(65), "1:05")
    }

    func test_recordingTimeVsPlaybackTime_atZero() {
        XCTAssertEqual(FormattingHelpers.formatRecordingTime(0), "00:00")
        XCTAssertEqual(FormattingHelpers.formatPlaybackTime(0), "0:00")
    }
}
