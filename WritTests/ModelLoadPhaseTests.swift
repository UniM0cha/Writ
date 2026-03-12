import XCTest
@testable import Writ

/// ModelLoadPhase 열거형 테스트 — 케이스 존재, switch 완전성, Sendable 검증
final class ModelLoadPhaseTests: XCTestCase {

    // MARK: - 케이스 존재 확인

    func test_optimizingCaseExists() {
        let phase: ModelLoadPhase = .optimizing
        if case .optimizing = phase {
            // OK
        } else {
            XCTFail("Expected .optimizing")
        }
    }

    func test_loadingCaseExists() {
        let phase: ModelLoadPhase = .loading
        if case .loading = phase {
            // OK
        } else {
            XCTFail("Expected .loading")
        }
    }

    // MARK: - Switch 완전성 (컴파일 타임 검증)

    func test_switchExhaustivenessReturnsCorrectLabel() {
        let phases: [ModelLoadPhase] = [.optimizing, .loading]

        for phase in phases {
            let label: String
            switch phase {
            case .optimizing: label = "optimizing"
            case .loading: label = "loading"
            }
            XCTAssertFalse(label.isEmpty, "Label should not be empty for \(phase)")
        }
    }

    func test_optimizingSwitchLabel() {
        let phase: ModelLoadPhase = .optimizing
        let label: String
        switch phase {
        case .optimizing: label = "optimizing"
        case .loading: label = "loading"
        }
        XCTAssertEqual(label, "optimizing")
    }

    func test_loadingSwitchLabel() {
        let phase: ModelLoadPhase = .loading
        let label: String
        switch phase {
        case .optimizing: label = "optimizing"
        case .loading: label = "loading"
        }
        XCTAssertEqual(label, "loading")
    }

    // MARK: - Sendable

    func test_sendable_canBeSentAcrossConcurrencyBoundary() async {
        let phase: ModelLoadPhase = .optimizing
        let result = await Task.detached {
            return phase
        }.value
        if case .optimizing = result {
            // OK
        } else {
            XCTFail("Expected .optimizing after crossing concurrency boundary")
        }
    }

    func test_sendable_loadingPhaseAcrossBoundary() async {
        let phase: ModelLoadPhase = .loading
        let result = await Task.detached {
            return phase
        }.value
        if case .loading = result {
            // OK
        } else {
            XCTFail("Expected .loading after crossing concurrency boundary")
        }
    }

    // MARK: - Callback 타입 호환성

    func test_canBeUsedInSendableClosure() async {
        // modelPhaseCallback은 @Sendable (ModelLoadPhase) -> Void 타입
        // ModelLoadPhase가 Sendable이면 이 클로저에 넘길 수 있어야 한다
        var received: ModelLoadPhase?
        let callback: @Sendable (ModelLoadPhase) -> Void = { phase in
            received = phase
        }

        callback(.optimizing)
        XCTAssertNotNil(received)
        if case .optimizing = received {
            // OK
        } else {
            XCTFail("Expected .optimizing in callback, got \(String(describing: received))")
        }

        callback(.loading)
        if case .loading = received {
            // OK
        } else {
            XCTFail("Expected .loading in callback, got \(String(describing: received))")
        }
    }
}
