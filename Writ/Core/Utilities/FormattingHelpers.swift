import Foundation

/// View 전반에서 중복되던 포맷팅 로직을 통합한 유틸리티
enum FormattingHelpers {

    // MARK: - Time Formatting (MM:SS with zero-padded minutes)

    /// 녹음 타이머 표시용: "00:00" ~ "99:59" (분:초, 분도 zero-padded)
    static func formatRecordingTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 재생 시간 표시용: "0:00" ~ "99:59" (분:초, 분은 zero-pad 없음)
    static func formatPlaybackTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Duration Formatting

    /// 짧은 시간 표시: "0:00" (분:초), 시간 단위 미지원
    static func formatShortDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 시간 포함 표시: "1:02:03" 또는 "2:03" (시간이 0이면 분:초만)
    static func formatDurationWithHours(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 한국어 시간 표시: "1시간 2분" 또는 "2분 3초"
    static func formatDurationKorean(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d시간 %d분", hours, minutes)
        }
        return String(format: "%d분 %d초", minutes, seconds)
    }

    // MARK: - Section Date Formatting

    /// 날짜 그룹 섹션 헤더: "오늘", "어제", 또는 "M월 d일" 형식
    static func formatSectionDate(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return "오늘"
        } else if calendar.isDateInYesterday(date) {
            return "어제"
        } else {
            return date.formatted(.dateTime.month().day())
        }
    }

    // MARK: - Speed Label

    /// 재생 속도 라벨: "1.0x", "0.5x", "2.0x" 등
    static func speedLabel(for speed: Float) -> String {
        if speed == 1.0 { return "1.0x" }
        if speed.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(speed)).0x"
        }
        return String(format: "%.1fx", speed)
    }

    // MARK: - Speed Cycling

    /// 재생 속도 목록에서 다음 속도를 반환
    static func nextSpeed(current: Float, speeds: [Float]) -> Float {
        guard let currentIndex = speeds.firstIndex(of: current) else {
            return 1.0
        }
        let nextIndex = (currentIndex + 1) % speeds.count
        return speeds[nextIndex]
    }

    // MARK: - Segment Highlighting

    /// 현재 재생 시간이 세그먼트 시간 범위에 포함되는지 확인
    static func isSegmentHighlighted(
        currentTime: TimeInterval,
        segmentStart: TimeInterval,
        segmentEnd: TimeInterval
    ) -> Bool {
        currentTime >= segmentStart && currentTime < segmentEnd
    }

    // MARK: - Status Text (Sidebar)

    /// 전사 상태에 따른 표시 텍스트
    static func statusText(for status: TranscriptionStatus?, progress: Float?) -> String {
        switch status {
        case .completed:
            return "완료"
        case .inProgress:
            let p = progress ?? 0
            return p > 0 ? "전사 중 \(Int(p * 100))%" : "전사 중"
        case .pending:
            return "대기"
        case .failed:
            return "실패"
        case nil:
            return ""
        }
    }

    // MARK: - Title Text (Sidebar / Detail)

    /// 전사 텍스트에서 제목 추출 (없으면 날짜 문자열)
    static func titleText(
        transcriptionText: String?,
        maxLength: Int,
        fallbackDate: Date
    ) -> String {
        if let text = transcriptionText, !text.isEmpty {
            return String(text.prefix(maxLength))
        }
        return fallbackDate.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: - Date Grouping

    /// 녹음 배열을 날짜별로 그룹화하여 역순 정렬된 튜플 배열 반환
    static func groupByDate<T>(
        _ items: [T],
        dateExtractor: (T) -> Date,
        calendar: Calendar = .current
    ) -> [(key: Date, value: [T])] {
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: dateExtractor(item))
        }
        return grouped.sorted { $0.key > $1.key }
    }

    // MARK: - File Extension Safety

    /// 빈 확장자를 기본값으로 대체
    static func safeFileExtension(_ ext: String, default defaultExt: String = "m4a") -> String {
        ext.isEmpty ? defaultExt : ext
    }
}
