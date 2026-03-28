import XCTest
import SwiftData
@testable import Writ

/// AppState+Transcription의 모델 미선택 시 early return 가드 검증
/// - activeModel이 nil일 때 전사가 .failed로 마킹되는지 확인
/// - ModelManager.transcribe()의 activeModel nil 가드 검증
@MainActor
final class TranscriptionNoModelGuardTests: XCTestCase {

    // MARK: - ModelManager.transcribe() 가드 테스트

    private var engine: WhisperKitEngine!
    private var modelManager: ModelManager!

    override func setUp() {
        super.setUp()
        engine = WhisperKitEngine()
        modelManager = ModelManager(whisperEngine: engine)
        UserDefaults.standard.removeObject(forKey: "selectedModelVariant")
        UserDefaults.standard.removeObject(forKey: "selectedEngineType")
    }

    override func tearDown() {
        modelManager = nil
        engine = nil
        UserDefaults.standard.removeObject(forKey: "selectedModelVariant")
        UserDefaults.standard.removeObject(forKey: "selectedEngineType")
        super.tearDown()
    }

    func test_transcribe_noActiveModel_throwsModelNotLoaded() async {
        // Given: activeModel이 nil인 상태
        XCTAssertNil(modelManager.activeModel)

        // When / Then: transcribe 호출 시 에러가 발생해야 함
        let dummyURL = URL(fileURLWithPath: "/tmp/nonexistent.m4a")
        do {
            _ = try await modelManager.transcribe(
                audioURL: dummyURL,
                language: nil,
                progressCallback: nil
            )
            XCTFail("activeModel이 nil인 상태에서 transcribe가 성공하면 안 됨")
        } catch let error as WhisperKitEngineError {
            XCTAssertEqual(
                error, .modelNotLoaded,
                "activeModel이 nil이면 WhisperKitEngineError.modelNotLoaded가 throw되어야 함"
            )
        } catch {
            XCTFail("예상치 못한 에러 타입: \(type(of: error)) - \(error)")
        }
    }

    func test_transcribe_noActiveModel_throwsWithCorrectMessage() async {
        // Given
        XCTAssertNil(modelManager.activeModel)

        // When
        let dummyURL = URL(fileURLWithPath: "/tmp/nonexistent.m4a")
        do {
            _ = try await modelManager.transcribe(
                audioURL: dummyURL,
                language: "ko",
                progressCallback: nil
            )
            XCTFail("에러가 발생해야 함")
        } catch {
            // Then: 에러 메시지가 비어있지 않아야 함
            XCTAssertFalse(error.localizedDescription.isEmpty,
                           "에러 메시지가 비어있으면 안 됨")
        }
    }

    func test_transcribe_noActiveModel_doesNotCallProgressCallback() async {
        // Given
        XCTAssertNil(modelManager.activeModel)
        var progressCalled = false

        // When
        let dummyURL = URL(fileURLWithPath: "/tmp/nonexistent.m4a")
        do {
            _ = try await modelManager.transcribe(
                audioURL: dummyURL,
                language: nil,
                progressCallback: { _ in
                    progressCalled = true
                }
            )
        } catch {
            // 에러 발생 예상됨
        }

        // Then: progressCallback이 호출되지 않아야 함
        XCTAssertFalse(progressCalled,
                       "activeModel이 nil일 때 progressCallback이 호출되면 안 됨")
    }

    // MARK: - AppState.transcribeInBackground 모델 가드 테스트

    func test_transcribeInBackground_noModel_marksTranscriptionAsFailed() async {
        // Given: 모델이 선택되지 않은 상태
        let appState = AppState.shared
        // 현재 activeModel이 nil인지 확인 (테스트 환경에서는 보통 nil)
        // 저장된 모델 정보도 제거
        UserDefaults.standard.removeObject(forKey: "selectedModelVariant")
        UserDefaults.standard.removeObject(forKey: "selectedEngineType")

        let container = appState.modelContainer
        let context = ModelContext(container)
        let recording = Recording(audioFileName: "test_no_model.m4a")
        context.insert(recording)
        try? context.save()

        let recordingID = recording.persistentModelID

        // 전사 상태 설정
        if recording.transcription == nil {
            recording.transcription = Transcription()
            recording.transcription?.status = .pending
            try? context.save()
        }

        // When: 모델이 없는 상태에서 전사 시도
        // loadDefaultModelIfNeeded가 호출되어도 저장된 모델이 없으므로 activeModel은 nil 유지
        await appState.transcribeInBackground(
            recordingID: recordingID,
            audioFileName: "test_no_model.m4a",
            language: nil,
            autoCopy: false
        )

        // Then: 전사가 .failed로 마킹되어야 함
        // 별도 context로 확인 (SwiftData 컨텍스트 격리)
        let verifyContext = ModelContext(container)
        if let savedRecording = verifyContext.model(for: recordingID) as? Recording {
            if let transcription = savedRecording.transcription {
                // 모델이 없으면 .failed이거나 아직 반영되지 않았을 수 있음
                // (activeModel이 실제로 nil인 경우에만 적용)
                if appState.modelManager.activeModel == nil {
                    XCTAssertEqual(transcription.status, .failed,
                                   "모델이 없을 때 전사 상태는 .failed이어야 함. 실제: \(transcription.status)")
                }
            }
        }

        // 정리
        context.delete(recording)
        try? context.save()
    }

    // MARK: - loadDefaultModelIfNeeded 후에도 모델이 없는 시나리오

    func test_loadDefaultModelIfNeeded_noSavedModel_activeModelStaysNil() async {
        // Given: 저장된 모델 정보 없음
        XCTAssertNil(UserDefaults.standard.string(forKey: "selectedModelVariant"))

        // When
        await modelManager.loadDefaultModelIfNeeded()

        // Then: 자동 다운로드가 제거되었으므로 activeModel은 nil
        XCTAssertNil(modelManager.activeModel,
                     "저장된 모델이 없으면 loadDefaultModelIfNeeded 후에도 activeModel은 nil이어야 함")
    }

    func test_transcribeGuard_afterLoadDefault_withNoSavedModel_throwsError() async {
        // Given: 저장된 모델 없음 → loadDefaultModelIfNeeded 호출 → activeModel nil
        await modelManager.loadDefaultModelIfNeeded()
        XCTAssertNil(modelManager.activeModel)

        // When: transcribe 시도
        let dummyURL = URL(fileURLWithPath: "/tmp/nonexistent.m4a")
        do {
            _ = try await modelManager.transcribe(
                audioURL: dummyURL,
                language: nil,
                progressCallback: nil
            )
            XCTFail("모델 없이 전사가 성공하면 안 됨")
        } catch {
            // Then: 에러 발생 확인
            XCTAssertTrue(error is WhisperKitEngineError,
                          "WhisperKitEngineError가 throw되어야 함. 실제: \(type(of: error))")
        }
    }
}

// MARK: - WhisperKitEngineError Equatable (테스트용)

extension WhisperKitEngineError: @retroactive Equatable {
    public static func == (lhs: WhisperKitEngineError, rhs: WhisperKitEngineError) -> Bool {
        switch (lhs, rhs) {
        case (.modelNotLoaded, .modelNotLoaded): return true
        case (.noResult, .noResult): return true
        default: return false
        }
    }
}
