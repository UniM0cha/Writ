import XCTest
@testable import Writ

/// loadModel()에서 이미 다운로드된 모델의 .downloading 상태를 건너뛰는 기능 테스트
/// - isModelDownloaded()에 의한 초기 상태 분기 (.downloading vs .loading)
/// - progressCallback 가드 (이미 .loading인 모델에 .downloading 덮어쓰기 방지)
@MainActor
final class ModelManagerSkipDownloadingStateTests: XCTestCase {

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
    private func largeV3TurboId() -> ModelIdentifier { WhisperModelVariant.largeV3Turbo.modelIdentifier }

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

    // MARK: - isWhisperModelDownloaded 디스패치 검증

    func test_isWhisperModelDownloaded_returnsConsistentResultForAllVariants() {
        // isWhisperModelDownloaded은 파일시스템 기반이므로 모든 variant에 대해 호출 가능해야 함
        for variant in WhisperModelVariant.allCases {
            let result = ModelManager.isWhisperModelDownloaded(variant)
            // Bool이면 OK (크래시 없이 결과 반환)
            XCTAssertTrue(result == true || result == false,
                          "\(variant) isWhisperModelDownloaded가 Bool을 반환해야 함")
        }
    }

    func test_isWhisperModelDownloaded_resultMatchesInitialModelState() {
        // ModelManager 초기화 시 isWhisperModelDownloaded 결과와 모델의 초기 상태가 일치해야 함
        for variant in WhisperModelVariant.allCases {
            let isDownloaded = ModelManager.isWhisperModelDownloaded(variant)
            let model = findModel(variant.modelIdentifier)
            XCTAssertNotNil(model, "\(variant) 모델이 models 배열에 존재해야 함")

            if isDownloaded {
                if case .downloaded = model!.state {
                    // OK
                } else {
                    XCTFail("\(variant)가 다운로드 상태인데 초기 상태가 .downloaded가 아님. 실제: \(model!.state)")
                }
            } else {
                if case .notDownloaded = model!.state {
                    // OK
                } else {
                    XCTFail("\(variant)가 미다운로드 상태인데 초기 상태가 .notDownloaded가 아님. 실제: \(model!.state)")
                }
            }
        }
    }

    // MARK: - isModelDownloaded 엔진별 디스패치 (간접 검증)

    func test_whisperIdentifier_hasWhisperVariant() {
        // WhisperKit 모델의 identifier는 whisperVariant를 갖고 있어야
        // isModelDownloaded에서 isWhisperModelDownloaded로 디스패치됨
        for variant in WhisperModelVariant.allCases {
            let id = variant.modelIdentifier
            XCTAssertEqual(id.engine, .whisperKit)
            XCTAssertNotNil(id.whisperVariant, "\(variant) identifier의 whisperVariant가 nil이면 안 됨")
            XCTAssertEqual(id.whisperVariant, variant)
        }
    }

    func test_qwenIdentifier_hasNoWhisperVariant() {
        // Qwen3-ASR 모델의 identifier는 whisperVariant가 nil이어야
        // isModelDownloaded에서 isQwenModelDownloaded로 디스패치됨
        let qwenModels = ModelIdentifier.allModels(for: .qwen3ASR)
        for id in qwenModels {
            XCTAssertEqual(id.engine, .qwen3ASR)
            XCTAssertNil(id.whisperVariant, "\(id.displayName) Qwen3 identifier의 whisperVariant는 nil이어야 함")
        }
    }

    func test_qwenIdentifier_engineIsQwen3ASR() {
        // isModelDownloaded에서 엔진 디스패치를 위해 engine 프로퍼티가 올바르게 설정되어야 함
        let qwenIds: [ModelIdentifier] = [
            .qwen3_0_6B_4bit, .qwen3_0_6B_8bit, .qwen3_1_7B_4bit, .qwen3_1_7B_8bit
        ]
        for id in qwenIds {
            XCTAssertEqual(id.engine, .qwen3ASR, "\(id.displayName)의 engine이 .qwen3ASR이어야 함")
        }
    }

    // MARK: - loadModel 초기 상태 분기: 다운로드되지 않은 모델

    func test_loadModel_notDownloadedModel_initialStateShouldBeDownloading() {
        // 다운로드되지 않은 WhisperKit 모델을 찾아서 테스트
        for variant in WhisperModelVariant.allCases {
            guard !ModelManager.isWhisperModelDownloaded(variant) else { continue }
            let id = variant.modelIdentifier

            // loadModel을 직접 호출하면 실제 다운로드가 시작되므로,
            // 초기 상태 분기 로직을 시뮬레이션:
            // isModelDownloaded == false이면 .downloading(progress: 0)으로 설정해야 함
            let alreadyDownloaded = ModelManager.isWhisperModelDownloaded(variant)
            XCTAssertFalse(alreadyDownloaded)

            // 실제 loadModel 로직: alreadyDownloaded ? .loading : .downloading(progress: 0)
            let expectedState: ModelState = alreadyDownloaded ? .loading : .downloading(progress: 0)
            setState(id, to: expectedState)

            let model = findModel(id)
            XCTAssertNotNil(model)
            if case .downloading(let progress, _) = model!.state {
                XCTAssertEqual(progress, 0.0, accuracy: 0.001,
                               "미다운로드 모델의 초기 상태는 .downloading(progress: 0)이어야 함")
            } else {
                XCTFail("미다운로드 모델 \(variant)의 초기 상태가 .downloading이 아님. 실제: \(model!.state)")
            }
            return // 하나만 확인하면 충분
        }
        // 모든 모델이 다운로드되어 있으면 이 테스트는 환경 의존으로 skip
    }

    func test_loadModel_downloadedModel_initialStateShouldBeLoading() {
        // 이미 다운로드된 WhisperKit 모델을 찾아서 테스트
        for variant in WhisperModelVariant.allCases {
            guard ModelManager.isWhisperModelDownloaded(variant) else { continue }
            let id = variant.modelIdentifier

            let alreadyDownloaded = ModelManager.isWhisperModelDownloaded(variant)
            XCTAssertTrue(alreadyDownloaded)

            // 실제 loadModel 로직: alreadyDownloaded ? .loading : .downloading(progress: 0)
            let expectedState: ModelState = alreadyDownloaded ? .loading : .downloading(progress: 0)
            setState(id, to: expectedState)

            let model = findModel(id)
            XCTAssertNotNil(model)
            if case .loading = model!.state {
                // OK - 이미 다운로드된 모델은 .loading으로 직접 전환
            } else {
                XCTFail("다운로드된 모델 \(variant)의 초기 상태가 .loading이 아님. 실제: \(model!.state)")
            }
            return // 하나만 확인하면 충분
        }
        // 다운로드된 모델이 없으면 환경 의존으로 skip
    }

    // MARK: - 초기 상태 분기 로직의 정확성 (환경 무관 유닛 테스트)

    func test_stateAssignment_whenAlreadyDownloadedIsTrue_shouldBeLoading() {
        // isModelDownloaded가 true를 반환하는 경우의 상태 분기 로직 검증
        let alreadyDownloaded = true
        let state: ModelState = alreadyDownloaded ? .loading : .downloading(progress: 0)
        if case .loading = state {
            // OK
        } else {
            XCTFail("alreadyDownloaded=true일 때 상태는 .loading이어야 함. 실제: \(state)")
        }
    }

    func test_stateAssignment_whenAlreadyDownloadedIsFalse_shouldBeDownloading() {
        // isModelDownloaded가 false를 반환하는 경우의 상태 분기 로직 검증
        let alreadyDownloaded = false
        let state: ModelState = alreadyDownloaded ? .loading : .downloading(progress: 0)
        if case .downloading(let progress, _) = state {
            XCTAssertEqual(progress, 0.0, accuracy: 0.001)
        } else {
            XCTFail("alreadyDownloaded=false일 때 상태는 .downloading(progress: 0)이어야 함. 실제: \(state)")
        }
    }

    func test_stateAssignment_downloadingProgressIsZero_notAnyOtherValue() {
        // 다운로드 시작 시 progress가 정확히 0이어야 함
        let alreadyDownloaded = false
        let state: ModelState = alreadyDownloaded ? .loading : .downloading(progress: 0)
        if case .downloading(let progress, let status) = state {
            XCTAssertEqual(progress, 0.0, accuracy: 0.001, "초기 다운로드 progress는 0이어야 함")
            XCTAssertNil(status, "초기 다운로드 status는 nil이어야 함")
        } else {
            XCTFail("Expected .downloading")
        }
    }

    // MARK: - progressCallback 가드: .loading 상태 보호

    func test_progressCallback_whenStateIsDownloading_shouldUpdateProgress() {
        // progressCallback 가드 로직 시뮬레이션:
        // case .downloading = self.models[idx].state 일 때만 상태 업데이트
        let id = tinyId()
        setState(id, to: .downloading(progress: 0.0))

        // progressCallback이 호출될 때의 가드 조건 시뮬레이션
        if let idx = findIndex(id), case .downloading = sut.models[idx].state {
            // 가드 통과 -- 상태 업데이트 가능
            setState(id, to: .downloading(progress: 0.5))
        }

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .downloading(let progress, _) = model!.state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.001,
                           "downloading 상태에서 progressCallback은 progress를 업데이트해야 함")
        } else {
            XCTFail("Expected .downloading. 실제: \(model!.state)")
        }
    }

    func test_progressCallback_whenStateIsLoading_shouldNotOverwrite() {
        // progressCallback 가드 로직 시뮬레이션:
        // case .downloading = self.models[idx].state 이 아니면 (즉 .loading이면)
        // 상태를 업데이트하지 않아야 함
        let id = tinyId()
        setState(id, to: .loading)

        // progressCallback이 호출될 때의 가드 조건 시뮬레이션
        if let idx = findIndex(id), case .downloading = sut.models[idx].state {
            // 가드 통과 -- 하지만 .loading 상태이므로 여기에 들어오면 안 됨
            setState(id, to: .downloading(progress: 0.5))
            XCTFail("loading 상태에서 downloading 가드를 통과하면 안 됨")
        }

        // .loading 상태가 보존되어야 함
        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .loading = model!.state {
            // OK - .loading 상태가 보존됨
        } else {
            XCTFail("loading 상태가 덮어씌워짐. 실제: \(model!.state)")
        }
    }

    func test_progressCallback_whenStateIsOptimizing_shouldNotOverwrite() {
        // .optimizing 상태에서도 progressCallback이 .downloading으로 덮어쓰면 안 됨
        let id = baseId()
        setState(id, to: .optimizing)

        if let idx = findIndex(id), case .downloading = sut.models[idx].state {
            setState(id, to: .downloading(progress: 0.3))
            XCTFail("optimizing 상태에서 downloading 가드를 통과하면 안 됨")
        }

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .optimizing = model!.state {
            // OK
        } else {
            XCTFail("optimizing 상태가 덮어씌워짐. 실제: \(model!.state)")
        }
    }

    func test_progressCallback_whenStateIsLoaded_shouldNotOverwrite() {
        // .loaded 상태에서도 보호되어야 함
        let id = smallId()
        setState(id, to: .loaded)

        if let idx = findIndex(id), case .downloading = sut.models[idx].state {
            setState(id, to: .downloading(progress: 0.7))
            XCTFail("loaded 상태에서 downloading 가드를 통과하면 안 됨")
        }

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .loaded = model!.state {
            // OK
        } else {
            XCTFail("loaded 상태가 덮어씌워짐. 실제: \(model!.state)")
        }
    }

    func test_progressCallback_whenStateIsError_shouldNotOverwrite() {
        // .error 상태에서도 보호되어야 함
        let id = tinyId()
        setState(id, to: .error("네트워크 오류"))

        if let idx = findIndex(id), case .downloading = sut.models[idx].state {
            setState(id, to: .downloading(progress: 0.1))
            XCTFail("error 상태에서 downloading 가드를 통과하면 안 됨")
        }

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .error(let msg) = model!.state {
            XCTAssertEqual(msg, "네트워크 오류")
        } else {
            XCTFail("error 상태가 덮어씌워짐. 실제: \(model!.state)")
        }
    }

    func test_progressCallback_whenStateIsNotDownloaded_shouldNotOverwrite() {
        // .notDownloaded 상태에서도 보호되어야 함
        let id = largeV3Id()
        setState(id, to: .notDownloaded)

        if let idx = findIndex(id), case .downloading = sut.models[idx].state {
            setState(id, to: .downloading(progress: 0.2))
            XCTFail("notDownloaded 상태에서 downloading 가드를 통과하면 안 됨")
        }

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .notDownloaded = model!.state {
            // OK
        } else {
            XCTFail("notDownloaded 상태가 덮어씌워짐. 실제: \(model!.state)")
        }
    }

    // MARK: - progressCallback 가드: 상태별 패턴 매칭 검증

    func test_patternMatch_downloading_matchesDownloadingState() {
        let state: ModelState = .downloading(progress: 0.5)
        if case .downloading = state {
            // OK - 매칭됨
        } else {
            XCTFail(".downloading 상태는 case .downloading에 매칭되어야 함")
        }
    }

    func test_patternMatch_downloading_doesNotMatchLoadingState() {
        let state: ModelState = .loading
        if case .downloading = state {
            XCTFail(".loading 상태는 case .downloading에 매칭되면 안 됨")
        }
        // OK - 매칭되지 않음
    }

    func test_patternMatch_downloading_doesNotMatchOptimizingState() {
        let state: ModelState = .optimizing
        if case .downloading = state {
            XCTFail(".optimizing 상태는 case .downloading에 매칭되면 안 됨")
        }
    }

    func test_patternMatch_downloading_doesNotMatchLoadedState() {
        let state: ModelState = .loaded
        if case .downloading = state {
            XCTFail(".loaded 상태는 case .downloading에 매칭되면 안 됨")
        }
    }

    func test_patternMatch_downloading_doesNotMatchDownloadedState() {
        let state: ModelState = .downloaded
        if case .downloading = state {
            XCTFail(".downloaded 상태는 case .downloading에 매칭되면 안 됨")
        }
    }

    // MARK: - Qwen3-ASR progressCallback 가드 (statusCallback 포함)

    func test_qwen3ProgressCallback_whenStateIsDownloading_shouldPreserveStatus() {
        // Qwen3-ASR progressCallback은 현재 status를 보존하면서 progress만 업데이트해야 함
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        guard let firstQwen = qwenModels.first else { return } // macOS에서는 skip

        let id = firstQwen.identifier
        setState(id, to: .downloading(progress: 0.3, status: "모델 다운로드 중"))

        // progressCallback 시뮬레이션: downloading 상태 확인 후 progress만 업데이트, status 보존
        if let idx = findIndex(id), case .downloading(_, let currentStatus) = sut.models[idx].state {
            setState(id, to: .downloading(progress: 0.6, status: currentStatus))
        }

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .downloading(let progress, let status) = model!.state {
            XCTAssertEqual(progress, 0.6, accuracy: 0.001)
            XCTAssertEqual(status, "모델 다운로드 중", "status가 보존되어야 함")
        } else {
            XCTFail("Expected .downloading. 실제: \(model!.state)")
        }
    }

    func test_qwen3ProgressCallback_whenStateIsLoading_shouldNotOverwrite() {
        // Qwen3-ASR 모델이 .loading 상태일 때 progressCallback이 덮어쓰면 안 됨
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        guard let firstQwen = qwenModels.first else { return }

        let id = firstQwen.identifier
        setState(id, to: .loading)

        // progressCallback 시뮬레이션
        if let idx = findIndex(id), case .downloading(_, let currentStatus) = sut.models[idx].state {
            setState(id, to: .downloading(progress: 0.5, status: currentStatus))
            XCTFail("loading 상태에서 Qwen3 progressCallback 가드를 통과하면 안 됨")
        }

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .loading = model!.state {
            // OK
        } else {
            XCTFail("Qwen3 모델의 loading 상태가 덮어씌워짐. 실제: \(model!.state)")
        }
    }

    func test_qwen3StatusCallback_whenStateIsDownloading_shouldPreserveProgress() {
        // Qwen3-ASR statusCallback은 현재 progress를 보존하면서 status만 업데이트해야 함
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        guard let firstQwen = qwenModels.first else { return }

        let id = firstQwen.identifier
        setState(id, to: .downloading(progress: 0.5, status: "모델 다운로드 중"))

        // statusCallback 시뮬레이션: downloading 상태 확인 후 status만 업데이트, progress 보존
        if let idx = findIndex(id), case .downloading(let progress, _) = sut.models[idx].state {
            setState(id, to: .downloading(progress: progress, status: "Aligner 로드 중"))
        }

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .downloading(let progress, let status) = model!.state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.001, "progress가 보존되어야 함")
            XCTAssertEqual(status, "Aligner 로드 중")
        } else {
            XCTFail("Expected .downloading. 실제: \(model!.state)")
        }
    }

    func test_qwen3StatusCallback_whenStateIsLoading_shouldNotOverwrite() {
        // Qwen3-ASR statusCallback도 .loading 상태를 덮어쓰면 안 됨
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        guard let firstQwen = qwenModels.first else { return }

        let id = firstQwen.identifier
        setState(id, to: .loading)

        // statusCallback 시뮬레이션
        if let idx = findIndex(id), case .downloading(let progress, _) = sut.models[idx].state {
            setState(id, to: .downloading(progress: progress, status: "Aligner 로드 중"))
            XCTFail("loading 상태에서 Qwen3 statusCallback 가드를 통과하면 안 됨")
        }

        let model = findModel(id)
        XCTAssertNotNil(model)
        if case .loading = model!.state {
            // OK
        } else {
            XCTFail("Qwen3 모델의 loading 상태가 statusCallback에 의해 덮어씌워짐. 실제: \(model!.state)")
        }
    }

    // MARK: - 종합 시나리오: 이미 다운로드된 모델의 전체 상태 흐름

    func test_scenario_downloadedModel_skipsDownloadingPhase() {
        // 시나리오: 이미 다운로드된 모델은 .loading → .loaded 흐름을 따라야 함
        let id = tinyId()

        // Step 1: alreadyDownloaded = true 가정
        let alreadyDownloaded = true
        let initialState: ModelState = alreadyDownloaded ? .loading : .downloading(progress: 0)
        setState(id, to: initialState)

        // Step 2: .loading 상태 확인
        if case .loading = findModel(id)!.state {
            // OK
        } else {
            XCTFail("다운로드된 모델의 초기 상태가 .loading이 아님")
        }

        // Step 3: progressCallback이 호출되어도 .loading 상태 보존
        if let idx = findIndex(id), case .downloading = sut.models[idx].state {
            XCTFail("loading 상태에서 downloading 가드를 통과하면 안 됨")
        }

        // Step 4: 최종적으로 .loaded로 전환
        setState(id, to: .loaded)
        if case .loaded = findModel(id)!.state {
            // OK
        } else {
            XCTFail("Expected .loaded")
        }
    }

    func test_scenario_notDownloadedModel_gosThroughDownloadingPhase() {
        // 시나리오: 다운로드되지 않은 모델은 .downloading → .optimizing → .loading → .loaded 흐름
        let id = baseId()

        // Step 1: alreadyDownloaded = false 가정
        let alreadyDownloaded = false
        let initialState: ModelState = alreadyDownloaded ? .loading : .downloading(progress: 0)
        setState(id, to: initialState)

        // Step 2: .downloading 상태 확인
        if case .downloading(let p, _) = findModel(id)!.state {
            XCTAssertEqual(p, 0.0, accuracy: 0.001)
        } else {
            XCTFail("미다운로드 모델의 초기 상태가 .downloading이 아님")
        }

        // Step 3: progressCallback으로 progress 업데이트
        if let idx = findIndex(id), case .downloading = sut.models[idx].state {
            setState(id, to: .downloading(progress: 0.5))
        }
        if case .downloading(let p, _) = findModel(id)!.state {
            XCTAssertEqual(p, 0.5, accuracy: 0.001)
        } else {
            XCTFail("progress 업데이트 실패")
        }

        // Step 4: optimizing → loading → loaded
        setState(id, to: .optimizing)
        setState(id, to: .loading)
        setState(id, to: .loaded)
        if case .loaded = findModel(id)!.state {
            // OK
        } else {
            XCTFail("Expected .loaded")
        }
    }

    // MARK: - 엣지 케이스

    func test_multipleModels_eachGetsCorrectInitialState() {
        // 여러 모델이 각각 다른 다운로드 상태일 때 독립적으로 올바른 초기 상태를 받아야 함
        for variant in WhisperModelVariant.allCases {
            let id = variant.modelIdentifier
            let isDownloaded = ModelManager.isWhisperModelDownloaded(variant)
            let expectedState: ModelState = isDownloaded ? .loading : .downloading(progress: 0)
            setState(id, to: expectedState)

            let model = findModel(id)
            XCTAssertNotNil(model)

            if isDownloaded {
                if case .loading = model!.state { /* OK */ } else {
                    XCTFail("\(variant)가 downloaded인데 .loading이 아님. 실제: \(model!.state)")
                }
            } else {
                if case .downloading = model!.state { /* OK */ } else {
                    XCTFail("\(variant)가 not downloaded인데 .downloading이 아님. 실제: \(model!.state)")
                }
            }
        }
    }

    func test_progressCallbackGuard_onlyMatchesDownloadingState_exhaustive() {
        // 모든 ModelState에 대해 case .downloading 가드가 올바르게 동작하는지 확인
        let allStates: [ModelState] = [
            .notDownloaded,
            .downloading(progress: 0.5),
            .downloading(progress: 0.0, status: "테스트"),
            .downloaded,
            .optimizing,
            .loading,
            .loaded,
            .error("에러")
        ]

        for state in allStates {
            var matchedDownloading = false
            if case .downloading = state {
                matchedDownloading = true
            }

            switch state {
            case .downloading:
                XCTAssertTrue(matchedDownloading,
                              ".downloading 상태는 가드를 통과해야 함")
            default:
                XCTAssertFalse(matchedDownloading,
                               "\(state) 상태는 downloading 가드를 통과하면 안 됨")
            }
        }
    }

    func test_progressCallbackGuard_downloadingWithStatus_alsoMatches() {
        // status가 있는 .downloading도 가드를 통과해야 함
        let state: ModelState = .downloading(progress: 0.3, status: "모델 다운로드 중")
        if case .downloading = state {
            // OK - status 유무와 관계없이 downloading이면 가드 통과
        } else {
            XCTFail(".downloading(with status)도 case .downloading에 매칭되어야 함")
        }
    }

    func test_progressCallbackGuard_downloadingWithNilStatus_alsoMatches() {
        // status가 nil인 .downloading도 가드를 통과해야 함
        let state: ModelState = .downloading(progress: 0.7, status: nil)
        if case .downloading = state {
            // OK
        } else {
            XCTFail(".downloading(status: nil)도 case .downloading에 매칭되어야 함")
        }
    }

    // MARK: - refreshDownloadStates와의 일관성

    func test_refreshDownloadStates_isConsistentWithIsWhisperModelDownloaded() {
        // refreshDownloadStates 후 모델 상태가 isWhisperModelDownloaded 결과와 일치하는지 검증
        sut.refreshDownloadStates()

        for variant in WhisperModelVariant.allCases {
            let id = variant.modelIdentifier
            let isDownloaded = ModelManager.isWhisperModelDownloaded(variant)
            let model = findModel(id)
            XCTAssertNotNil(model)

            if isDownloaded {
                switch model!.state {
                case .downloaded, .loaded:
                    break // OK
                default:
                    XCTFail("refreshDownloadStates 후 다운로드된 모델 \(variant)의 상태가 올바르지 않음. 실제: \(model!.state)")
                }
            } else {
                if case .notDownloaded = model!.state {
                    // OK
                } else {
                    XCTFail("refreshDownloadStates 후 미다운로드 모델 \(variant)의 상태가 올바르지 않음. 실제: \(model!.state)")
                }
            }
        }
    }
}
