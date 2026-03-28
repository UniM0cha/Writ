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
            if case .downloading(let progress, _) = decoded {
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
            if case .downloading(let progress, _) = decoded {
                return abs(progress - 0.0) < 0.001
            }
            return false
        }
    }

    func test_codableRoundtrip_downloadingFullProgress() throws {
        try assertCodableRoundtrip(.downloading(progress: 1.0)) { decoded in
            if case .downloading(let progress, _) = decoded {
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
        if case .downloading(let progress, _) = result {
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

    // MARK: - downloading + status 파라미터

    func test_downloading_withStatus_storesBothValues() {
        let state: ModelState = .downloading(progress: 0.5, status: "모델 다운로드 중")
        if case .downloading(let progress, let status) = state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.001)
            XCTAssertEqual(status, "모델 다운로드 중")
        } else {
            XCTFail("Expected .downloading, got \(state)")
        }
    }

    func test_downloading_withoutStatus_defaultsToNil() {
        let state: ModelState = .downloading(progress: 0.7)
        if case .downloading(let progress, let status) = state {
            XCTAssertEqual(progress, 0.7, accuracy: 0.001)
            XCTAssertNil(status, "status 생략 시 nil이어야 한다")
        } else {
            XCTFail("Expected .downloading, got \(state)")
        }
    }

    func test_downloading_withExplicitNilStatus() {
        let state: ModelState = .downloading(progress: 0.3, status: nil)
        if case .downloading(let progress, let status) = state {
            XCTAssertEqual(progress, 0.3, accuracy: 0.001)
            XCTAssertNil(status)
        } else {
            XCTFail("Expected .downloading, got \(state)")
        }
    }

    func test_downloading_withEmptyStatus() {
        let state: ModelState = .downloading(progress: 0.1, status: "")
        if case .downloading(let progress, let status) = state {
            XCTAssertEqual(progress, 0.1, accuracy: 0.001)
            XCTAssertEqual(status, "")
        } else {
            XCTFail("Expected .downloading, got \(state)")
        }
    }

    func test_downloading_statusVariousPhases() {
        // Qwen3-ASR 엔진에서 사용하는 실제 상태 문자열 검증
        let phases: [(Float, String)] = [
            (0.0, "모델 다운로드 중"),
            (0.35, "모델 로드 중"),
            (0.7, "Aligner 다운로드 중"),
            (0.85, "Aligner 로드 중"),
        ]
        for (progress, statusText) in phases {
            let state: ModelState = .downloading(progress: progress, status: statusText)
            if case .downloading(let p, let s) = state {
                XCTAssertEqual(p, progress, accuracy: 0.001)
                XCTAssertEqual(s, statusText)
            } else {
                XCTFail("Expected .downloading for phase '\(statusText)'")
            }
        }
    }

    func test_codableRoundtrip_downloadingWithStatus() throws {
        let statusText = "Aligner 다운로드 중"
        try assertCodableRoundtrip(.downloading(progress: 0.85, status: statusText)) { decoded in
            if case .downloading(let progress, let status) = decoded {
                return abs(progress - 0.85) < 0.001 && status == statusText
            }
            return false
        }
    }

    func test_codableRoundtrip_downloadingWithNilStatus() throws {
        try assertCodableRoundtrip(.downloading(progress: 0.5, status: nil)) { decoded in
            if case .downloading(let progress, let status) = decoded {
                return abs(progress - 0.5) < 0.001 && status == nil
            }
            return false
        }
    }

    func test_codableRoundtrip_downloadingWithEmptyStatus() throws {
        try assertCodableRoundtrip(.downloading(progress: 0.2, status: "")) { decoded in
            if case .downloading(let progress, let status) = decoded {
                return abs(progress - 0.2) < 0.001 && status == ""
            }
            return false
        }
    }

    func test_codableRoundtrip_downloadingWithKoreanStatus() throws {
        let koreanStatus = "모델 로드 중"
        try assertCodableRoundtrip(.downloading(progress: 0.6, status: koreanStatus)) { decoded in
            if case .downloading(let progress, let status) = decoded {
                return abs(progress - 0.6) < 0.001 && status == koreanStatus
            }
            return false
        }
    }

    func test_sendable_downloadingWithStatus() async {
        let state: ModelState = .downloading(progress: 0.7, status: "Aligner 다운로드 중")
        let result = await Task.detached {
            return state
        }.value
        if case .downloading(let progress, let status) = result {
            XCTAssertEqual(progress, 0.7, accuracy: 0.001)
            XCTAssertEqual(status, "Aligner 다운로드 중")
        } else {
            XCTFail("Expected .downloading, got \(result)")
        }
    }

    func test_differentStatusProduceDifferentJSON() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let withStatus = try encoder.encode(ModelState.downloading(progress: 0.5, status: "모델 다운로드 중"))
        let withNilStatus = try encoder.encode(ModelState.downloading(progress: 0.5))
        let withDifferentStatus = try encoder.encode(ModelState.downloading(progress: 0.5, status: "Aligner 로드 중"))

        // status가 다르면 JSON도 달라야 한다
        XCTAssertNotEqual(withStatus, withDifferentStatus,
                          "status가 다른 .downloading의 JSON이 동일하면 안 됨")
    }

    func test_patternMatching_withWildcard_ignoresStatus() {
        // status를 무시하고 progress만 추출하는 패턴 매칭
        let state: ModelState = .downloading(progress: 0.9, status: "모델 로드 중")
        if case .downloading(let progress, _) = state {
            XCTAssertEqual(progress, 0.9, accuracy: 0.001)
        } else {
            XCTFail("Expected .downloading")
        }
    }

    func test_patternMatching_noBindings_matchesDownloading() {
        // switch 문에서 바인딩 없이 매칭
        let state: ModelState = .downloading(progress: 0.5, status: "테스트")
        switch state {
        case .downloading:
            break // OK - 바인딩 없이도 매칭 가능
        default:
            XCTFail("Expected .downloading case to match")
        }
    }

    func test_downloading_progressBoundary_zeroWithStatus() {
        let state: ModelState = .downloading(progress: 0.0, status: "다운로드 시작")
        if case .downloading(let progress, let status) = state {
            XCTAssertEqual(progress, 0.0, accuracy: 0.001)
            XCTAssertEqual(status, "다운로드 시작")
        } else {
            XCTFail("Expected .downloading")
        }
    }

    func test_downloading_progressBoundary_oneWithStatus() {
        let state: ModelState = .downloading(progress: 1.0, status: "다운로드 완료")
        if case .downloading(let progress, let status) = state {
            XCTAssertEqual(progress, 1.0, accuracy: 0.001)
            XCTAssertEqual(status, "다운로드 완료")
        } else {
            XCTFail("Expected .downloading")
        }
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
