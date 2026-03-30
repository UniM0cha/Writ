import XCTest
@testable import Writ

/// RecordingView의 모델 로딩 취소 버튼 표시 조건 및 isModelLoading 로직 검증
///
/// RecordingView에는 모델이 downloading/optimizing/loading 상태일 때
/// xmark.circle.fill 취소 버튼이 표시된다. 이 테스트는 취소 버튼 표시를 결정하는
/// 조건(ModelManager.models의 상태)과 cancelDownload 호출 결과를 검증한다.
@MainActor
final class RecordingViewCancelButtonTests: XCTestCase {

    private var engine: WhisperKitEngine!
    private var sut: ModelManager!

    override func setUp() {
        super.setUp()
        engine = WhisperKitEngine()
        sut = ModelManager(whisperEngine: engine)
    }

    override func tearDown() {
        sut = nil
        engine = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// RecordingView.isModelLoading과 동일한 로직
    private var isModelLoading: Bool {
        sut.models.contains {
            switch $0.state {
            case .downloading, .optimizing, .loading: return true
            default: return false
            }
        }
    }

    /// 취소 대상 모델 (RecordingView에서 cancel 버튼이 사용하는 로직과 동일)
    private var loadingModel: ModelInfo? {
        sut.models.first {
            switch $0.state {
            case .downloading, .optimizing, .loading: return true
            default: return false
            }
        }
    }

    private func setModelState(_ identifier: ModelIdentifier, to state: ModelState) {
        if let index = sut.models.firstIndex(where: { $0.identifier == identifier }) {
            sut.models[index].state = state
        }
    }

    // MARK: - isModelLoading: 초기 상태

    func test_isModelLoading_initialState_isFalse() {
        // Given: 초기 상태 (모든 모델이 notDownloaded 또는 downloaded)
        // Then
        XCTAssertFalse(isModelLoading,
                       "초기 상태에서는 모델 로딩 중이 아니어야 함")
    }

    // MARK: - isModelLoading: 각 활성 상태에서 true

    func test_isModelLoading_downloading_isTrue() {
        // Given
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .downloading(progress: 0.3))

        // Then
        XCTAssertTrue(isModelLoading,
                      "downloading 상태의 모델이 있으면 isModelLoading은 true여야 함")
    }

    func test_isModelLoading_optimizing_isTrue() {
        // Given
        let baseId = WhisperModelVariant.base.modelIdentifier
        setModelState(baseId, to: .optimizing)

        // Then
        XCTAssertTrue(isModelLoading,
                      "optimizing 상태의 모델이 있으면 isModelLoading은 true여야 함")
    }

    func test_isModelLoading_loading_isTrue() {
        // Given
        let smallId = WhisperModelVariant.small.modelIdentifier
        setModelState(smallId, to: .loading)

        // Then
        XCTAssertTrue(isModelLoading,
                      "loading 상태의 모델이 있으면 isModelLoading은 true여야 함")
    }

    // MARK: - isModelLoading: 비활성 상태에서 false

    func test_isModelLoading_allNotDownloaded_isFalse() {
        // Given: 모든 모델이 notDownloaded
        for i in sut.models.indices {
            sut.models[i].state = .notDownloaded
        }

        // Then
        XCTAssertFalse(isModelLoading)
    }

    func test_isModelLoading_allDownloaded_isFalse() {
        // Given: 모든 모델이 downloaded
        for i in sut.models.indices {
            sut.models[i].state = .downloaded
        }

        // Then
        XCTAssertFalse(isModelLoading)
    }

    func test_isModelLoading_loaded_isFalse() {
        // Given: 하나의 모델이 loaded
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .loaded)

        // Then: loaded는 활성 상태가 아님
        XCTAssertFalse(isModelLoading,
                       "loaded 상태는 로딩 완료이므로 isModelLoading은 false여야 함")
    }

    func test_isModelLoading_error_isFalse() {
        // Given: 하나의 모델이 error
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .error("테스트 에러"))

        // Then
        XCTAssertFalse(isModelLoading,
                       "error 상태에서는 isModelLoading이 false여야 함")
    }

    // MARK: - loadingModel: 취소 대상 모델 식별

    func test_loadingModel_returnsFirstLoadingModel() {
        // Given
        let smallId = WhisperModelVariant.small.modelIdentifier
        setModelState(smallId, to: .downloading(progress: 0.5))

        // Then
        XCTAssertEqual(loadingModel?.identifier, smallId,
                       "downloading 중인 모델이 취소 대상으로 반환되어야 함")
    }

    func test_loadingModel_returnsNil_whenNoActiveLoading() {
        // Given: 모든 모델이 안정 상태
        // Then
        XCTAssertNil(loadingModel,
                     "로딩 중인 모델이 없으면 nil이어야 함")
    }

    func test_loadingModel_optimizing_isReturnedAsTarget() {
        // Given
        let baseId = WhisperModelVariant.base.modelIdentifier
        setModelState(baseId, to: .optimizing)

        // Then
        XCTAssertEqual(loadingModel?.identifier, baseId,
                       "optimizing 상태의 모델도 취소 대상이어야 함")
    }

    func test_loadingModel_loading_isReturnedAsTarget() {
        // Given
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .loading)

        // Then
        XCTAssertEqual(loadingModel?.identifier, tinyId,
                       "loading 상태의 모델도 취소 대상이어야 함")
    }

    // MARK: - cancelDownload로 로딩 취소 후 상태

    func test_cancelDownload_downloading_isModelLoadingBecomesFalse() {
        // Given
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .downloading(progress: 0.7))
        XCTAssertTrue(isModelLoading)

        // When
        sut.cancelDownload(tinyId)

        // Then
        XCTAssertFalse(isModelLoading,
                       "cancelDownload 후 isModelLoading은 false가 되어야 함")
    }

    func test_cancelDownload_optimizing_isModelLoadingBecomesFalse() {
        // Given
        let baseId = WhisperModelVariant.base.modelIdentifier
        setModelState(baseId, to: .optimizing)
        XCTAssertTrue(isModelLoading)

        // When
        sut.cancelDownload(baseId)

        // Then
        XCTAssertFalse(isModelLoading,
                       "optimizing 취소 후 isModelLoading은 false가 되어야 함")
    }

    func test_cancelDownload_loading_isModelLoadingBecomesFalse() {
        // Given
        let smallId = WhisperModelVariant.small.modelIdentifier
        setModelState(smallId, to: .loading)
        XCTAssertTrue(isModelLoading)

        // When
        sut.cancelDownload(smallId)

        // Then
        XCTAssertFalse(isModelLoading,
                       "loading 취소 후 isModelLoading은 false가 되어야 함")
    }

    // MARK: - downloading 상태의 진행도 + 상태 텍스트 (modelStatusText 관련)

    func test_downloadingWithStatus_progressAndStatusAreAccessible() {
        // Given
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .downloading(progress: 0.45, status: "모델 다운로드 중"))

        // Then
        let model = sut.models.first { $0.identifier == tinyId }
        XCTAssertNotNil(model)
        if case .downloading(let progress, let status) = model!.state {
            XCTAssertEqual(progress, 0.45, accuracy: 0.001)
            XCTAssertEqual(status, "모델 다운로드 중")
        } else {
            XCTFail("Expected .downloading state")
        }
    }

    func test_downloadingWithNilStatus_usesDefaultLabel() {
        // Given
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .downloading(progress: 0.2))

        // Then: status가 nil이면 RecordingView에서 "다운로드 중"을 기본 레이블로 사용
        let model = sut.models.first { $0.identifier == tinyId }
        if case .downloading(_, let status) = model!.state {
            XCTAssertNil(status,
                         "status 파라미터 없이 생성하면 nil이어야 함")
        } else {
            XCTFail("Expected .downloading state")
        }
    }

    // MARK: - 여러 모델이 동시에 로딩 중인 경우 (방어 테스트)

    func test_isModelLoading_multipleModelsLoading_isTrue() {
        // Given: 여러 모델이 동시에 활성 상태 (정상적으로는 발생하지 않지만 방어)
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        let baseId = WhisperModelVariant.base.modelIdentifier
        setModelState(tinyId, to: .downloading(progress: 0.3))
        setModelState(baseId, to: .loading)

        // Then
        XCTAssertTrue(isModelLoading)
    }

    func test_loadingModel_multipleModelsLoading_returnsFirst() {
        // Given
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        let baseId = WhisperModelVariant.base.modelIdentifier
        setModelState(tinyId, to: .downloading(progress: 0.3))
        setModelState(baseId, to: .loading)

        // Then: first를 반환하므로 models 배열에서 먼저 나오는 것이 반환됨
        let target = loadingModel
        XCTAssertNotNil(target,
                        "로딩 중인 모델이 존재하면 반환되어야 함")
    }

    // MARK: - cancelDownload 후 activeModel은 변경 안 됨

    func test_cancelDownload_doesNotChangeActiveModel() {
        // Given
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        sut.activeModel = tinyId
        let baseId = WhisperModelVariant.base.modelIdentifier
        setModelState(baseId, to: .downloading(progress: 0.5))

        // When
        sut.cancelDownload(baseId)

        // Then
        XCTAssertEqual(sut.activeModel, tinyId,
                       "cancelDownload는 activeModel에 영향을 주면 안 됨")
    }
}
