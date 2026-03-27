import XCTest
import SwiftUI
@testable import Writ

/// ModelRowView의 onCancel 파라미터 존재 확인 (컴파일 타임 검증)
final class ModelRowViewTests: XCTestCase {

    private func makeModelInfo(
        variant: WhisperModelVariant = .tiny,
        state: ModelState = .notDownloaded,
        isSupported: Bool = true,
        unsupportedReason: String? = nil
    ) -> ModelInfo {
        ModelInfo(
            identifier: variant.modelIdentifier,
            state: state,
            isSupported: isSupported,
            unsupportedReason: unsupportedReason
        )
    }

    // MARK: - onCancel 파라미터 존재 확인

    func test_modelRowView_canBeInstantiatedWithOnCancel() {
        let view = ModelRowView(
            model: makeModelInfo(),
            isActive: false,
            onSelect: {},
            onDelete: {},
            onCancel: {}
        )
        XCTAssertNotNil(view)
    }

    func test_modelRowView_withActiveModel() {
        let view = ModelRowView(
            model: makeModelInfo(variant: .small, state: .loaded),
            isActive: true,
            onSelect: {},
            onDelete: {},
            onCancel: {}
        )
        XCTAssertNotNil(view)
    }

    func test_modelRowView_withDownloadingState() {
        let view = ModelRowView(
            model: makeModelInfo(variant: .base, state: .downloading(progress: 0.5)),
            isActive: false,
            onSelect: {},
            onDelete: {},
            onCancel: {}
        )
        XCTAssertNotNil(view)
    }

    func test_modelRowView_withOptimizingState() {
        let view = ModelRowView(
            model: makeModelInfo(variant: .small, state: .optimizing),
            isActive: false,
            onSelect: {},
            onDelete: {},
            onCancel: {}
        )
        XCTAssertNotNil(view)
    }

    func test_modelRowView_withErrorState() {
        let view = ModelRowView(
            model: makeModelInfo(variant: .largeV3, state: .error("저장 공간이 부족합니다")),
            isActive: false,
            onSelect: {},
            onDelete: {},
            onCancel: {}
        )
        XCTAssertNotNil(view)
    }

    func test_modelRowView_withUnsupportedModel() {
        let view = ModelRowView(
            model: makeModelInfo(
                variant: .largeV3Turbo,
                isSupported: false,
                unsupportedReason: "이 기기에서는 메모리가 부족합니다"
            ),
            isActive: false,
            onSelect: {},
            onDelete: {},
            onCancel: {}
        )
        XCTAssertNotNil(view)
    }

    func test_modelRowView_allModelStates() {
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
            let view = ModelRowView(
                model: makeModelInfo(state: state),
                isActive: false,
                onSelect: {},
                onDelete: {},
                onCancel: {}
            )
            XCTAssertNotNil(view, "ModelRowView should be instantiable with state \(state)")
        }
    }
}
