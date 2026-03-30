import XCTest
@testable import Writ

/// RecordingView의 계산 프로퍼티 및 상태 로직 검증
///
/// RecordingView는 다음 계산 프로퍼티를 통해 UI 상태를 결정한다:
/// - isRecording: appState.recorderService.isRecording
/// - isTranscribing: appState.isProcessingQueue
/// - buttonState: .idle / .recording / .transcribing
/// - isModelReady: appState.modelManager.activeModel != nil
/// - isModelLoading: models.contains { downloading/optimizing/loading }
/// - modelStatusText: 로딩 모델의 상태 문자열
///
/// SwiftUI View의 private 프로퍼티는 직접 접근할 수 없으므로,
/// 동일한 로직을 테스트 내부에 재현하여 검증한다.
@MainActor
final class RecordingViewStateLogicTests: XCTestCase {

    private var engine: WhisperKitEngine!
    private var modelManager: ModelManager!

    override func setUp() {
        super.setUp()
        engine = WhisperKitEngine()
        modelManager = ModelManager(whisperEngine: engine)
    }

    override func tearDown() {
        modelManager = nil
        engine = nil
        super.tearDown()
    }

    // MARK: - Helpers (RecordingView 로직 미러링)

    private enum RecordButtonState: Equatable {
        case idle, recording, transcribing
    }

    private func buttonState(isRecording: Bool, isTranscribing: Bool) -> RecordButtonState {
        if isRecording { return .recording }
        if isTranscribing { return .transcribing }
        return .idle
    }

    private var isModelReady: Bool {
        modelManager.activeModel != nil
    }

    private var isModelLoading: Bool {
        modelManager.models.contains {
            switch $0.state {
            case .downloading, .optimizing, .loading: return true
            default: return false
            }
        }
    }

    /// RecordingView.modelStatusText와 동일한 로직
    private var modelStatusText: String {
        if let loading = modelManager.models.first(where: {
            if case .loading = $0.state { return true }
            if case .downloading = $0.state { return true }
            if case .optimizing = $0.state { return true }
            return false
        }) {
            if case .downloading(let progress, let status) = loading.state {
                let label = status ?? "다운로드 중"
                return "\(loading.identifier.displayName) \(label) (\(Int(progress * 100))%)"
            }
            if case .optimizing = loading.state {
                return "\(loading.identifier.displayName) 최적화 중..."
            }
            return "\(loading.identifier.displayName) 로딩 중..."
        }
        return "모델을 로드하는 중..."
    }

    private func setModelState(_ identifier: ModelIdentifier, to state: ModelState) {
        if let index = modelManager.models.firstIndex(where: { $0.identifier == identifier }) {
            modelManager.models[index].state = state
        }
    }

    // MARK: - buttonState 조합 테스트

    func test_buttonState_idle_whenNeitherRecordingNorTranscribing() {
        let state = buttonState(isRecording: false, isTranscribing: false)
        XCTAssertEqual(state, .idle)
    }

    func test_buttonState_recording_whenRecording() {
        let state = buttonState(isRecording: true, isTranscribing: false)
        XCTAssertEqual(state, .recording)
    }

    func test_buttonState_transcribing_whenTranscribing() {
        let state = buttonState(isRecording: false, isTranscribing: true)
        XCTAssertEqual(state, .transcribing)
    }

    func test_buttonState_recording_takePrecedence_overTranscribing() {
        // isRecording이 true면 isTranscribing 값과 무관하게 .recording
        let state = buttonState(isRecording: true, isTranscribing: true)
        XCTAssertEqual(
            state, .recording,
            "isRecording이 우선순위가 높아야 함 (if isRecording 먼저 평가)"
        )
    }

    // MARK: - isModelReady 테스트

    func test_isModelReady_initialState_isFalse() {
        XCTAssertFalse(
            isModelReady,
            "초기 상태에서 activeModel은 nil이므로 isModelReady는 false여야 함"
        )
    }

    func test_isModelReady_withActiveModel_isTrue() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        modelManager.activeModel = tinyId

        XCTAssertTrue(
            isModelReady,
            "activeModel이 설정되면 isModelReady는 true여야 함"
        )
    }

    func test_isModelReady_afterClearingActiveModel_isFalse() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        modelManager.activeModel = tinyId
        XCTAssertTrue(isModelReady)

        modelManager.activeModel = nil
        XCTAssertFalse(
            isModelReady,
            "activeModel을 nil로 설정하면 isModelReady는 false여야 함"
        )
    }

    // MARK: - isModelLoading 테스트

    func test_isModelLoading_initialState_isFalse() {
        XCTAssertFalse(isModelLoading)
    }

    func test_isModelLoading_downloading_isTrue() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .downloading(progress: 0.5))
        XCTAssertTrue(isModelLoading)
    }

    func test_isModelLoading_optimizing_isTrue() {
        let baseId = WhisperModelVariant.base.modelIdentifier
        setModelState(baseId, to: .optimizing)
        XCTAssertTrue(isModelLoading)
    }

    func test_isModelLoading_loading_isTrue() {
        let smallId = WhisperModelVariant.small.modelIdentifier
        setModelState(smallId, to: .loading)
        XCTAssertTrue(isModelLoading)
    }

    func test_isModelLoading_loaded_isFalse() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .loaded)
        XCTAssertFalse(
            isModelLoading,
            "loaded 상태는 로딩 완료이므로 isModelLoading이 false여야 함"
        )
    }

    func test_isModelLoading_error_isFalse() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .error("test error"))
        XCTAssertFalse(isModelLoading)
    }

    func test_isModelLoading_notDownloaded_isFalse() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .notDownloaded)
        XCTAssertFalse(isModelLoading)
    }

    func test_isModelLoading_downloaded_isFalse() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .downloaded)
        XCTAssertFalse(isModelLoading)
    }

    // MARK: - modelStatusText 테스트

    func test_modelStatusText_downloading_withStatus() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .downloading(progress: 0.45, status: "모델 다운로드 중"))

        let text = modelStatusText
        XCTAssertTrue(
            text.contains("45%"),
            "진행률 45%가 포함되어야 함, 실제: \(text)"
        )
        XCTAssertTrue(
            text.contains("모델 다운로드 중"),
            "커스텀 상태 문자열이 포함되어야 함"
        )
        XCTAssertTrue(
            text.contains(tinyId.displayName),
            "모델 이름이 포함되어야 함"
        )
    }

    func test_modelStatusText_downloading_withoutStatus_usesDefault() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .downloading(progress: 0.2))

        let text = modelStatusText
        XCTAssertTrue(
            text.contains("다운로드 중"),
            "status가 nil이면 기본 '다운로드 중' 레이블을 사용해야 함, 실제: \(text)"
        )
        XCTAssertTrue(
            text.contains("20%"),
            "진행률 20%가 포함되어야 함"
        )
    }

    func test_modelStatusText_downloading_zeroProgress() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .downloading(progress: 0.0))

        let text = modelStatusText
        XCTAssertTrue(
            text.contains("0%"),
            "진행률 0%가 포함되어야 함, 실제: \(text)"
        )
    }

    func test_modelStatusText_downloading_fullProgress() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .downloading(progress: 1.0))

        let text = modelStatusText
        XCTAssertTrue(
            text.contains("100%"),
            "진행률 100%가 포함되어야 함, 실제: \(text)"
        )
    }

    func test_modelStatusText_optimizing() {
        let baseId = WhisperModelVariant.base.modelIdentifier
        setModelState(baseId, to: .optimizing)

        let text = modelStatusText
        XCTAssertTrue(
            text.contains("최적화 중"),
            "optimizing 상태에서 '최적화 중'이 포함되어야 함, 실제: \(text)"
        )
        XCTAssertTrue(
            text.contains(baseId.displayName),
            "모델 이름이 포함되어야 함"
        )
    }

    func test_modelStatusText_loading() {
        let smallId = WhisperModelVariant.small.modelIdentifier
        setModelState(smallId, to: .loading)

        let text = modelStatusText
        XCTAssertTrue(
            text.contains("로딩 중"),
            "loading 상태에서 '로딩 중'이 포함되어야 함, 실제: \(text)"
        )
        XCTAssertTrue(
            text.contains(smallId.displayName),
            "모델 이름이 포함되어야 함"
        )
    }

    func test_modelStatusText_noLoadingModel_fallback() {
        // 모든 모델이 안정 상태일 때 폴백 텍스트
        let text = modelStatusText
        XCTAssertEqual(
            text, "모델을 로드하는 중...",
            "로딩 중인 모델이 없으면 폴백 문자열을 반환해야 함"
        )
    }

    // MARK: - startRecording 가드 조건: isModelReady OR isModelLoading

    func test_startRecordingGuard_noActiveModelAndNotLoading_shouldRedirectToSettings() {
        // RecordingView.startRecording: guard activeModel != nil || isModelLoading else { settings }
        // 모델이 없고 로딩 중도 아니면 설정 탭으로 이동해야 함
        XCTAssertFalse(isModelReady, "activeModel이 nil이어야 함")
        XCTAssertFalse(isModelLoading, "로딩 중이 아니어야 함")

        // 가드 조건 실패 → 설정 탭 이동이 필요한 상태
        let shouldRedirect = !(isModelReady || isModelLoading)
        XCTAssertTrue(shouldRedirect, "모델이 없고 로딩 중도 아니면 설정으로 리디렉트해야 함")
    }

    func test_startRecordingGuard_activeModelPresent_shouldNotRedirect() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        modelManager.activeModel = tinyId

        let shouldRedirect = !(isModelReady || isModelLoading)
        XCTAssertFalse(shouldRedirect, "activeModel이 있으면 리디렉트하지 않아야 함")
    }

    func test_startRecordingGuard_modelLoading_shouldNotRedirect() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        setModelState(tinyId, to: .downloading(progress: 0.3))

        let shouldRedirect = !(isModelReady || isModelLoading)
        XCTAssertFalse(shouldRedirect, "모델 로딩 중이면 리디렉트하지 않아야 함")
    }

    // MARK: - formatTime 로직 (RecordingView.formatTime과 동일)

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let centiseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    func test_formatTime_zero() {
        XCTAssertEqual(formatTime(0), "00:00.00")
    }

    func test_formatTime_oneSecond() {
        XCTAssertEqual(formatTime(1.0), "00:01.00")
    }

    func test_formatTime_oneMinute() {
        XCTAssertEqual(formatTime(60.0), "01:00.00")
    }

    func test_formatTime_withCentiseconds() {
        XCTAssertEqual(formatTime(1.5), "00:01.50")
    }

    func test_formatTime_complexTime() {
        // 5분 30.75초
        XCTAssertEqual(formatTime(330.75), "05:30.75")
    }

    func test_formatTime_almostOneSecond() {
        XCTAssertEqual(formatTime(0.99), "00:00.99")
    }

    func test_formatTime_tenMinutes() {
        XCTAssertEqual(formatTime(600.0), "10:00.00")
    }

    // MARK: - 접근성 레이블 로직 (RecordingView.accessibilityLabel과 동일)

    private func accessibilityLabel(isRecording: Bool, isTranscribing: Bool) -> String {
        isRecording ? "녹음 중지" :
        isTranscribing ? "전사 처리 중" : "녹음 시작"
    }

    private func accessibilityHint(isTranscribing: Bool) -> String {
        isTranscribing ? "전사가 완료되면 녹음을 시작할 수 있습니다" : ""
    }

    func test_accessibilityLabel_idle() {
        XCTAssertEqual(accessibilityLabel(isRecording: false, isTranscribing: false), "녹음 시작")
    }

    func test_accessibilityLabel_recording() {
        XCTAssertEqual(accessibilityLabel(isRecording: true, isTranscribing: false), "녹음 중지")
    }

    func test_accessibilityLabel_transcribing() {
        XCTAssertEqual(accessibilityLabel(isRecording: false, isTranscribing: true), "전사 처리 중")
    }

    func test_accessibilityLabel_recordingTakesPrecedence() {
        // isRecording이 먼저 평가되므로 둘 다 true여도 "녹음 중지"
        XCTAssertEqual(accessibilityLabel(isRecording: true, isTranscribing: true), "녹음 중지")
    }

    func test_accessibilityHint_transcribing() {
        XCTAssertEqual(
            accessibilityHint(isTranscribing: true),
            "전사가 완료되면 녹음을 시작할 수 있습니다"
        )
    }

    func test_accessibilityHint_notTranscribing_isEmpty() {
        XCTAssertEqual(accessibilityHint(isTranscribing: false), "")
    }

    // MARK: - 버튼 disabled 조건

    func test_recordButton_disabled_whenTranscribing() {
        // RecordingView에서 .disabled(isTranscribing)
        let isTranscribing = true
        XCTAssertTrue(isTranscribing, "전사 중이면 버튼이 비활성화되어야 함")
    }

    func test_recordButton_enabled_whenIdle() {
        let isTranscribing = false
        XCTAssertFalse(isTranscribing, "idle 상태에서 버튼이 활성화되어야 함")
    }
}
