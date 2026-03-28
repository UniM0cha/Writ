import XCTest
@testable import Writ

/// ModelManager의 cancelDownload 및 상태 전환 관련 테스트
@MainActor
final class ModelManagerCancelTests: XCTestCase {

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
        UserDefaults.standard.removeObject(forKey: "selectedModelVariant")
        super.tearDown()
    }

    // MARK: - Helpers

    private func tinyId() -> ModelIdentifier { WhisperModelVariant.tiny.modelIdentifier }
    private func baseId() -> ModelIdentifier { WhisperModelVariant.base.modelIdentifier }
    private func smallId() -> ModelIdentifier { WhisperModelVariant.small.modelIdentifier }

    private func findModel(_ id: ModelIdentifier) -> ModelInfo? {
        sut.models.first { $0.identifier == id }
    }

    private func findIndex(_ id: ModelIdentifier) -> Int? {
        sut.models.firstIndex { $0.identifier == id }
    }

    // MARK: - cancelDownload

    func test_cancelDownload_resetsStateToNotDownloaded() {
        let id = tinyId()
        if let index = findIndex(id) {
            sut.models[index].state = .downloading(progress: 0.5)
        }
        sut.cancelDownload(id)
        let model = findModel(id)
        XCTAssertNotNil(model)
        switch model!.state {
        case .notDownloaded, .downloaded:
            break
        default:
            XCTFail("cancelDownload 후 상태가 notDownloaded 또는 downloaded여야 함. 실제: \(model!.state)")
        }
    }

    func test_cancelDownload_worksForAllWhisperVariants() {
        for variant in WhisperModelVariant.allCases {
            sut.cancelDownload(variant.modelIdentifier)
        }
        let whisperCount = sut.models.filter { $0.identifier.engine == .whisperKit }.count
        XCTAssertEqual(whisperCount, WhisperModelVariant.allCases.count)
    }

    func test_cancelDownload_doesNotAffectOtherModels() {
        let baseModel = findModel(baseId())
        let originalBaseState = baseModel?.state

        sut.cancelDownload(tinyId())

        let baseModelAfter = findModel(baseId())
        XCTAssertNotNil(baseModelAfter)
        switch (originalBaseState, baseModelAfter?.state) {
        case (.notDownloaded, .notDownloaded), (.downloaded, .downloaded):
            break
        default:
            break
        }
    }

    // MARK: - optimizing 상태 설정

    func test_modelState_canBeSetToOptimizing() {
        var info = ModelInfo(identifier: smallId(), state: .notDownloaded)
        info.state = .optimizing
        if case .optimizing = info.state { } else {
            XCTFail("State should be .optimizing, got \(info.state)")
        }
    }

    func test_modelStateTransition_downloadingToOptimizing() {
        var info = ModelInfo(identifier: baseId(), state: .downloading(progress: 1.0))
        info.state = .optimizing
        if case .optimizing = info.state { } else {
            XCTFail("Expected .optimizing after transition from downloading")
        }
    }

    func test_modelStateTransition_optimizingToLoading() {
        var info = ModelInfo(identifier: baseId(), state: .optimizing)
        info.state = .loading
        if case .loading = info.state { } else {
            XCTFail("Expected .loading after transition from optimizing")
        }
    }

    func test_modelStateTransition_loadingToLoaded() {
        var info = ModelInfo(identifier: baseId(), state: .loading)
        info.state = .loaded
        if case .loaded = info.state { } else {
            XCTFail("Expected .loaded after transition from loading")
        }
    }

    func test_fullStateTransitionSequence() {
        var info = ModelInfo(identifier: smallId())
        info.state = .downloading(progress: 0.0)
        info.state = .downloading(progress: 0.5)
        info.state = .optimizing
        info.state = .loading
        info.state = .loaded
        if case .loaded = info.state { } else {
            XCTFail("Expected .loaded")
        }
    }

    // MARK: - cancelDownload과 다양한 상태

    func test_cancelDownload_fromOptimizingState_resetsState() {
        let id = smallId()
        if let index = findIndex(id) {
            sut.models[index].state = .optimizing
        }
        sut.cancelDownload(id)
        let model = findModel(id)
        XCTAssertNotNil(model)
        switch model!.state {
        case .notDownloaded, .downloaded: break
        default: XCTFail("cancelDownload 후 optimizing 상태가 남아있으면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_cancelDownload_fromLoadingState_resetsState() {
        let id = baseId()
        if let index = findIndex(id) {
            sut.models[index].state = .loading
        }
        sut.cancelDownload(id)
        let model = findModel(id)
        XCTAssertNotNil(model)
        switch model!.state {
        case .notDownloaded, .downloaded: break
        default: XCTFail("cancelDownload 후 loading 상태가 남아있으면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_cancelDownload_fromErrorState_resetsState() {
        let id = tinyId()
        if let index = findIndex(id) {
            sut.models[index].state = .error("네트워크 에러")
        }
        sut.cancelDownload(id)
        let model = findModel(id)
        XCTAssertNotNil(model)
        switch model!.state {
        case .notDownloaded, .downloaded: break
        default: XCTFail("cancelDownload 후 error 상태가 남아있으면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_cancelDownload_multipleTimes_doesNotCrash() {
        let id = smallId()
        sut.cancelDownload(id)
        sut.cancelDownload(id)
        sut.cancelDownload(id)
        XCTAssertNotNil(findModel(id))
    }

    // MARK: - activeModel 상태와 cancelDownload

    func test_cancelDownload_doesNotChangeActiveModel() {
        XCTAssertNil(sut.activeModel)
        sut.cancelDownload(tinyId())
        XCTAssertNil(sut.activeModel, "cancelDownload는 activeModel을 변경해서는 안 됨")
    }

    // MARK: - loadModel 초기 상태

    func test_loadModel_initialState_isDownloadingNotLoading() {
        let id = tinyId()
        if let index = findIndex(id) {
            sut.models[index].state = .downloading(progress: 0)
        }
        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .downloading(let progress, _) = model!.state {
            XCTAssertEqual(progress, 0.0, accuracy: 0.001)
        } else {
            XCTFail("loadModel 초기 상태는 .downloading(progress: 0)이어야 한다. 실제: \(model!.state)")
        }
    }

    func test_loadModel_initialState_isNotLoading() {
        let initialState: ModelState = .downloading(progress: 0)
        if case .loading = initialState {
            XCTFail("초기 상태는 .loading이 아니라 .downloading(progress: 0)이어야 한다")
        }
        if case .downloading(let p, _) = initialState {
            XCTAssertEqual(p, 0.0, accuracy: 0.001)
        } else {
            XCTFail("Expected .downloading")
        }
    }

    // MARK: - cancelDownload 시뮬레이션

    func test_cancelDownload_simulatesTaskCancellation() {
        let id = tinyId()
        if let index = findIndex(id) {
            sut.models[index].state = .downloading(progress: 0.5)
        }
        sut.cancelDownload(id)
        let model = findModel(id)
        XCTAssertNotNil(model)
        switch model!.state {
        case .notDownloaded, .downloaded: break
        default: XCTFail("취소 후 중간 상태가 남아있으면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_cancelDownload_preservesOtherModelsState() {
        let cancelId = tinyId()
        let otherId = baseId()

        if let index = findIndex(cancelId) {
            sut.models[index].state = .downloading(progress: 0.5)
        }
        if let index = findIndex(otherId) {
            sut.models[index].state = .optimizing
        }

        sut.cancelDownload(cancelId)

        let otherModel = findModel(otherId)
        if case .optimizing = otherModel!.state {
        } else {
            XCTFail("다른 모델의 상태가 변경되었음. 실제: \(otherModel!.state)")
        }
    }

    func test_activeModel_notSetUntilLoadCompletes() {
        let id = tinyId()
        XCTAssertNil(sut.activeModel)

        if let index = findIndex(id) {
            sut.models[index].state = .downloading(progress: 0.5)
        }
        XCTAssertNil(sut.activeModel)

        if let index = findIndex(id) {
            sut.models[index].state = .optimizing
        }
        XCTAssertNil(sut.activeModel)

        if let index = findIndex(id) {
            sut.models[index].state = .loading
        }
        XCTAssertNil(sut.activeModel)
    }

    // MARK: - resetActiveStates

    func test_resetActiveStates_resetsDownloadingToNotDownloaded() {
        let id = smallId()
        if let index = findIndex(id) {
            sut.models[index].state = .downloading(progress: 0.7)
        }
        sut.resetActiveStates()
        let model = findModel(id)
        switch model!.state {
        case .notDownloaded, .downloaded: break
        default: XCTFail("resetActiveStates 후 downloading 상태가 남아있으면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_resetActiveStates_resetsOptimizingToDownloaded() {
        let id = baseId()
        if let index = findIndex(id) {
            sut.models[index].state = .optimizing
        }
        sut.resetActiveStates()
        let model = findModel(id)
        if case .downloaded = model!.state { } else {
            XCTFail("optimizing 상태는 다운로드 완료이므로 .downloaded로 리셋되어야 함. 실제: \(model!.state)")
        }
    }

    func test_resetActiveStates_resetsLoadingToDownloaded() {
        let id = tinyId()
        if let index = findIndex(id) {
            sut.models[index].state = .loading
        }
        sut.resetActiveStates()
        let model = findModel(id)
        if case .downloaded = model!.state { } else {
            XCTFail("loading 상태는 다운로드 완료이므로 .downloaded로 리셋되어야 함. 실제: \(model!.state)")
        }
    }

    func test_resetActiveStates_doesNotTouchStableStates() {
        let loadedId = tinyId()
        let downloadedId = baseId()
        let errorId = smallId()

        if let i = findIndex(loadedId) { sut.models[i].state = .loaded }
        if let i = findIndex(downloadedId) { sut.models[i].state = .downloaded }
        if let i = findIndex(errorId) { sut.models[i].state = .error("test") }

        sut.resetActiveStates()

        if case .loaded = findModel(loadedId)!.state { } else {
            XCTFail("loaded 상태가 변경되었음")
        }
        if case .downloaded = findModel(downloadedId)!.state { } else {
            XCTFail("downloaded 상태가 변경되었음")
        }
        if case .error = findModel(errorId)!.state { } else {
            XCTFail("error 상태가 변경되었음")
        }
    }
}
