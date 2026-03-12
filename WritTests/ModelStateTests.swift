import XCTest
@testable import Writ

/// ModelState 열거형 테스트 — 특히 .optimizing 케이스 추가 후 Codable 라운드트립 검증
final class ModelStateTests: XCTestCase {

    // MARK: - 모든 케이스 존재 확인

    func test_allCasesExist() {
        // ModelState의 7가지 케이스가 모두 존재하는지 컴파일 타임 + 런타임 검증
        let states: [ModelState] = [
            .notDownloaded,
            .downloading(progress: 0.5),
            .downloaded,
            .optimizing,
            .loading,
            .loaded,
            .error("test")
        ]
        XCTAssertEqual(states.count, 7)
    }

    func test_switchExhaustiveness() {
        // switch 문이 모든 케이스를 커버하는지 검증 (컴파일 타임)
        let state: ModelState = .optimizing
        let label: String
        switch state {
        case .notDownloaded: label = "notDownloaded"
        case .downloading: label = "downloading"
        case .downloaded: label = "downloaded"
        case .optimizing: label = "optimizing"
        case .loading: label = "loading"
        case .loaded: label = "loaded"
        case .error: label = "error"
        }
        XCTAssertEqual(label, "optimizing")
    }

    // MARK: - Codable 라운드트립

    func test_codableRoundtrip_notDownloaded() throws {
        try assertCodableRoundtrip(.notDownloaded) { decoded in
            if case .notDownloaded = decoded { return true }
            return false
        }
    }

    func test_codableRoundtrip_downloading() throws {
        try assertCodableRoundtrip(.downloading(progress: 0.75)) { decoded in
            if case .downloading(let progress) = decoded {
                return abs(progress - 0.75) < 0.001
            }
            return false
        }
    }

    func test_codableRoundtrip_downloaded() throws {
        try assertCodableRoundtrip(.downloaded) { decoded in
            if case .downloaded = decoded { return true }
            return false
        }
    }

    func test_codableRoundtrip_optimizing() throws {
        // 새로 추가된 .optimizing 케이스의 Codable 라운드트립 검증
        try assertCodableRoundtrip(.optimizing) { decoded in
            if case .optimizing = decoded { return true }
            return false
        }
    }

    func test_codableRoundtrip_loading() throws {
        try assertCodableRoundtrip(.loading) { decoded in
            if case .loading = decoded { return true }
            return false
        }
    }

    func test_codableRoundtrip_loaded() throws {
        try assertCodableRoundtrip(.loaded) { decoded in
            if case .loaded = decoded { return true }
            return false
        }
    }

    func test_codableRoundtrip_error() throws {
        let message = "저장 공간이 부족합니다"
        try assertCodableRoundtrip(.error(message)) { decoded in
            if case .error(let msg) = decoded {
                return msg == message
            }
            return false
        }
    }

    func test_codableRoundtrip_errorWithEmptyMessage() throws {
        try assertCodableRoundtrip(.error("")) { decoded in
            if case .error(let msg) = decoded {
                return msg == ""
            }
            return false
        }
    }

    func test_codableRoundtrip_downloadingZeroProgress() throws {
        try assertCodableRoundtrip(.downloading(progress: 0.0)) { decoded in
            if case .downloading(let progress) = decoded {
                return abs(progress - 0.0) < 0.001
            }
            return false
        }
    }

    func test_codableRoundtrip_downloadingFullProgress() throws {
        try assertCodableRoundtrip(.downloading(progress: 1.0)) { decoded in
            if case .downloading(let progress) = decoded {
                return abs(progress - 1.0) < 0.001
            }
            return false
        }
    }

    // MARK: - Sendable

    func test_sendable_canBePassedAcrossConcurrencyBoundary() async {
        let state: ModelState = .optimizing
        let result = await Task.detached {
            return state
        }.value
        if case .optimizing = result {
            // OK
        } else {
            XCTFail("Expected .optimizing, got \(result)")
        }
    }

    func test_sendable_downloadingWithAssociatedValue() async {
        let state: ModelState = .downloading(progress: 0.33)
        let result = await Task.detached {
            return state
        }.value
        if case .downloading(let progress) = result {
            XCTAssertEqual(progress, 0.33, accuracy: 0.001)
        } else {
            XCTFail("Expected .downloading, got \(result)")
        }
    }

    // MARK: - JSON 안정성 (직렬화된 데이터의 역호환성)

    func test_encodedDataIsNotEmpty() throws {
        let states: [ModelState] = [
            .notDownloaded, .downloading(progress: 0.5), .downloaded,
            .optimizing, .loading, .loaded, .error("err")
        ]
        let encoder = JSONEncoder()
        for state in states {
            let data = try encoder.encode(state)
            XCTAssertGreaterThan(data.count, 0, "Encoded data for \(state) should not be empty")
        }
    }

    func test_differentStatesProduceDifferentJSON() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let optimizingData = try encoder.encode(ModelState.optimizing)
        let loadingData = try encoder.encode(ModelState.loading)
        let downloadedData = try encoder.encode(ModelState.downloaded)

        // .optimizing, .loading, .downloaded는 서로 다른 JSON을 생성해야 한다
        XCTAssertNotEqual(optimizingData, loadingData, ".optimizing과 .loading의 JSON이 동일함")
        XCTAssertNotEqual(optimizingData, downloadedData, ".optimizing과 .downloaded의 JSON이 동일함")
        XCTAssertNotEqual(loadingData, downloadedData, ".loading과 .downloaded의 JSON이 동일함")
    }

    // MARK: - Helper

    private func assertCodableRoundtrip(
        _ state: ModelState,
        file: StaticString = #file,
        line: UInt = #line,
        verify: (ModelState) -> Bool
    ) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ModelState.self, from: data)
        XCTAssertTrue(verify(decoded), "Codable roundtrip failed for \(state). Decoded: \(decoded)", file: file, line: line)
    }
}
