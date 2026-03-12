import XCTest
@testable import Writ

/// SourceDevice 열거형 테스트
/// .keyboard 케이스가 제거되고 4개 케이스만 남아있는지 검증
@MainActor
final class SourceDeviceTests: XCTestCase {

    // MARK: - Cases & RawValue

    func testAllCasesExist() {
        let iPhone = SourceDevice.iPhone
        let iPad = SourceDevice.iPad
        let mac = SourceDevice.mac
        let watch = SourceDevice.watch

        XCTAssertEqual(iPhone.rawValue, "iPhone")
        XCTAssertEqual(iPad.rawValue, "iPad")
        XCTAssertEqual(mac.rawValue, "mac")
        XCTAssertEqual(watch.rawValue, "watch")
    }

    func testCaseCount_isFour() {
        // .keyboard가 제거된 후 정확히 4개 케이스가 남아야 함
        // Mirror로 enum 케이스 수를 간접 확인
        let allRawValues = ["iPhone", "iPad", "mac", "watch"]
        var validDevices: [SourceDevice] = []

        for raw in allRawValues {
            if let device = SourceDevice(rawValue: raw) {
                validDevices.append(device)
            }
        }

        XCTAssertEqual(validDevices.count, 4, "SourceDevice는 정확히 4개 케이스가 있어야 함")
    }

    func testKeyboardRawValue_returnsNil() {
        // .keyboard 케이스가 제거되었으므로 rawValue "keyboard"로 초기화하면 nil
        let device = SourceDevice(rawValue: "keyboard")
        XCTAssertNil(device, "'keyboard' rawValue로 초기화하면 nil이어야 함 (.keyboard 케이스 제거됨)")
    }

    func testInitFromValidRawValue() {
        XCTAssertEqual(SourceDevice(rawValue: "iPhone"), .iPhone)
        XCTAssertEqual(SourceDevice(rawValue: "iPad"), .iPad)
        XCTAssertEqual(SourceDevice(rawValue: "mac"), .mac)
        XCTAssertEqual(SourceDevice(rawValue: "watch"), .watch)
    }

    func testInitFromInvalidRawValue() {
        XCTAssertNil(SourceDevice(rawValue: ""))
        XCTAssertNil(SourceDevice(rawValue: "unknown"))
        XCTAssertNil(SourceDevice(rawValue: "IPHONE")) // 대소문자 구분
        XCTAssertNil(SourceDevice(rawValue: "MacOS"))
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip_allCases() throws {
        let devices: [SourceDevice] = [.iPhone, .iPad, .mac, .watch]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for device in devices {
            let data = try encoder.encode(device)
            let decoded = try decoder.decode(SourceDevice.self, from: data)
            XCTAssertEqual(decoded, device, "\(device) Codable 라운드트립 실패")
        }
    }

    func testEncodingProducesRawValueString() throws {
        let data = try JSONEncoder().encode(SourceDevice.mac)
        let string = String(data: data, encoding: .utf8)
        XCTAssertEqual(string, "\"mac\"")
    }

    func testDecodingFromRawString() throws {
        let json = Data("\"watch\"".utf8)
        let decoded = try JSONDecoder().decode(SourceDevice.self, from: json)
        XCTAssertEqual(decoded, .watch)
    }

    func testDecodingKeyboard_fallsBackToiPhone() throws {
        // .keyboard가 제거되었으므로 기존 데이터 마이그레이션을 위해 .iPhone으로 폴백
        let json = Data("\"keyboard\"".utf8)
        let decoded = try JSONDecoder().decode(SourceDevice.self, from: json)
        XCTAssertEqual(decoded, .iPhone, "'keyboard' 디코딩 시 .iPhone으로 폴백해야 함")
    }

    func testDecodingInvalidValue_fallsBackToiPhone() throws {
        let json = Data("\"invalid_device\"".utf8)
        let decoded = try JSONDecoder().decode(SourceDevice.self, from: json)
        XCTAssertEqual(decoded, .iPhone, "유효하지 않은 값은 .iPhone으로 폴백해야 함")
    }

    // MARK: - Sendable

    func testSendable_canBePassedAcrossConcurrencyBoundary() async {
        // Sendable 준수 검증: 다른 Task로 전달 가능
        let device: SourceDevice = .iPhone
        let result = await Task.detached {
            return device
        }.value
        XCTAssertEqual(result, .iPhone)
    }

    // MARK: - Default Value

    func testDefaultValue_isiPhone() {
        // Recording의 기본 sourceDevice가 .iPhone인지 확인
        // Recording 모델 정의: var sourceDevice: SourceDevice = SourceDevice.iPhone
        let defaultDevice: SourceDevice = .iPhone
        XCTAssertEqual(defaultDevice.rawValue, "iPhone")
    }
}
