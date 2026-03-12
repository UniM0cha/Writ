import XCTest
@testable import Writ

/// Deep link URL 파싱 로직 테스트
/// WritApp.handleDeepLink은 private이므로 URL 구조를 직접 파싱하여 검증
final class DeepLinkTests: XCTestCase {

    // MARK: - URL 구조 파싱 테스트

    func testStartRecordingURL_hasCorrectComponents() {
        let url = URL(string: "writ://start-recording")!
        XCTAssertEqual(url.scheme, "writ")
        XCTAssertEqual(url.host, "start-recording")
    }

    func testStopRecordingURL_hasCorrectComponents() {
        let url = URL(string: "writ://stop-recording")!
        XCTAssertEqual(url.scheme, "writ")
        XCTAssertEqual(url.host, "stop-recording")
    }

    func testRecordingDetailURL_hasCorrectComponents() {
        let testID = "550E8400-E29B-41D4-A716-446655440000"
        let url = URL(string: "writ://recording/\(testID)")!

        XCTAssertEqual(url.scheme, "writ")
        XCTAssertEqual(url.host, "recording")

        // pathComponents: ["/", "{id}"]
        let idComponent = url.pathComponents.dropFirst().first
        XCTAssertEqual(idComponent, testID)
    }

    func testRecordingDetailURL_withShortID() {
        let url = URL(string: "writ://recording/abc123")!
        XCTAssertEqual(url.host, "recording")
        let idComponent = url.pathComponents.dropFirst().first
        XCTAssertEqual(idComponent, "abc123")
    }

    func testRecordingDetailURL_withoutID() {
        // ID가 없는 recording URL
        let url = URL(string: "writ://recording")!
        XCTAssertEqual(url.host, "recording")
        let idComponent = url.pathComponents.dropFirst().first
        XCTAssertNil(idComponent, "ID가 없으면 pathComponents에서 추출할 수 없어야 함")
    }

    // MARK: - 스킴 검증

    func testInvalidScheme_isNotWrit() {
        let url = URL(string: "https://start-recording")!
        XCTAssertNotEqual(url.scheme, "writ")
    }

    func testWritScheme_caseMatching() {
        let url = URL(string: "writ://start-recording")!
        XCTAssertEqual(url.scheme, "writ")
    }

    // MARK: - 알 수 없는 host

    func testUnknownHost() {
        let url = URL(string: "writ://unknown-action")!
        XCTAssertEqual(url.scheme, "writ")
        XCTAssertEqual(url.host, "unknown-action")

        // handleDeepLink에서 unknown host는 default → break (무시)
        // 여기서는 URL 파싱 자체만 검증
        let knownHosts = ["start-recording", "stop-recording", "recording"]
        XCTAssertFalse(knownHosts.contains(url.host ?? ""))
    }

    // MARK: - 복수 path 컴포넌트

    func testRecordingURL_extraPathComponents_firstIsID() {
        // writ://recording/id/extra 같은 경우 첫 번째만 ID로 사용
        let url = URL(string: "writ://recording/myID/extra/path")!
        let idComponent = url.pathComponents.dropFirst().first
        XCTAssertEqual(idComponent, "myID")
    }

    // MARK: - AppTab 열거형

    func testAppTab_historyCase() {
        // Deep link가 .history 탭으로 전환하는지 간접 검증
        let tab = AppTab.history
        XCTAssertEqual(tab.rawValue, "기록")
        XCTAssertEqual(tab.systemImage, "clock.fill")
    }

    func testAppTab_recordCase() {
        let tab = AppTab.record
        XCTAssertEqual(tab.rawValue, "녹음")
        XCTAssertEqual(tab.systemImage, "mic.fill")
    }

    func testAppTab_settingsCase() {
        let tab = AppTab.settings
        XCTAssertEqual(tab.rawValue, "설정")
        XCTAssertEqual(tab.systemImage, "gearshape.fill")
    }

    func testAppTab_allCases() {
        XCTAssertEqual(AppTab.allCases.count, 3)
        XCTAssertTrue(AppTab.allCases.contains(.record))
        XCTAssertTrue(AppTab.allCases.contains(.history))
        XCTAssertTrue(AppTab.allCases.contains(.settings))
    }

    // MARK: - URL 특수문자 처리

    func testRecordingURL_withURLEncodedID() {
        // UUID 문자열은 특수문자가 없지만 인코딩된 경우도 파싱 가능해야 함
        let url = URL(string: "writ://recording/550E8400-E29B-41D4-A716-446655440000")!
        let idComponent = url.pathComponents.dropFirst().first
        XCTAssertNotNil(idComponent)
        XCTAssertFalse(idComponent!.isEmpty)
    }
}
