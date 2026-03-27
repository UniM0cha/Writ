import XCTest
@testable import Writ

/// WhisperKitEngine 리팩토링 검증 테스트
/// - modelPhaseCallback 프로퍼티 제거 확인
/// - loadModel 3-param 오버로드 시그니처 존재 확인
/// - WhisperKitEngineError 에러 메시지 검증
/// - unloadModel 동작 검증
final class WhisperKitEngineTests: XCTestCase {

    private var sut: WhisperKitEngine!

    override func setUp() {
        super.setUp()
        sut = WhisperKitEngine()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - modelPhaseCallback 프로퍼티 제거 확인

    func test_modelPhaseCallbackProperty_doesNotExist() {
        // 리팩토링으로 modelPhaseCallback mutable 프로퍼티가 제거됨
        // loadModel의 파라미터로 대체되었으므로, 프로퍼티가 존재하지 않아야 한다
        let selector = NSSelectorFromString("modelPhaseCallback")
        let responds = (sut as AnyObject).responds(to: selector)
        XCTAssertFalse(
            responds,
            "WhisperKitEngine에서 'modelPhaseCallback' 프로퍼티가 제거되었어야 함"
        )
    }

    func test_setModelPhaseCallbackProperty_doesNotExist() {
        // setter도 존재하지 않아야 한다
        let selector = NSSelectorFromString("setModelPhaseCallback:")
        let responds = (sut as AnyObject).responds(to: selector)
        XCTAssertFalse(
            responds,
            "WhisperKitEngine에서 'setModelPhaseCallback:' setter가 제거되었어야 함"
        )
    }

    // MARK: - loadModel 시그니처 존재 확인 (컴파일 타임 검증)

    func test_loadModel_twoParamOverload_compiles() {
        // TranscriptionEngine 프로토콜 준수용 2-param 오버로드가 존재하는지 컴파일 타임 검증
        let _: (ModelIdentifier, (@Sendable (Float) -> Void)?) async throws -> Void = sut.loadModel(_:progressCallback:)
        // 컴파일 성공 자체가 테스트 통과
    }

    func test_loadModel_threeParamOverload_compiles() {
        // ModelManager 전용 3-param 오버로드가 존재하는지 컴파일 타임 검증
        let _: (ModelIdentifier, (@Sendable (Float) -> Void)?, (@Sendable (ModelLoadPhase) -> Void)?) async throws -> Void = sut.loadModel(_:progressCallback:phaseCallback:)
        // 컴파일 성공 자체가 테스트 통과
    }

    // MARK: - TranscriptionEngine 프로토콜 준수

    func test_conformsToTranscriptionEngine() {
        // WhisperKitEngine이 TranscriptionEngine 프로토콜을 준수하는지 확인
        XCTAssertTrue(sut is TranscriptionEngine)
    }

    func test_conformsToSendable() {
        // @unchecked Sendable 준수 확인: 다른 Task로 전달 가능
        let engine: any Sendable = sut as Any as! any Sendable
        XCTAssertNotNil(engine)
    }

    // MARK: - currentModel 초기 상태

    func test_currentModel_initiallyNil() {
        XCTAssertNil(sut.currentModel, "초기 상태에서 currentModel은 nil이어야 함")
    }

    // MARK: - unloadModel

    func test_unloadModel_setsCurrentModelToNil() async {
        // unloadModel 호출 후 currentModel이 nil이 되는지 확인
        // (모델이 로드되지 않은 상태에서도 크래시 없이 동작해야 한다)
        await sut.unloadModel()
        XCTAssertNil(sut.currentModel, "unloadModel 후 currentModel은 nil이어야 함")
    }

    func test_unloadModel_canBeCalledMultipleTimes() async {
        // 여러 번 호출해도 크래시하지 않아야 한다
        await sut.unloadModel()
        await sut.unloadModel()
        await sut.unloadModel()
        XCTAssertNil(sut.currentModel)
    }

    // MARK: - supportedModels

    func test_supportedModels_returnsNonEmptyArray() {
        let models = sut.supportedModels()
        XCTAssertFalse(models.isEmpty, "지원 모델 목록은 비어있지 않아야 함")
    }

    func test_supportedModels_alwaysContainsTiny() {
        // tiny 모델은 minimumRAMGB가 1이므로 어떤 환경에서든 포함되어야 한다
        let models = sut.supportedModels()
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        XCTAssertTrue(models.contains(tinyId), "tiny 모델은 항상 지원 목록에 포함되어야 함")
    }

    func test_supportedModels_containsOnlySupportedVariants() {
        // 반환되는 모든 모델이 DeviceCapability에서 지원하는 것인지 확인
        let models = sut.supportedModels()
        let capability = DeviceCapability.current
        for model in models {
            XCTAssertTrue(capability.supports(model), "\(model)이 지원 목록에 있지만 DeviceCapability에서 지원하지 않음")
        }
    }

    // MARK: - transcribe without loaded model

    func test_transcribe_withoutLoadedModel_throwsModelNotLoaded() async {
        // 모델이 로드되지 않은 상태에서 transcribe를 호출하면 modelNotLoaded 에러가 발생해야 한다
        let dummyURL = URL(fileURLWithPath: "/tmp/nonexistent.m4a")
        do {
            _ = try await sut.transcribe(audioURL: dummyURL, language: nil, progressCallback: nil)
            XCTFail("모델이 로드되지 않은 상태에서 transcribe가 성공해서는 안 됨")
        } catch let error as WhisperKitEngineError {
            if case .modelNotLoaded = error {
                // 예상대로
            } else {
                XCTFail("Expected .modelNotLoaded, got \(error)")
            }
        } catch {
            XCTFail("Expected WhisperKitEngineError, got \(type(of: error)): \(error)")
        }
    }

    // MARK: - WhisperKitEngineError

    func test_engineError_modelNotLoaded_errorDescription() {
        let error = WhisperKitEngineError.modelNotLoaded
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty, "에러 메시지가 비어있으면 안 됨")
    }

    func test_engineError_noResult_errorDescription() {
        let error = WhisperKitEngineError.noResult
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty, "에러 메시지가 비어있으면 안 됨")
    }

    func test_engineError_modelNotLoaded_isLocalizedError() {
        let error: Error = WhisperKitEngineError.modelNotLoaded
        XCTAssertTrue(error is LocalizedError, "WhisperKitEngineError는 LocalizedError를 준수해야 함")
    }

    func test_engineError_differentCasesHaveDifferentDescriptions() {
        let modelNotLoaded = WhisperKitEngineError.modelNotLoaded.errorDescription
        let noResult = WhisperKitEngineError.noResult.errorDescription
        XCTAssertNotEqual(modelNotLoaded, noResult, "다른 에러 케이스는 다른 메시지를 가져야 함")
    }

    func test_engineError_switchExhaustiveness() {
        // 모든 케이스가 커버되는지 컴파일 타임 검증
        let errors: [WhisperKitEngineError] = [.modelNotLoaded, .noResult]
        for error in errors {
            switch error {
            case .modelNotLoaded:
                XCTAssertEqual(error.errorDescription, "모델이 로드되지 않았습니다.")
            case .noResult:
                XCTAssertEqual(error.errorDescription, "전사 결과가 없습니다.")
            }
        }
    }
}
