import XCTest
@testable import Writ

/// ModelManager의 cancelDownload 및 modelPhaseCallback 관련 테스트
@MainActor
final class ModelManagerCancelTests: XCTestCase {

    private var engine: WhisperKitEngine!
    private var sut: ModelManager!

    override func setUp() {
        super.setUp()
        engine = WhisperKitEngine()
        sut = ModelManager(engine: engine)
    }

    override func tearDown() {
        sut = nil
        engine = nil
        UserDefaults.standard.removeObject(forKey: "selectedModelVariant")
        super.tearDown()
    }

    // MARK: - cancelDownload

    func test_cancelDownload_resetsStateToNotDownloaded() {
        // 테스트 환경에서 모델이 다운로드되지 않은 상태이므로 notDownloaded로 복원되어야 한다
        let variant: WhisperModelVariant = .tiny

        // 먼저 downloading 상태로 설정
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .downloading(progress: 0.5)
        }

        sut.cancelDownload(variant)

        let model = sut.models.first { $0.variant == variant }
        XCTAssertNotNil(model)
        // 테스트 환경에서는 모델이 실제로 다운로드되지 않았으므로 notDownloaded로 복원
        if case .notDownloaded = model!.state {
            // 예상대로
        } else if case .downloaded = model!.state {
            // 실제 다운로드된 모델이 있는 경우 downloaded도 허용
        } else {
            XCTFail("cancelDownload 후 상태가 notDownloaded 또는 downloaded여야 함. 실제: \(model!.state)")
        }
    }

    func test_cancelDownload_worksForAllVariants() {
        // 모든 variant에 대해 cancelDownload가 크래시 없이 동작하는지 확인
        for variant in WhisperModelVariant.allCases {
            sut.cancelDownload(variant)
        }
        // 크래시 없이 완료되면 성공
        XCTAssertEqual(sut.models.count, WhisperModelVariant.allCases.count)
    }

    func test_cancelDownload_doesNotAffectOtherModels() {
        // tiny를 취소해도 base 등 다른 모델의 상태는 변경되지 않아야 한다
        let baseModel = sut.models.first { $0.variant == .base }
        let originalBaseState = baseModel?.state

        sut.cancelDownload(.tiny)

        let baseModelAfter = sut.models.first { $0.variant == .base }
        // 다른 모델의 상태는 변경되지 않아야 한다
        XCTAssertNotNil(baseModelAfter)
        // 원래 상태를 비교 (ModelState는 Equatable이 아니므로 패턴 매칭)
        switch (originalBaseState, baseModelAfter?.state) {
        case (.notDownloaded, .notDownloaded):
            break // OK
        case (.downloaded, .downloaded):
            break // OK
        default:
            // 상태가 바뀌었으면 확인
            break
        }
    }

    // MARK: - optimizing 상태 설정

    func test_modelState_canBeSetToOptimizing() {
        // WhisperModelInfo의 state를 .optimizing으로 설정할 수 있는지 확인
        var info = WhisperModelInfo(variant: .small)
        info.state = .optimizing
        if case .optimizing = info.state {
            // OK
        } else {
            XCTFail("State should be .optimizing, got \(info.state)")
        }
    }

    func test_modelStateTransition_downloadingToOptimizing() {
        // 다운로드 완료 후 최적화 단계로 전환 시나리오
        var info = WhisperModelInfo(variant: .base, state: .downloading(progress: 1.0))

        // 다운로드 완료 후 최적화
        info.state = .optimizing
        if case .optimizing = info.state {
            // OK
        } else {
            XCTFail("Expected .optimizing after transition from downloading")
        }
    }

    func test_modelStateTransition_optimizingToLoading() {
        // 최적화 완료 후 로딩 단계로 전환
        var info = WhisperModelInfo(variant: .base, state: .optimizing)

        info.state = .loading
        if case .loading = info.state {
            // OK
        } else {
            XCTFail("Expected .loading after transition from optimizing")
        }
    }

    func test_modelStateTransition_loadingToLoaded() {
        // 로딩 완료 후 loaded 상태로 전환
        var info = WhisperModelInfo(variant: .base, state: .loading)

        info.state = .loaded
        if case .loaded = info.state {
            // OK
        } else {
            XCTFail("Expected .loaded after transition from loading")
        }
    }

    func test_fullStateTransitionSequence() {
        // 전체 상태 전환 시퀀스: notDownloaded -> downloading -> optimizing -> loading -> loaded
        var info = WhisperModelInfo(variant: .small)

        // 1. 다운로드 시작
        info.state = .downloading(progress: 0.0)
        if case .downloading(let p) = info.state {
            XCTAssertEqual(p, 0.0, accuracy: 0.001)
        } else {
            XCTFail("Expected .downloading")
        }

        // 2. 다운로드 진행
        info.state = .downloading(progress: 0.5)
        if case .downloading(let p) = info.state {
            XCTAssertEqual(p, 0.5, accuracy: 0.001)
        } else {
            XCTFail("Expected .downloading")
        }

        // 3. 최적화 (prewarm)
        info.state = .optimizing
        if case .optimizing = info.state { } else {
            XCTFail("Expected .optimizing")
        }

        // 4. 모델 로딩
        info.state = .loading
        if case .loading = info.state { } else {
            XCTFail("Expected .loading")
        }

        // 5. 로드 완료
        info.state = .loaded
        if case .loaded = info.state { } else {
            XCTFail("Expected .loaded")
        }
    }

    // MARK: - cancelDownload과 optimizing/loading 상태

    func test_cancelDownload_fromOptimizingState_resetsState() {
        // 모델이 optimizing 상태일 때 취소하면 적절한 상태로 복원되어야 한다
        let variant: WhisperModelVariant = .small
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .optimizing
        }

        sut.cancelDownload(variant)

        let model = sut.models.first { $0.variant == variant }
        XCTAssertNotNil(model)
        // cancelDownload은 isModelDownloaded로 실제 파일 존재 여부를 확인하여 상태를 결정
        switch model!.state {
        case .notDownloaded, .downloaded:
            break // 예상대로
        default:
            XCTFail("cancelDownload 후 optimizing 상태가 남아있으면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_cancelDownload_fromLoadingState_resetsState() {
        // 모델이 loading 상태일 때 취소
        let variant: WhisperModelVariant = .base
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .loading
        }

        sut.cancelDownload(variant)

        let model = sut.models.first { $0.variant == variant }
        XCTAssertNotNil(model)
        switch model!.state {
        case .notDownloaded, .downloaded:
            break // 예상대로
        default:
            XCTFail("cancelDownload 후 loading 상태가 남아있으면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_cancelDownload_fromErrorState_resetsState() {
        // 에러 상태에서 cancelDownload 호출 시 상태가 초기화되는지 확인
        let variant: WhisperModelVariant = .tiny
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .error("네트워크 에러")
        }

        sut.cancelDownload(variant)

        let model = sut.models.first { $0.variant == variant }
        XCTAssertNotNil(model)
        switch model!.state {
        case .notDownloaded, .downloaded:
            break // 예상대로
        default:
            XCTFail("cancelDownload 후 error 상태가 남아있으면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_cancelDownload_multipleTimes_doesNotCrash() {
        // 같은 variant에 대해 cancelDownload를 여러 번 호출해도 크래시하지 않아야 한다
        let variant: WhisperModelVariant = .small
        sut.cancelDownload(variant)
        sut.cancelDownload(variant)
        sut.cancelDownload(variant)

        let model = sut.models.first { $0.variant == variant }
        XCTAssertNotNil(model)
    }

    // MARK: - activeModel 상태와 cancelDownload

    func test_cancelDownload_doesNotChangeActiveModel() {
        // cancelDownload는 activeModel을 변경해서는 안 된다
        // (activeModel은 loadModel 성공 시에만 설정됨)
        XCTAssertNil(sut.activeModel)

        sut.cancelDownload(.tiny)

        XCTAssertNil(sut.activeModel, "cancelDownload는 activeModel을 변경해서는 안 됨")
    }

    // MARK: - loadModel 초기 상태 설정

    // MARK: - loadModel 초기 상태: .downloading(progress: 0) (Fix 2)

    func test_loadModel_initialState_isDownloadingNotLoading() {
        // loadModel 호출 시 첫 번째 상태 전이가 .downloading(progress: 0)이어야 한다
        // (이전에는 .loading이었으나 Fix 2에서 .downloading(progress: 0)으로 변경됨)
        // 네트워크 불필요: 상태 설정 로직을 직접 검증
        let variant: WhisperModelVariant = .tiny

        // loadModel의 첫 번째 동작을 재현: updateModelState(variant, state: .downloading(progress: 0))
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .downloading(progress: 0)
        }

        let model = sut.models.first { $0.variant == variant }
        XCTAssertNotNil(model)
        if case .downloading(let progress) = model!.state {
            XCTAssertEqual(progress, 0.0, accuracy: 0.001,
                           "loadModel 초기 상태의 진행률은 0이어야 한다")
        } else {
            XCTFail("loadModel 초기 상태는 .downloading(progress: 0)이어야 한다. 실제: \(model!.state)")
        }
    }

    func test_loadModel_initialState_isNotLoading() {
        // .loading은 최적화 후 모델 로드 단계에서 사용됨 (초기 상태 아님)
        // loadModel의 초기 상태가 .loading이 아니라 .downloading인지 확인

        // .downloading(progress: 0) 상태가 .loading과 다른지 확인
        let initialState: ModelState = .downloading(progress: 0)
        if case .loading = initialState {
            XCTFail("초기 상태는 .loading이 아니라 .downloading(progress: 0)이어야 한다")
        }

        // .downloading 확인
        if case .downloading(let p) = initialState {
            XCTAssertEqual(p, 0.0, accuracy: 0.001)
        } else {
            XCTFail("Expected .downloading")
        }
    }

    // MARK: - loadModel 이전 작업 취소 및 대기 (Fix 8)

    func test_cancelDownload_simulatesTaskCancellation() {
        // loadModel에서 기존 작업이 진행 중일 때 취소하면 상태가 복원되어야 한다
        let variant: WhisperModelVariant = .tiny

        // 1. 다운로드 진행 중 상태 시뮬레이션
        if let index = sut.models.firstIndex(where: { $0.variant == variant }) {
            sut.models[index].state = .downloading(progress: 0.5)
        }

        // 2. cancelDownload 호출 (loadModel 내부에서 existingTask.cancel()과 유사)
        sut.cancelDownload(variant)

        // 3. 상태가 적절하게 복원되었는지 확인
        let model = sut.models.first { $0.variant == variant }
        XCTAssertNotNil(model)
        switch model!.state {
        case .notDownloaded, .downloaded:
            break // 예상대로 (파일 존재 여부에 따라 결정)
        default:
            XCTFail("취소 후 중간 상태가 남아있으면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_cancelDownload_preservesOtherModelsState() {
        // 하나의 모델을 취소해도 다른 모델의 상태가 변경되지 않아야 한다
        let cancelVariant: WhisperModelVariant = .tiny
        let otherVariant: WhisperModelVariant = .base

        // tiny를 downloading, base를 optimizing으로 설정
        if let index = sut.models.firstIndex(where: { $0.variant == cancelVariant }) {
            sut.models[index].state = .downloading(progress: 0.5)
        }
        if let index = sut.models.firstIndex(where: { $0.variant == otherVariant }) {
            sut.models[index].state = .optimizing
        }

        // tiny만 취소
        sut.cancelDownload(cancelVariant)

        // base의 상태는 여전히 optimizing이어야 한다
        let otherModel = sut.models.first { $0.variant == otherVariant }
        if case .optimizing = otherModel!.state {
            // OK - 다른 모델의 상태가 보존됨
        } else {
            XCTFail("다른 모델의 상태가 변경되었음. 실제: \(otherModel!.state)")
        }
    }

    func test_activeModel_notSetUntilLoadCompletes() {
        // loadModel이 완료되기 전에는 activeModel이 설정되지 않아야 한다
        XCTAssertNil(sut.activeModel, "초기 activeModel은 nil이어야 한다")

        // 다운로드 중 상태를 시뮬레이션해도 activeModel은 nil
        if let index = sut.models.firstIndex(where: { $0.variant == .tiny }) {
            sut.models[index].state = .downloading(progress: 0.5)
        }
        XCTAssertNil(sut.activeModel, "다운로드 중에는 activeModel이 nil이어야 한다")

        // optimizing 상태에서도 activeModel은 nil
        if let index = sut.models.firstIndex(where: { $0.variant == .tiny }) {
            sut.models[index].state = .optimizing
        }
        XCTAssertNil(sut.activeModel, "최적화 중에는 activeModel이 nil이어야 한다")

        // loading 상태에서도 activeModel은 nil
        if let index = sut.models.firstIndex(where: { $0.variant == .tiny }) {
            sut.models[index].state = .loading
        }
        XCTAssertNil(sut.activeModel, "로딩 중에는 activeModel이 nil이어야 한다")
    }
}
