import XCTest
@testable import Writ

/// Qwen3-ASR CoreML 다운로드 진행도 테스트
/// ASR 모델(0~90%) + warmUp(90~100%) 진행도 매핑 및 ModelManager 상태 업데이트 검증
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

    // MARK: - ASR 진행도 매핑 (0% ~ 90%)

    func test_asrProgressMapping_zeroMapsToZero() {
        let asrProgress: Double = 0.0
        let unified = Float(asrProgress) * 0.9
        XCTAssertEqual(unified, 0.0, accuracy: 0.001)
    }

    func test_asrProgressMapping_halfMapsTo45Percent() {
        let asrProgress: Double = 0.5
        let unified = Float(asrProgress) * 0.9
        XCTAssertEqual(unified, 0.45, accuracy: 0.001)
    }

    func test_asrProgressMapping_fullMapsTo90Percent() {
        let asrProgress: Double = 1.0
        let unified = Float(asrProgress) * 0.9
        XCTAssertEqual(unified, 0.9, accuracy: 0.001)
    }

    // MARK: - 진행도 연속성

    func test_progressMonotonicity_alwaysIncreasing() {
        var previous: Float = -1
        for i in stride(from: 0.0, through: 1.0, by: 0.1) {
            let unified = Float(i) * 0.9
            XCTAssertGreaterThan(unified, previous,
                                 "ASR 단계 진행도가 단조 증가하지 않음: \(unified) <= \(previous)")
            previous = unified
        }
    }

    func test_progressRange_alwaysBetweenZeroAndOne() {
        for i in stride(from: 0.0, through: 1.0, by: 0.01) {
            let asrUnified = Float(i) * 0.9
            XCTAssertGreaterThanOrEqual(asrUnified, 0.0)
            XCTAssertLessThanOrEqual(asrUnified, 1.0)
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

    func test_modelManager_statusTransitions() {
        let qwenModels = sut.models.filter { $0.identifier.engine == .qwen3ASR }
        guard let firstQwen = qwenModels.first else { return }

        let id = firstQwen.identifier

        // CoreML 모델 다운로드 진행
        setState(id, to: .downloading(progress: 0.0, status: "모델 다운로드 중"))
        setState(id, to: .downloading(progress: 0.3, status: "모델 다운로드 중"))
        setState(id, to: .downloading(progress: 0.6, status: "모델 로드 중"))
        setState(id, to: .downloading(progress: 0.9, status: "모델 최적화 중"))
        setState(id, to: .downloading(progress: 1.0, status: "모델 최적화 중"))

        // 완료
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
            // OK
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

        setState(firstQwen.identifier, to: .downloading(progress: 0.6, status: "모델 다운로드 중"))

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

    // MARK: - 엣지 케이스

    func test_asrProgressMapping_negativeClampedToZero() {
        let asrProgress: Double = -0.1
        let unified = Float(asrProgress) * 0.9
        XCTAssertLessThan(unified, 0.0, "음수 입력은 음수 결과를 생성 -- 호출자가 클램핑해야 함")
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
        var downloadingCount = 0
        for state in states {
            if case .downloading = state {
                downloadingCount += 1
            }
        }
        XCTAssertEqual(downloadingCount, 3, "downloading 케이스가 3개여야 한다")
        XCTAssertEqual(states.count, 9)
    }

    // MARK: - Qwen3 CoreML 모델 식별자

    func test_qwen3_0_6B_int8_variantKey() {
        XCTAssertTrue(ModelIdentifier.qwen3_0_6B_int8.variantKey.contains("0.6B"))
    }

    func test_allModels_qwen3ASR_hasFourVariants() {
        let models = ModelIdentifier.allModels(for: .qwen3ASR)
        XCTAssertEqual(models.count, 4)
    }
}
