import XCTest
@testable import Writ

/// AppTab enum 분리 후 인터페이스 검증
/// AppTab이 독립 파일로 분리되었으므로 enum 정의, rawValue, systemImage 등을 검증한다.
@MainActor
final class AppTabTests: XCTestCase {

    // MARK: - Cases & RawValue

    func testAllCasesExist() {
        let record = AppTab.record
        let history = AppTab.history
        let settings = AppTab.settings

        XCTAssertEqual(record.rawValue, "녹음")
        XCTAssertEqual(history.rawValue, "기록")
        XCTAssertEqual(settings.rawValue, "설정")
    }

    func testCaseCount_isThree() {
        XCTAssertEqual(AppTab.allCases.count, 3, "AppTab은 정확히 3개 케이스가 있어야 함")
    }

    func testCaseIterable_containsAllCases() {
        let allCases = AppTab.allCases
        XCTAssertTrue(allCases.contains(.record))
        XCTAssertTrue(allCases.contains(.history))
        XCTAssertTrue(allCases.contains(.settings))
    }

    // MARK: - RawValue 초기화

    func testInitFromValidRawValue() {
        XCTAssertEqual(AppTab(rawValue: "녹음"), .record)
        XCTAssertEqual(AppTab(rawValue: "기록"), .history)
        XCTAssertEqual(AppTab(rawValue: "설정"), .settings)
    }

    func testInitFromInvalidRawValue() {
        XCTAssertNil(AppTab(rawValue: ""))
        XCTAssertNil(AppTab(rawValue: "unknown"))
        XCTAssertNil(AppTab(rawValue: "record")) // 영어 rawValue는 없음
        XCTAssertNil(AppTab(rawValue: "Record"))
        XCTAssertNil(AppTab(rawValue: "녹 음")) // 공백 포함
    }

    // MARK: - systemImage

    func testSystemImage_record() {
        XCTAssertEqual(AppTab.record.systemImage, "mic.fill")
    }

    func testSystemImage_history() {
        XCTAssertEqual(AppTab.history.systemImage, "clock.fill")
    }

    func testSystemImage_settings() {
        XCTAssertEqual(AppTab.settings.systemImage, "gearshape.fill")
    }

    func testSystemImage_allCasesHaveNonEmptyValues() {
        for tab in AppTab.allCases {
            XCTAssertFalse(tab.systemImage.isEmpty, "\(tab) systemImage가 비어있으면 안 됨")
        }
    }

    func testSystemImage_allCasesHaveUniqueValues() {
        let images = AppTab.allCases.map(\.systemImage)
        let uniqueImages = Set(images)
        XCTAssertEqual(
            uniqueImages.count, images.count,
            "모든 탭의 systemImage는 고유해야 함"
        )
    }

    // MARK: - Equatable

    func testEquatable_sameCases() {
        XCTAssertEqual(AppTab.record, AppTab.record)
        XCTAssertEqual(AppTab.history, AppTab.history)
        XCTAssertEqual(AppTab.settings, AppTab.settings)
    }

    func testEquatable_differentCases() {
        XCTAssertNotEqual(AppTab.record, AppTab.history)
        XCTAssertNotEqual(AppTab.record, AppTab.settings)
        XCTAssertNotEqual(AppTab.history, AppTab.settings)
    }

    // MARK: - Hashable

    func testHashable_canBeUsedAsSetElement() {
        let tabSet: Set<AppTab> = [.record, .history, .settings, .record]
        XCTAssertEqual(tabSet.count, 3, "Set에 중복 없이 3개만 저장되어야 함")
    }

    func testHashable_canBeUsedAsDictionaryKey() {
        var dict: [AppTab: String] = [:]
        dict[.record] = "녹음 화면"
        dict[.history] = "기록 화면"
        dict[.settings] = "설정 화면"

        XCTAssertEqual(dict[.record], "녹음 화면")
        XCTAssertEqual(dict[.history], "기록 화면")
        XCTAssertEqual(dict[.settings], "설정 화면")
    }
}
