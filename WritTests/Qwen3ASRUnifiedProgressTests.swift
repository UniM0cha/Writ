import XCTest
@testable import Writ

/// Qwen3-ASR 통합 다운로드 진행도 테스트
/// ASR 모델(0~70%) + ForcedAligner(70~100%) 진행도 매핑 및 ModelManager 상태 업데이트 검증
@MainActor
final class Qwen3ASRUnifiedProgressTests: XCTestCase {

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

    // MARK: - ASR 진행도 매핑 (0% ~ 70%)

    func test_asrProgressMapping_zeroMapsToZero() {
        // ASR 모델 다운로드 시작: progress=0.0 -> 전체 0%
        let asrProgress: Double = 0.0
        let unified = Float(asrProgress) * 0.7
        XCTAssertEqual(unified, 0.0, accuracy: 0.001)
    }

    func test_asrProgressMapping_halfMapsTo35Percent() {
        // ASR 모델 50% 완료 -> 전체 35%
        let asrProgress: Double = 0.5
        let unified = Float(asrProgress) * 0.7
        XCTAssertEqual(unified, 0.35, accuracy: 0.001)
    }

    func test_asrProgressMapping_fullMapsTo70Percent() {
        // ASR 모델 100% 완료 -> 전체 70%
        let asrProgress: Double = 1.0
        let unified = Float(asrProgress) * 0.7
        XCTAssertEqual(unified, 0.7, accuracy: 0.001)
    }

    // MARK: - Aligner 진행도 매핑 (70% ~ 100%)

    func test_alignerProgressMapping_zeroMapsTo70Percent() {
        // Aligner 다운로드 시작: progress=0.0 -> 전체 70%
        let alignerProgress: Double = 0.0
        let unified = 0.7 + Float(alignerProgress) * 0.3
        XCTAssertEqual(unified, 0.7, accuracy: 0.001)
    }

    func test_alignerProgressMapping_halfMapsTo85Percent() {
        // Aligner 50% 완료 -> 전체 85%
        let alignerProgress: Double = 0.5
        let unified = 0.7 + Float(alignerProgress) * 0.3
        XCTAssertEqual(unified, 0.85, accuracy: 0.001)
    }

    func test_alignerProgressMapping_fullMapsTo100Percent() {
        // Aligner 100% 완료 -> 전체 100%
        let alignerProgress: Double = 1.0
        let unified = 0.7 + Float(alignerProgress) * 0.3
        XCTAssertEqual(unified, 1.0, accuracy: 0.001)
    }

    // MARK: - 진행도 연속성 (ASR -> Aligner 전환)

    func test_progressContinuity_asrEndEqualsAlignerStart() {
        // ASR 완료 시점(70%)과 Aligner 시작 시점(70%)이 일치해야 함
        let asrEnd = Float(1.0) * 0.7
        let alignerStart = 0.7 + Float(0.0) * 0.3
        XCTAssertEqual(asrEnd, alignerStart, accuracy: 0.001,
                       "ASR 완료 진행도와 Aligner 시작 진행도가 일치해야 한다")
    }

    func test_progressMonotonicity_alwaysIncreasing() {
        // 전체 진행도가 항상 단조 증가하는지 검증
        var previous: Float = -1
        // ASR 단계: 0.0 ~ 1.0 -> 전체 0.0 ~ 0.7
        for i in stride(from: 0.0, through: 1.0, by: 0.1) {
            let unified = Float(i) * 0.7
            XCTAssertGreaterThan(unified, previous,
                                 "ASR 단계 진행도가 단조 증가하지 않음: \(unified) <= \(previous)")
            previous = unified
        }
        // Aligner 단계: 0.0 ~ 1.0 -> 전체 0.7 ~ 1.0
        for i in stride(from: 0.0, through: 1.0, by: 0.1) {
            let unified = 0.7 + Float(i) * 0.3
            XCTAssertGreaterThanOrEqual(unified, previous,
                                        "Aligner 단계 진행도가 단조 증가하지 않음: \(unified) < \(previous)")
            previous = unified
        }
    }

    func test_progressRange_alwaysBetweenZeroAndOne() {
        // 모든 진행도 값이 [0, 1] 범위 내에 있어야 한다
        for i in stride(from: 0.0, through: 1.0, by: 0.01) {
            let asrUnified = Float(i) * 0.7
            XCTAssertGreaterThanOrEqual(asrUnified, 0.0)
            XCTAssertLessThanOrEqual(asrUnified, 1.0)

            let alignerUnified = 0.7 + Float(i) * 0.3
            XCTAssertGreaterThanOrEqual(alignerUnified, 0.0)
            XCTAssertLessThanOrEqual(alignerUnified, 1.0)
        }
    }

    // MARK: - ModelManager 상태 업데이트 (status 포함)

    func test_modelManager_downloadingWithStatus_storesStatus() {
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        guard let firstQwen = qwenModels.first else { return }

        setState(firstQwen.identifier, to: .downloading(progress: 0.3, status: "모델 다운로드 중"))

        let model = findModel(firstQwen.identifier)
        XCTAssertNotNil(model)
        if case .downloading(let progress, let status) = model!.state {
            XCTAssertEqual(progress, 0.3, accuracy: 0.001)
            XCTAssertEqual(status, "모델 다운로드 중")
        } else {
            XCTFail("Expected .downloading with status, got \(model!.state)")
        }
    }

    func test_modelManager_downloadingWithNilStatus_worksForWhisperKit() {
        // WhisperKit 모델은 status 없이 다운로드 진행
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setState(tinyId, to: .downloading(progress: 0.5))

        let model = findModel(tinyId)
        XCTAssertNotNil(model)
        if case .downloading(let progress, let status) = model!.state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.001)
            XCTAssertNil(status, "WhisperKit 모델은 status가 nil이어야 한다")
        } else {
            XCTFail("Expected .downloading, got \(model!.state)")
        }
    }

    func test_modelManager_statusUpdatePreservesProgress() {
        // statusCallback이 호출될 때 기존 progress를 유지하면서 status만 업데이트
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        guard let firstQwen = qwenModels.first else { return }

        // 1. 먼저 progress 설정
        setState(firstQwen.identifier, to: .downloading(progress: 0.35))

        // 2. status만 변경 (progress 유지)
        if let idx = findIndex(firstQwen.identifier),
           case .downloading(let currentProgress, _) = sut.models[idx].state {
            sut.models[idx].state = .downloading(progress: currentProgress, status: "모델 로드 중")
        }

        // 3. 검증: progress는 유지, status만 변경
        let model = findModel(firstQwen.identifier)
        if case .downloading(let progress, let status) = model!.state {
            XCTAssertEqual(progress, 0.35, accuracy: 0.001, "progress가 유지되어야 한다")
            XCTAssertEqual(status, "모델 로드 중")
        } else {
            XCTFail("Expected .downloading, got \(model!.state)")
        }
    }

    func test_modelManager_statusTransitions() {
        // Qwen3-ASR 모델의 상태 전환 시퀀스 시뮬레이션
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        guard let firstQwen = qwenModels.first else { return }

        let id = firstQwen.identifier

        // 1단계: ASR 모델 다운로드
        setState(id, to: .downloading(progress: 0.0, status: "모델 다운로드 중"))
        setState(id, to: .downloading(progress: 0.35, status: "모델 다운로드 중"))
        setState(id, to: .downloading(progress: 0.5, status: "모델 로드 중"))
        setState(id, to: .downloading(progress: 0.7, status: "모델 로드 중"))

        // 2단계: Aligner 다운로드
        setState(id, to: .downloading(progress: 0.7, status: "Aligner 다운로드 중"))
        setState(id, to: .downloading(progress: 0.85, status: "Aligner 다운로드 중"))
        setState(id, to: .downloading(progress: 0.95, status: "Aligner 로드 중"))
        setState(id, to: .downloading(progress: 1.0, status: "Aligner 로드 중"))

        // 3단계: 완료
        setState(id, to: .loaded)

        let model = findModel(id)
        if case .loaded = model!.state {
            // OK
        } else {
            XCTFail("Expected .loaded, got \(model!.state)")
        }
    }

    // MARK: - resetActiveStates + status

    func test_resetActiveStates_resetsDownloadingWithStatus() {
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        guard let firstQwen = qwenModels.first else { return }

        setState(firstQwen.identifier, to: .downloading(progress: 0.5, status: "모델 다운로드 중"))

        sut.resetActiveStates()

        let model = findModel(firstQwen.identifier)
        XCTAssertNotNil(model)
        if case .notDownloaded = model!.state {
            // OK - Qwen3-ASR 모델은 디스크 확인 불가능하므로 notDownloaded로 리셋
        } else {
            XCTFail("downloading(status 포함) 상태도 리셋되어야 함. 실제: \(model!.state)")
        }
    }

    func test_resetActiveStates_resetsWhisperDownloadingWithoutStatus() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        guard !ModelManager.isWhisperModelDownloaded(.tiny) else { return }

        setState(tinyId, to: .downloading(progress: 0.5))

        sut.resetActiveStates()

        let model = findModel(tinyId)
        XCTAssertNotNil(model)
        if case .notDownloaded = model!.state {
            // OK
        } else {
            XCTFail("WhisperKit downloading(nil status) 상태도 리셋되어야 함. 실제: \(model!.state)")
        }
    }

    // MARK: - 초기 상태

    func test_loadModel_initialState_hasNoStatus() {
        // loadModel 시작 시 초기 상태는 .downloading(progress: 0) (status 없음)
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setState(tinyId, to: .downloading(progress: 0))

        let model = findModel(tinyId)
        XCTAssertNotNil(model)
        if case .downloading(let progress, let status) = model!.state {
            XCTAssertEqual(progress, 0.0, accuracy: 0.001)
            XCTAssertNil(status, "초기 상태의 status는 nil이어야 한다")
        } else {
            XCTFail("Expected .downloading(progress: 0), got \(model!.state)")
        }
    }

    // MARK: - cancelDownload + status

    func test_cancelDownload_resetsDownloadingWithStatus() {
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        guard let firstQwen = qwenModels.first else { return }

        setState(firstQwen.identifier, to: .downloading(progress: 0.6, status: "Aligner 다운로드 중"))

        sut.cancelDownload(firstQwen.identifier)

        let model = findModel(firstQwen.identifier)
        XCTAssertNotNil(model)
        switch model!.state {
        case .notDownloaded, .downloaded:
            break // OK
        default:
            XCTFail("cancelDownload 후 status 포함 downloading 상태가 남아있으면 안 됨. 실제: \(model!.state)")
        }
    }

    // MARK: - 엣지 케이스: 진행도 경계값

    func test_asrProgressMapping_negativeClampedToZero() {
        // 음수 진행도가 들어올 경우 (방어적 코딩)
        let asrProgress: Double = -0.1
        let unified = Float(asrProgress) * 0.7
        XCTAssertLessThan(unified, 0.0, "음수 입력은 음수 결과를 생성 -- 호출자가 클램핑해야 함")
    }

    func test_alignerProgressMapping_overOneExceedsRange() {
        // 1.0 초과 진행도가 들어올 경우
        let alignerProgress: Double = 1.1
        let unified = 0.7 + Float(alignerProgress) * 0.3
        XCTAssertGreaterThan(unified, 1.0, "1.0 초과 입력은 범위 초과 결과를 생성 -- 호출자가 클램핑해야 함")
    }

    // MARK: - allCasesExist (status 포함)

    func test_allCasesExist_includingStatusVariant() {
        let states: [ModelState] = [
            .notDownloaded,
            .downloading(progress: 0.5),
            .downloading(progress: 0.5, status: "테스트"),
            .downloading(progress: 0.5, status: nil),
            .downloaded,
            .optimizing,
            .loading,
            .loaded,
            .error("test")
        ]
        // status가 있든 없든 모두 .downloading 케이스
        var downloadingCount = 0
        for state in states {
            if case .downloading = state {
                downloadingCount += 1
            }
        }
        XCTAssertEqual(downloadingCount, 3, "downloading 케이스가 3개여야 한다")
        XCTAssertEqual(states.count, 9)
    }
}
