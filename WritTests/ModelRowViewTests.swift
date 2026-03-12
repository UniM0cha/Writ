import XCTest
import SwiftUI
@testable import Writ

/// ModelRowView의 onCancel 파라미터 존재 확인 (컴파일 타임 검증)
final class ModelRowViewTests: XCTestCase {

    // MARK: - onCancel 파라미터 존재 확인

    func test_modelRowView_canBeInstantiatedWithOnCancel() {
        // ModelRowView가 onCancel 파라미터를 가지는지 컴파일 타임에 검증
        // 이 코드가 컴파일되면 onCancel 파라미터가 존재하는 것이 증명된다
        let model = WhisperModelInfo(variant: .tiny, state: .notDownloaded)
        let view = ModelRowView(
            model: model,
            isActive: false,
            onSelect: {},
            onDelete: {},
            onCancel: {}
        )
        XCTAssertNotNil(view)
    }

    func test_modelRowView_withActiveModel() {
        // isActive = true일 때도 정상 생성되는지 확인
        let model = WhisperModelInfo(variant: .small, state: .loaded)
        let view = ModelRowView(
            model: model,
            isActive: true,
            onSelect: {},
            onDelete: {},
            onCancel: {}
        )
        XCTAssertNotNil(view)
    }

    func test_modelRowView_withDownloadingState() {
        // downloading 상태에서 생성 — onCancel이 사용되는 상태
        let model = WhisperModelInfo(variant: .base, state: .downloading(progress: 0.5))
        let view = ModelRowView(
            model: model,
            isActive: false,
            onSelect: {},
            onDelete: {},
            onCancel: {}
        )
        XCTAssertNotNil(view)
    }

    func test_modelRowView_withOptimizingState() {
        // optimizing 상태에서 생성
        let model = WhisperModelInfo(variant: .small, state: .optimizing)
        let view = ModelRowView(
            model: model,
            isActive: false,
            onSelect: {},
            onDelete: {},
            onCancel: {}
        )
        XCTAssertNotNil(view)
    }

    func test_modelRowView_withErrorState() {
        let model = WhisperModelInfo(
            variant: .largeV3,
            state: .error("저장 공간이 부족합니다"),
            isSupported: true
        )
        let view = ModelRowView(
            model: model,
            isActive: false,
            onSelect: {},
            onDelete: {},
            onCancel: {}
        )
        XCTAssertNotNil(view)
    }

    func test_modelRowView_withUnsupportedModel() {
        let model = WhisperModelInfo(
            variant: .largeV3Turbo,
            state: .notDownloaded,
            isSupported: false,
            unsupportedReason: "이 기기에서는 메모리가 부족합니다"
        )
        let view = ModelRowView(
            model: model,
            isActive: false,
            onSelect: {},
            onDelete: {},
            onCancel: {}
        )
        XCTAssertNotNil(view)
    }

    func test_modelRowView_allModelStates() {
        // ModelRowView가 모든 ModelState에 대해 생성 가능한지 검증
        let states: [ModelState] = [
            .notDownloaded,
            .downloading(progress: 0.3),
            .downloaded,
            .optimizing,
            .loading,
            .loaded,
            .error("test error")
        ]

        for state in states {
            let model = WhisperModelInfo(variant: .tiny, state: state)
            let view = ModelRowView(
                model: model,
                isActive: false,
                onSelect: {},
                onDelete: {},
                onCancel: {}
            )
            XCTAssertNotNil(view, "ModelRowView should be instantiable with state \(state)")
        }
    }
}
