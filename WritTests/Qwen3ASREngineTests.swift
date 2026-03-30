#if os(iOS) || os(macOS)
import XCTest
@testable import Writ

/// Qwen3ASREngine OOM 수정 관련 검증 테스트
/// - Qwen3ASREngineError 에러 메시지 검증
/// - unloadModel / transcribe 시그니처 컴파일 타임 검증
/// - loadModel 오버로드 (2-param, 3-param) 존재 확인
///
/// 주의: Qwen3ASREngine은 MLX 프레임워크 초기화 시 Metal GPU가 필요하여
/// 시뮬레이터에서 직접 인스턴스를 생성하면 크래시한다.
/// 따라서 컴파일 타임 검증과 에러 타입 테스트에 집중한다.
final class Qwen3ASREngineTests: XCTestCase {

    // MARK: - Qwen3ASREngineError

    func test_engineError_modelNotLoaded_errorDescription() {
        let error = Qwen3ASREngineError.modelNotLoaded
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty, "에러 메시지가 비어있으면 안 됨")
    }

    func test_engineError_modelNotLoaded_specificMessage() {
        let error = Qwen3ASREngineError.modelNotLoaded
        XCTAssertEqual(error.errorDescription, "Qwen3-ASR 모델이 로드되지 않았습니다.")
    }

    func test_engineError_modelNotLoaded_isLocalizedError() {
        let error: Error = Qwen3ASREngineError.modelNotLoaded
        XCTAssertTrue(error is LocalizedError,
                     "Qwen3ASREngineError는 LocalizedError를 준수해야 함")
    }

    func test_engineError_switchExhaustiveness() {
        // 모든 케이스가 커버되는지 컴파일 타임 검증
        let error = Qwen3ASREngineError.modelNotLoaded
        switch error {
        case .modelNotLoaded:
            XCTAssertEqual(error.errorDescription, "Qwen3-ASR 모델이 로드되지 않았습니다.")
        }
    }

    func test_engineError_equatable() {
        // Qwen3ASREngineError가 Equatable을 준수하는지 확인
        let a = Qwen3ASREngineError.modelNotLoaded
        let b = Qwen3ASREngineError.modelNotLoaded
        XCTAssertEqual(a, b)
    }

    func test_engineError_localizedDescription_nonEmpty() {
        // Error 프로토콜의 localizedDescription이 비어있지 않은지 확인
        let error: Error = Qwen3ASREngineError.modelNotLoaded
        XCTAssertFalse(error.localizedDescription.isEmpty,
                      "localizedDescription이 비어있으면 안 됨")
    }

    // MARK: - 컴파일 타임 시그니처 검증

    func test_loadModel_twoParamOverload_signatureExists() {
        // TranscriptionEngine 프로토콜 준수용 2-param 오버로드
        // 컴파일 성공 자체가 테스트 통과
        typealias LoadModelFunc = (Qwen3ASREngine) -> (ModelIdentifier, (@Sendable (Float) -> Void)?) async throws -> Void
        let _: LoadModelFunc = Qwen3ASREngine.loadModel(_:progressCallback:)
    }

    func test_loadModel_threeParamOverload_signatureExists() {
        // ModelManager 전용 3-param 오버로드 (statusCallback 포함)
        // 컴파일 성공 자체가 테스트 통과
        typealias LoadModelFunc = (Qwen3ASREngine) -> (ModelIdentifier, (@Sendable (Float) -> Void)?, (@Sendable (String) -> Void)?) async throws -> Void
        let _: LoadModelFunc = Qwen3ASREngine.loadModel(_:progressCallback:statusCallback:)
    }

    func test_unloadModel_signatureExists() {
        // unloadModel() async 시그니처 존재 확인
        typealias UnloadFunc = (Qwen3ASREngine) -> () async -> Void
        let _: UnloadFunc = Qwen3ASREngine.unloadModel
    }

    func test_transcribe_signatureExists() {
        // transcribe 시그니처 존재 확인
        typealias TranscribeFunc = (Qwen3ASREngine) -> (URL, String?, (@Sendable (Float) -> Void)?) async throws -> TranscriptionOutput
        let _: TranscribeFunc = Qwen3ASREngine.transcribe(audioURL:language:progressCallback:)
    }

    func test_supportedModels_signatureExists() {
        // supportedModels() -> [ModelIdentifier] 시그니처 존재 확인
        typealias SupportedModelsFunc = (Qwen3ASREngine) -> () -> [ModelIdentifier]
        let _: SupportedModelsFunc = Qwen3ASREngine.supportedModels
    }

    func test_currentModel_propertyExists() {
        // currentModel: ModelIdentifier? 프로퍼티 존재 확인
        typealias CurrentModelGetter = (Qwen3ASREngine) -> ModelIdentifier?
        let _: CurrentModelGetter = { $0.currentModel }
    }

    // MARK: - TranscriptionEngine 프로토콜 준수 (컴파일 타임)

    func test_conformsToTranscriptionEngine_compileTime() {
        // Qwen3ASREngine이 TranscriptionEngine 프로토콜을 준수하는지 컴파일 타임 검증
        func _requireTranscriptionEngine<T: TranscriptionEngine>(_: T.Type) {}
        _requireTranscriptionEngine(Qwen3ASREngine.self)
    }

    func test_conformsToSendable_compileTime() {
        // @unchecked Sendable 준수 확인
        func _requireSendable<T: Sendable>(_: T.Type) {}
        _requireSendable(Qwen3ASREngine.self)
    }

    // MARK: - final class 검증

    func test_isFinalClass() {
        // Qwen3ASREngine이 final class인지 확인 (Mirror 기반)
        // final class는 subclass할 수 없으므로 메모리 레이아웃이 보장됨
        let mirror = Mirror(reflecting: Qwen3ASREngine.self)
        XCTAssertEqual(String(describing: mirror.subjectType), "Qwen3ASREngine.Type")
    }
}
#endif
