import XCTest
@testable import Writ

/// loadDefaultModelIfNeeded() 테스트 — 저장된 모델이 없을 때 activeModel이 nil로 유지되는지 검증
@MainActor
final class ModelManagerLoadDefaultTests: XCTestCase {

    private var engine: WhisperKitEngine!
    private var sut: ModelManager!

    override func setUp() {
        super.setUp()
        engine = WhisperKitEngine()
        sut = ModelManager(whisperEngine: engine)
        // 테스트 시작 전 저장된 모델 선택 정보 제거
        UserDefaults.standard.removeObject(forKey: "selectedModelVariant")
        UserDefaults.standard.removeObject(forKey: "selectedEngineType")
    }

    override func tearDown() {
        sut = nil
        engine = nil
        UserDefaults.standard.removeObject(forKey: "selectedModelVariant")
        UserDefaults.standard.removeObject(forKey: "selectedEngineType")
        super.tearDown()
    }

    // MARK: - 저장된 모델이 없을 때 (최초 실행 시나리오)

    func test_loadDefaultModelIfNeeded_noSavedModel_activeModelRemainsNil() async {
        // Given: UserDefaults에 저장된 모델이 없음 (최초 실행)
        XCTAssertNil(UserDefaults.standard.string(forKey: "selectedModelVariant"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "selectedEngineType"))

        // When
        await sut.loadDefaultModelIfNeeded()

        // Then: 자동 다운로드 없이 activeModel이 nil 유지
        XCTAssertNil(sut.activeModel, "저장된 모델이 없으면 activeModel은 nil이어야 함 (자동 다운로드 제거됨)")
    }

    func test_loadDefaultModelIfNeeded_noSavedModel_doesNotChangeSelectedEngine() async {
        // Given: 기본 엔진은 whisperKit
        let originalEngine = sut.selectedEngine

        // When
        await sut.loadDefaultModelIfNeeded()

        // Then: 엔진이 변경되지 않아야 함
        XCTAssertEqual(sut.selectedEngine, originalEngine,
                       "저장된 모델이 없으면 selectedEngine이 변경되면 안 됨")
    }

    func test_loadDefaultModelIfNeeded_noSavedModel_modelStatesRemainStable() async {
        // Given: 초기 상태 기록
        let statesBefore = sut.models.map { ($0.identifier, $0.state) }

        // When
        await sut.loadDefaultModelIfNeeded()

        // Then: 모델 상태가 downloading/loading 등 활성 상태로 변경되지 않아야 함
        for (id, stateBefore) in statesBefore {
            guard let modelAfter = sut.models.first(where: { $0.identifier == id }) else {
                XCTFail("모델이 사라짐: \(id.displayName)")
                continue
            }
            switch modelAfter.state {
            case .downloading, .optimizing, .loading:
                XCTFail("저장된 모델이 없을 때 모델 \(id.displayName)이 활성 상태로 변경됨: \(modelAfter.state)")
            default:
                break
            }
        }
    }

    // MARK: - activeModel이 이미 설정된 경우 (early return)

    func test_loadDefaultModelIfNeeded_activeModelAlreadySet_doesNothing() async {
        // Given: activeModel이 이미 설정됨
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        sut.activeModel = tinyId

        // When
        await sut.loadDefaultModelIfNeeded()

        // Then: activeModel이 변경되지 않아야 함
        XCTAssertEqual(sut.activeModel, tinyId,
                       "activeModel이 이미 설정되어 있으면 변경되면 안 됨")
    }

    // MARK: - 잘못된 저장 데이터

    func test_loadDefaultModelIfNeeded_invalidSavedEngineType_activeModelRemainsNil() async {
        // Given: 잘못된 엔진 타입과 잘못된 variant가 저장되어 있음
        UserDefaults.standard.set("invalidEngine", forKey: "selectedEngineType")
        UserDefaults.standard.set("nonexistent_variant", forKey: "selectedModelVariant")

        // When
        await sut.loadDefaultModelIfNeeded()

        // Then: 잘못된 데이터로는 모델을 로드할 수 없으므로 nil 유지
        XCTAssertNil(sut.activeModel,
                     "잘못된 엔진 타입이 저장되어 있으면 activeModel은 nil이어야 함")
    }

    func test_loadDefaultModelIfNeeded_invalidSavedVariant_activeModelRemainsNil() async {
        // Given: 유효한 엔진이지만 잘못된 variant가 저장되어 있음
        UserDefaults.standard.set("whisperKit", forKey: "selectedEngineType")
        UserDefaults.standard.set("nonexistent_model_variant", forKey: "selectedModelVariant")

        // When
        await sut.loadDefaultModelIfNeeded()

        // Then
        XCTAssertNil(sut.activeModel,
                     "존재하지 않는 variant가 저장되어 있으면 activeModel은 nil이어야 함")
    }

    func test_loadDefaultModelIfNeeded_emptyStringSavedVariant_activeModelRemainsNil() async {
        // Given: 빈 문자열이 저장되어 있음
        UserDefaults.standard.set("", forKey: "selectedModelVariant")

        // When
        await sut.loadDefaultModelIfNeeded()

        // Then
        XCTAssertNil(sut.activeModel,
                     "빈 문자열 variant로는 모델을 로드할 수 없어야 함")
    }

    func test_loadDefaultModelIfNeeded_onlyEngineType_noVariant_activeModelRemainsNil() async {
        // Given: 엔진 타입만 있고 variant가 없음
        UserDefaults.standard.set("whisperKit", forKey: "selectedEngineType")
        UserDefaults.standard.removeObject(forKey: "selectedModelVariant")

        // When
        await sut.loadDefaultModelIfNeeded()

        // Then
        XCTAssertNil(sut.activeModel,
                     "variant가 없으면 activeModel은 nil이어야 함")
    }

    // MARK: - refreshDownloadStates 호출 확인

    func test_loadDefaultModelIfNeeded_callsRefreshDownloadStates() async {
        // loadDefaultModelIfNeeded는 항상 refreshDownloadStates를 호출해야 함
        // 간접적으로 검증: 호출 후 모델 상태가 파일 시스템과 일치하는지 확인
        await sut.loadDefaultModelIfNeeded()

        for model in sut.models where model.identifier.engine == .whisperKit {
            guard let variant = model.identifier.whisperVariant else { continue }
            let isDownloaded = ModelManager.isWhisperModelDownloaded(variant)
            if isDownloaded {
                switch model.state {
                case .downloaded, .loaded:
                    break
                default:
                    XCTFail("\(variant) 다운로드 상태와 불일치: \(model.state)")
                }
            }
        }
    }

    // MARK: - 여러 번 호출 안정성

    func test_loadDefaultModelIfNeeded_calledMultipleTimes_noCrash() async {
        // Given: 저장된 모델 없음
        // When: 여러 번 연속 호출
        for _ in 0..<5 {
            await sut.loadDefaultModelIfNeeded()
        }

        // Then: 크래시 없이 완료, activeModel은 여전히 nil
        XCTAssertNil(sut.activeModel)
    }

    func test_loadDefaultModelIfNeeded_modelCountUnchanged() async {
        // Given
        let countBefore = sut.models.count

        // When
        await sut.loadDefaultModelIfNeeded()

        // Then
        XCTAssertEqual(sut.models.count, countBefore,
                       "loadDefaultModelIfNeeded 호출 후 모델 수가 변경되면 안 됨")
    }
}
