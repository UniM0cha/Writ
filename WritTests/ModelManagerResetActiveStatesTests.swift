import XCTest
@testable import Writ

/// resetActiveStates() 메서드 테스트 — 다운로드 취소 시 모든 활성 상태 모델을 올바르게 리셋하는지 검증
@MainActor
final class ModelManagerResetActiveStatesTests: XCTestCase {

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
        UserDefaults.standard.removeObject(forKey: "selectedEngineType")
        super.tearDown()
    }

    // MARK: - Helpers

    private func tinyId() -> ModelIdentifier { WhisperModelVariant.tiny.modelIdentifier }
    private func baseId() -> ModelIdentifier { WhisperModelVariant.base.modelIdentifier }
    private func smallId() -> ModelIdentifier { WhisperModelVariant.small.modelIdentifier }
    private func largeV3Id() -> ModelIdentifier { WhisperModelVariant.largeV3.modelIdentifier }

    private func findModel(_ id: ModelIdentifier) -> ModelInfo? {
        sut.models.first { $0.identifier == id }
    }

    private func findIndex(_ id: ModelIdentifier) -> Int? {
        sut.models.firstIndex { $0.identifier == id }
    }

    private func setState(_ id: ModelIdentifier, to state: ModelState) {
        if let index = findIndex(id) {
            sut.models[index].state = state
        }
    }

    // MARK: - resetActiveStates: downloading 상태 리셋

    func test_resetActiveStates_resetsDownloadingToNotDownloaded_whenModelNotOnDisk() {
        // Given: 디스크에 없는 모델이 downloading 상태
        let id = tinyId()
        let isOnDisk = ModelManager.isWhisperModelDownloaded(.tiny)
        guard !isOnDisk else {
            // tiny 모델이 실제 디스크에 있으면 이 테스트는 skip
            return
        }
        setState(id, to: .downloading(progress: 0.5))

        // When
        sut.resetActiveStates()

        // Then
        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .notDownloaded = model!.state {
            // OK
        } else {
            XCTFail("디스크에 없는 모델의 downloading 상태는 notDownloaded로 리셋되어야 함. 실제: \(model!.state)")
        }
    }

    func test_resetActiveStates_resetsDownloadingToDownloaded_whenWhisperModelOnDisk() {
        // Given: 디스크에 있는 WhisperKit 모델이 downloading 상태
        // 실제 다운로드된 모델을 찾아서 테스트
        for variant in WhisperModelVariant.allCases {
            guard ModelManager.isWhisperModelDownloaded(variant) else { continue }
            let id = variant.modelIdentifier
            setState(id, to: .downloading(progress: 0.7))

            // When
            sut.resetActiveStates()

            // Then
            let model = findModel(id)
            XCTAssertNotNil(model)
            if case .downloaded = model!.state {
                // OK
            } else {
                XCTFail("디스크에 있는 모델의 downloading 상태는 downloaded로 리셋되어야 함. 실제: \(model!.state)")
            }
            return // 하나만 테스트하면 충분
        }
        // 다운로드된 모델이 없으면 테스트 통과 (환경 의존)
    }

    func test_resetActiveStates_resetsDownloadingWithZeroProgress() {
        let id = baseId()
        guard !ModelManager.isWhisperModelDownloaded(.base) else { return }
        setState(id, to: .downloading(progress: 0.0))

        sut.resetActiveStates()

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .notDownloaded = model!.state {
            // OK
        } else {
            XCTFail("downloading(progress: 0.0) 상태도 리셋되어야 함. 실제: \(model!.state)")
        }
    }

    func test_resetActiveStates_resetsDownloadingWithFullProgress() {
        let id = smallId()
        guard !ModelManager.isWhisperModelDownloaded(.small) else { return }
        setState(id, to: .downloading(progress: 1.0))

        sut.resetActiveStates()

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .notDownloaded = model!.state {
            // OK
        } else {
            XCTFail("downloading(progress: 1.0) 상태도 리셋되어야 함. 실제: \(model!.state)")
        }
    }

    // MARK: - resetActiveStates: optimizing / loading 상태 리셋

    func test_resetActiveStates_resetsOptimizingToDownloaded() {
        // optimizing 단계에 진입했다는 것은 다운로드가 완료되었다는 의미
        let id = tinyId()
        setState(id, to: .optimizing)

        sut.resetActiveStates()

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .downloaded = model!.state {
            // OK - optimizing은 다운로드 완료 후 단계이므로 downloaded로 리셋
        } else {
            XCTFail("optimizing 상태는 downloaded로 리셋되어야 함. 실제: \(model!.state)")
        }
    }

    func test_resetActiveStates_resetsLoadingToDownloaded() {
        // loading 단계에 진입했다는 것은 다운로드가 완료되었다는 의미
        let id = baseId()
        setState(id, to: .loading)

        sut.resetActiveStates()

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .downloaded = model!.state {
            // OK - loading은 다운로드 완료 후 단계이므로 downloaded로 리셋
        } else {
            XCTFail("loading 상태는 downloaded로 리셋되어야 함. 실제: \(model!.state)")
        }
    }

    // MARK: - resetActiveStates: 안정 상태는 변경하지 않음

    func test_resetActiveStates_doesNotTouchLoadedState() {
        let id = tinyId()
        setState(id, to: .loaded)

        sut.resetActiveStates()

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .loaded = model!.state {
            // OK
        } else {
            XCTFail("loaded 상태는 resetActiveStates에 의해 변경되면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_resetActiveStates_doesNotTouchDownloadedState() {
        let id = smallId()
        setState(id, to: .downloaded)

        sut.resetActiveStates()

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .downloaded = model!.state {
            // OK
        } else {
            XCTFail("downloaded 상태는 resetActiveStates에 의해 변경되면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_resetActiveStates_doesNotTouchNotDownloadedState() {
        let id = largeV3Id()
        setState(id, to: .notDownloaded)

        sut.resetActiveStates()

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .notDownloaded = model!.state {
            // OK
        } else {
            XCTFail("notDownloaded 상태는 resetActiveStates에 의해 변경되면 안 됨. 실제: \(model!.state)")
        }
    }

    func test_resetActiveStates_doesNotTouchErrorState() {
        let id = tinyId()
        let errorMessage = "네트워크 에러"
        setState(id, to: .error(errorMessage))

        sut.resetActiveStates()

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .error(let msg) = model!.state {
            XCTAssertEqual(msg, errorMessage, "error 상태의 메시지가 보존되어야 함")
        } else {
            XCTFail("error 상태는 resetActiveStates에 의해 변경되면 안 됨. 실제: \(model!.state)")
        }
    }

    // MARK: - resetActiveStates: 여러 모델이 동시에 활성 상태인 경우 (핵심 버그 시나리오)

    func test_resetActiveStates_resetsMultipleActiveModels() {
        // Given: 모델 A는 downloading, 모델 B는 optimizing, 모델 C는 loading
        setState(tinyId(), to: .downloading(progress: 0.3))
        setState(baseId(), to: .optimizing)
        setState(smallId(), to: .loading)

        // When
        sut.resetActiveStates()

        // Then: downloading은 디스크 확인 후 리셋, optimizing/loading은 downloaded로 리셋
        let tinyModel = findModel(tinyId())
        XCTAssertNotNil(tinyModel)
        switch tinyModel!.state {
        case .notDownloaded, .downloaded:
            break // OK - 디스크 존재 여부에 따라 결정
        default:
            XCTFail("downloading 상태가 리셋되지 않음. 상태: \(tinyModel!.state)")
        }

        // optimizing/loading은 다운로드 완료 후 단계이므로 항상 downloaded
        let baseModel = findModel(baseId())
        XCTAssertNotNil(baseModel)
        if case .downloaded = baseModel!.state { } else {
            XCTFail("optimizing 상태가 downloaded로 리셋되지 않음. 실제: \(baseModel!.state)")
        }

        let smallModel = findModel(smallId())
        XCTAssertNotNil(smallModel)
        if case .downloaded = smallModel!.state { } else {
            XCTFail("loading 상태가 downloaded로 리셋되지 않음. 실제: \(smallModel!.state)")
        }
    }

    func test_resetActiveStates_onlyResetsActiveModels_preservesOthers() {
        // Given: tiny는 downloading, base는 downloaded (안정 상태), small은 error
        setState(tinyId(), to: .downloading(progress: 0.5))
        setState(baseId(), to: .downloaded)
        setState(smallId(), to: .error("test error"))

        // When
        sut.resetActiveStates()

        // Then: tiny만 리셋, base와 small은 그대로
        let tinyModel = findModel(tinyId())
        switch tinyModel!.state {
        case .notDownloaded, .downloaded:
            break // OK - 리셋됨
        default:
            XCTFail("downloading 상태가 리셋되지 않음. 실제: \(tinyModel!.state)")
        }

        let baseModel = findModel(baseId())
        if case .downloaded = baseModel!.state {
            // OK - 그대로
        } else {
            XCTFail("downloaded 상태가 변경됨. 실제: \(baseModel!.state)")
        }

        let smallModel = findModel(smallId())
        if case .error = smallModel!.state {
            // OK - 그대로
        } else {
            XCTFail("error 상태가 변경됨. 실제: \(smallModel!.state)")
        }
    }

    // MARK: - 버그 시나리오: 모델 A 다운로드 중 모델 B 시작

    func test_bugScenario_modelADownloading_modelBStarts_modelAStateResets() {
        // Given: 모델 A(tiny)가 downloading 중
        let modelA = tinyId()
        let modelB = baseId()
        setState(modelA, to: .downloading(progress: 0.6))

        // When: 모델 B를 시작하기 위해 모델 A의 작업을 취소하고 resetActiveStates 호출
        // (loadModel 내부에서 일어나는 동작을 시뮬레이션)
        sut.resetActiveStates()

        // Then: 모델 A의 상태가 stuck되지 않고 올바르게 리셋됨
        let modelAInfo = findModel(modelA)
        XCTAssertNotNil(modelAInfo)
        switch modelAInfo!.state {
        case .notDownloaded, .downloaded:
            break // OK - 리셋됨
        case .downloading:
            XCTFail("모델 A의 downloading 상태가 리셋되지 않음 (버그 재현)")
        default:
            XCTFail("예상치 못한 상태: \(modelAInfo!.state)")
        }

        // 모델 B도 활성 상태가 아니어야 함 (아직 시작 전)
        let modelBInfo = findModel(modelB)
        XCTAssertNotNil(modelBInfo)
        switch modelBInfo!.state {
        case .notDownloaded, .downloaded:
            break // OK
        default:
            XCTFail("모델 B가 의도치 않게 변경됨: \(modelBInfo!.state)")
        }
    }

    // MARK: - Qwen3-ASR 모델에 대한 resetActiveStates

    func test_resetActiveStates_resetsQwenModelDownloadingState() {
        // Qwen3-ASR 모델은 항상 디스크에 없으므로 notDownloaded로 리셋
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        guard let firstQwen = qwenModels.first else {
            // macOS에서는 Qwen3-ASR 모델이 없을 수 있음
            return
        }

        setState(firstQwen.identifier, to: .downloading(progress: 0.4))

        sut.resetActiveStates()

        let model = findModel(firstQwen.identifier)
        XCTAssertNotNil(model)
        if case .notDownloaded = model!.state {
            // OK
        } else {
            XCTFail("Qwen3-ASR 모델의 downloading 상태는 notDownloaded로 리셋되어야 함. 실제: \(model!.state)")
        }
    }

    func test_resetActiveStates_resetsQwenModelOptimizingToDownloaded() {
        // optimizing/loading은 다운로드 완료 후 단계이므로 엔진에 관계없이 downloaded로 리셋
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        guard let firstQwen = qwenModels.first else { return }

        setState(firstQwen.identifier, to: .optimizing)

        sut.resetActiveStates()

        let model = findModel(firstQwen.identifier)
        XCTAssertNotNil(model)
        if case .downloaded = model!.state {
            // OK - optimizing 단계 진입 = 다운로드 완료 상태
        } else {
            XCTFail("Qwen3-ASR 모델의 optimizing 상태는 downloaded로 리셋되어야 함. 실제: \(model!.state)")
        }
    }

    // MARK: - 엣지 케이스

    func test_resetActiveStates_calledMultipleTimes_isIdempotent() {
        setState(tinyId(), to: .downloading(progress: 0.5))

        sut.resetActiveStates()
        let stateAfterFirst = findModel(tinyId())!.state

        sut.resetActiveStates()
        let stateAfterSecond = findModel(tinyId())!.state

        // 두 번 호출해도 결과가 동일해야 함
        switch (stateAfterFirst, stateAfterSecond) {
        case (.notDownloaded, .notDownloaded), (.downloaded, .downloaded):
            break // OK
        default:
            XCTFail("resetActiveStates 중복 호출 시 상태 불일치. 첫 번째: \(stateAfterFirst), 두 번째: \(stateAfterSecond)")
        }
    }

    func test_resetActiveStates_withNoActiveModels_doesNothing() {
        // Given: 모든 모델이 안정 상태
        let statesBefore = sut.models.map { $0.state }

        // When
        sut.resetActiveStates()

        // Then: 상태가 변경되지 않아야 함
        let statesAfter = sut.models.map { $0.state }
        XCTAssertEqual(statesBefore.count, statesAfter.count)
        for i in statesBefore.indices {
            switch (statesBefore[i], statesAfter[i]) {
            case (.notDownloaded, .notDownloaded), (.downloaded, .downloaded):
                break // OK
            default:
                XCTFail("안정 상태 모델이 변경됨. 인덱스: \(i), 이전: \(statesBefore[i]), 이후: \(statesAfter[i])")
            }
        }
    }

    func test_resetActiveStates_preservesModelCount() {
        let countBefore = sut.models.count
        setState(tinyId(), to: .downloading(progress: 0.5))
        setState(baseId(), to: .optimizing)

        sut.resetActiveStates()

        XCTAssertEqual(sut.models.count, countBefore, "resetActiveStates 후 모델 개수가 변경되면 안 됨")
    }

    func test_resetActiveStates_preservesModelIdentifiers() {
        let identifiersBefore = sut.models.map { $0.identifier }
        setState(tinyId(), to: .loading)
        setState(smallId(), to: .downloading(progress: 0.9))

        sut.resetActiveStates()

        let identifiersAfter = sut.models.map { $0.identifier }
        XCTAssertEqual(identifiersBefore, identifiersAfter, "resetActiveStates 후 identifier가 변경되면 안 됨")
    }

    func test_resetActiveStates_preservesIsSupportedFlag() {
        let supportedBefore = sut.models.map { $0.isSupported }
        setState(tinyId(), to: .downloading(progress: 0.5))

        sut.resetActiveStates()

        let supportedAfter = sut.models.map { $0.isSupported }
        XCTAssertEqual(supportedBefore, supportedAfter, "resetActiveStates 후 isSupported가 변경되면 안 됨")
    }

    // MARK: - cancelDownload과의 차이 검증

    func test_cancelDownload_onlyResetsTargetModel_notOthers() {
        // cancelDownload은 지정한 모델만 리셋하고, 다른 활성 모델은 그대로 둔다
        setState(tinyId(), to: .downloading(progress: 0.5))
        setState(baseId(), to: .downloading(progress: 0.3))

        sut.cancelDownload(tinyId())

        // tiny는 리셋됨
        let tinyModel = findModel(tinyId())
        switch tinyModel!.state {
        case .notDownloaded, .downloaded:
            break // OK
        default:
            XCTFail("cancelDownload 대상 모델이 리셋되지 않음")
        }

        // base는 여전히 downloading (cancelDownload은 다른 모델에 영향 없음)
        let baseModel = findModel(baseId())
        if case .downloading = baseModel!.state {
            // OK - cancelDownload은 다른 모델을 건드리지 않음
        } else {
            XCTFail("cancelDownload이 다른 모델에 영향을 미침. 실제: \(baseModel!.state)")
        }
    }

    func test_resetActiveStates_resetsAllActiveModels_unlikeCancelDownload() {
        // resetActiveStates는 모든 활성 모델을 리셋한다 (cancelDownload과의 핵심 차이)
        setState(tinyId(), to: .downloading(progress: 0.5))
        setState(baseId(), to: .downloading(progress: 0.3))
        setState(smallId(), to: .optimizing)

        sut.resetActiveStates()

        // 모든 활성 모델이 리셋됨
        for id in [tinyId(), baseId(), smallId()] {
            let model = findModel(id)
            switch model!.state {
            case .notDownloaded, .downloaded:
                break // OK
            default:
                XCTFail("resetActiveStates가 모든 활성 모델을 리셋하지 않음. 모델: \(id.displayName), 상태: \(model!.state)")
            }
        }
    }
}
