import XCTest
@testable import Writ

/// 엔진 전환 시 메모리 관리 테스트
/// iPhone 14 Pro (6GB RAM) OOM 크래시 방지를 위한 검증:
/// 1. 모델 전환 시 이전 모델의 완전한 해제
/// 2. 같은 모델 재로드 시 이전 인스턴스 해제
/// 3. 엔진 간 전환 시 이전 엔진 모델 해제
///
/// 실제 ML 모델을 로드하지 않고 MockTranscriptionEngine을 사용하여
/// unload/load 패턴의 올바른 동작을 검증한다.
final class EngineMemoryManagementTests: XCTestCase {

    // MARK: - MockTranscriptionEngine unloadModel 호출 추적

    func test_mockEngine_unloadModel_incrementsCallCount() async {
        let engine = MockTranscriptionEngine()
        XCTAssertEqual(engine.unloadModelCallCount, 0)

        await engine.unloadModel()
        XCTAssertEqual(engine.unloadModelCallCount, 1)

        await engine.unloadModel()
        XCTAssertEqual(engine.unloadModelCallCount, 2)
    }

    func test_mockEngine_unloadModel_clearsCurrentModel() async {
        let engine = MockTranscriptionEngine()
        engine.stubbedCurrentModel = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "test",
            displayName: "Test",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )
        XCTAssertNotNil(engine.currentModel)

        await engine.unloadModel()
        XCTAssertNil(engine.currentModel,
                     "unloadModel 후 currentModel은 nil이어야 함")
    }

    // MARK: - 동일 엔진 내 모델 전환 시나리오

    func test_switchingModelsWithinSameEngine_previousModelShouldBeUnloaded() async {
        // 시나리오: 모델 A → 모델 B 전환 시
        // 이전 모델이 완전히 해제되어야 OOM이 발생하지 않음
        let engine = MockTranscriptionEngine()
        let firstModel = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "model-a",
            displayName: "Model A",
            diskSizeMB: 500,
            minimumRAMGB: 2
        )

        // 첫 번째 모델 "로드"
        try? await engine.loadModel(firstModel, progressCallback: nil)
        XCTAssertEqual(engine.currentModel, firstModel)
        XCTAssertEqual(engine.loadModelCallCount, 1)

        // 모델 전환 전 unload
        await engine.unloadModel()
        XCTAssertEqual(engine.unloadModelCallCount, 1)
        XCTAssertNil(engine.currentModel)

        // 두 번째 모델 "로드"
        let secondModel = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "model-b",
            displayName: "Model B",
            diskSizeMB: 300,
            minimumRAMGB: 1
        )
        try? await engine.loadModel(secondModel, progressCallback: nil)
        XCTAssertEqual(engine.currentModel, secondModel)
        XCTAssertEqual(engine.loadModelCallCount, 2)
    }

    // MARK: - unload → load → unload → load 반복 사이클

    func test_repeatedLoadUnloadCycles_doNotAccumulateState() async {
        let engine = MockTranscriptionEngine()
        let model = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "test-model",
            displayName: "Test",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )

        for cycle in 0..<5 {
            try? await engine.loadModel(model, progressCallback: nil)
            XCTAssertNotNil(engine.currentModel,
                           "사이클 \(cycle): loadModel 후 currentModel이 설정되어야 함")

            await engine.unloadModel()
            XCTAssertNil(engine.currentModel,
                        "사이클 \(cycle): unloadModel 후 currentModel이 nil이어야 함")
        }

        XCTAssertEqual(engine.loadModelCallCount, 5)
        XCTAssertEqual(engine.unloadModelCallCount, 5)
    }

    // MARK: - WhisperKitEngine unloadModel 동작 (실제 인스턴스)

    func test_whisperKitEngine_unloadModel_nilState_doesNotCrash() async {
        // 실제 WhisperKitEngine으로 nil 상태에서 unloadModel 호출
        // kit?.unloadModels()가 nil일 때 안전하게 무시되는지 검증
        let engine = WhisperKitEngine()
        XCTAssertNil(engine.currentModel)

        await engine.unloadModel()
        XCTAssertNil(engine.currentModel,
                     "nil 상태에서 unloadModel은 크래시 없이 nil을 유지해야 함")
    }

    func test_whisperKitEngine_multipleUnloads_doNotCrash() async {
        // kit?.unloadModels()가 nil일 때 반복 호출해도 안전한지 검증
        let engine = WhisperKitEngine()

        for _ in 0..<5 {
            await engine.unloadModel()
        }
        XCTAssertNil(engine.currentModel)
    }

    func test_whisperKitEngine_unloadThenTranscribe_throwsError() async {
        // unloadModels()로 CoreML 모델 해제 후 transcribe 불가 확인
        let engine = WhisperKitEngine()
        await engine.unloadModel()

        let dummyURL = URL(fileURLWithPath: "/tmp/test.m4a")
        do {
            _ = try await engine.transcribe(audioURL: dummyURL, language: nil, progressCallback: nil)
            XCTFail("unloadModel 후 transcribe가 성공해서는 안 됨")
        } catch is WhisperKitEngineError {
            // 예상대로: modelNotLoaded
        } catch {
            XCTFail("Expected WhisperKitEngineError, got \(type(of: error))")
        }
    }

    // MARK: - 엔진 전환 시뮬레이션 (MockTranscriptionEngine 사용)

    func test_engineSwitchSimulation_unloadCalledBeforeSwitch() async {
        // 엔진 전환 시 이전 엔진의 unloadModel이 호출되는 패턴 검증
        let engine1 = MockTranscriptionEngine()
        let engine2 = MockTranscriptionEngine()

        let model1 = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "whisper-tiny",
            displayName: "Tiny",
            diskSizeMB: 75,
            minimumRAMGB: 1
        )
        let model2 = ModelIdentifier(
            engine: .qwen3ASR,
            variantKey: "qwen-0.6b",
            displayName: "0.6B",
            diskSizeMB: 675,
            minimumRAMGB: 2
        )

        // 첫 번째 엔진으로 모델 로드
        try? await engine1.loadModel(model1, progressCallback: nil)
        XCTAssertNotNil(engine1.currentModel)

        // 엔진 전환: 이전 엔진 unload
        await engine1.unloadModel()
        XCTAssertEqual(engine1.unloadModelCallCount, 1)
        XCTAssertNil(engine1.currentModel)

        // 새 엔진으로 모델 로드
        try? await engine2.loadModel(model2, progressCallback: nil)
        XCTAssertNotNil(engine2.currentModel)

        // 다시 첫 번째 엔진으로 전환
        await engine2.unloadModel()
        XCTAssertEqual(engine2.unloadModelCallCount, 1)
        XCTAssertNil(engine2.currentModel)

        try? await engine1.loadModel(model1, progressCallback: nil)
        XCTAssertNotNil(engine1.currentModel)
    }

    // MARK: - 연속 전사 후 메모리 해제 시뮬레이션

    func test_consecutiveTranscriptions_engineRemainsUsable() async {
        // 같은 모델로 연속 전사 시 엔진이 정상 동작하는지 검증
        // (Qwen3ASREngine에서 Memory.clearCache() 호출 후에도 안정적이어야 함)
        let engine = MockTranscriptionEngine()
        let model = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "test",
            displayName: "Test",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )
        engine.transcribeResult = TranscriptionOutput(
            text: "테스트 결과",
            segments: [],
            language: "ko"
        )

        try? await engine.loadModel(model, progressCallback: nil)

        // 연속 5회 전사
        let dummyURL = URL(fileURLWithPath: "/tmp/test.m4a")
        for i in 0..<5 {
            let result = try? await engine.transcribe(
                audioURL: dummyURL,
                language: "ko",
                progressCallback: nil
            )
            XCTAssertEqual(result?.text, "테스트 결과",
                          "전사 \(i+1)회: 결과가 정상이어야 함")
        }
        XCTAssertEqual(engine.transcribeCallCount, 5)
        XCTAssertNotNil(engine.currentModel,
                       "연속 전사 후에도 모델이 로드된 상태를 유지해야 함")
    }

    // MARK: - 동시성 안전성

    func test_concurrentUnloadOnRealWhisperKitEngine_doesNotCrash() async {
        // 여러 Task에서 동시에 WhisperKitEngine.unloadModel을 호출해도 크래시하지 않아야 한다
        let engine = WhisperKitEngine()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await engine.unloadModel()
                }
            }
        }
        XCTAssertNil(engine.currentModel)
    }

    // MARK: - 전사 후 unload 시퀀스 (OOM 시나리오 재현)

    func test_transcribeFailThenUnload_doesNotCrash() async {
        // 전사 실패 후 unload 호출 시 크래시 없는지 검증
        // (실제 OOM 시나리오: 전사 중 메모리 부족 → unload → 재로드)
        let engine = MockTranscriptionEngine()
        engine.transcribeError = NSError(domain: "test", code: -1,
                                         userInfo: [NSLocalizedDescriptionKey: "OOM simulation"])

        let model = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "test",
            displayName: "Test",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )

        try? await engine.loadModel(model, progressCallback: nil)

        // 전사 실패
        let dummyURL = URL(fileURLWithPath: "/tmp/test.m4a")
        _ = try? await engine.transcribe(audioURL: dummyURL, language: nil, progressCallback: nil)
        XCTAssertEqual(engine.transcribeCallCount, 1)

        // unload (메모리 해제)
        await engine.unloadModel()
        XCTAssertNil(engine.currentModel)

        // 재로드 가능한지 확인
        engine.transcribeError = nil
        engine.transcribeResult = TranscriptionOutput(text: "복구됨", segments: [], language: nil)
        try? await engine.loadModel(model, progressCallback: nil)
        XCTAssertNotNil(engine.currentModel, "OOM 복구 후 재로드가 가능해야 함")

        let result = try? await engine.transcribe(
            audioURL: dummyURL,
            language: nil,
            progressCallback: nil
        )
        XCTAssertEqual(result?.text, "복구됨", "OOM 복구 후 전사가 정상 동작해야 함")
    }
}
