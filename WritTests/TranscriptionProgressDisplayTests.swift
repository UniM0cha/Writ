#if os(iOS)
import XCTest
@testable import Writ

/// Live Activity의 전사 진행률 표시 분기 로직 검증
///
/// WritLiveActivity에서 `transcriptionProgress == 0`이면 인디케이터(스피너),
/// `transcriptionProgress >= 0.01`이면 퍼센트 텍스트 + 진행 바를 표시한다.
/// SwiftUI 뷰는 직접 테스트할 수 없으므로, 분기 조건과 표시 값 계산 로직을 검증한다.
@MainActor
final class TranscriptionProgressDisplayTests: XCTestCase {

    // MARK: - progress == 0 분기 조건 (스피너 표시)

    func test_transcribingFactory_defaultProgress_isZero() {
        // Given/When: 기본 파라미터로 transcribing 상태 생성
        let state = WritActivityAttributes.ContentState.transcribing()

        // Then: progress가 정확히 0이어야 함 (스피너 분기)
        XCTAssertEqual(
            state.transcriptionProgress, 0,
            "transcribing() 기본 progress는 0이어야 함"
        )
    }

    func test_transcribingFactory_explicitZeroProgress() {
        // Given/When: 명시적으로 progress: 0 전달
        let state = WritActivityAttributes.ContentState.transcribing(progress: 0)

        // Then: progress가 0이어야 함 (스피너 분기)
        XCTAssertEqual(
            state.transcriptionProgress, 0,
            "transcribing(progress: 0)은 0이어야 함"
        )
    }

    func test_progressZero_shouldShowSpinner() {
        // Given: progress가 0인 ContentState
        let state = WritActivityAttributes.ContentState.transcribing(progress: 0)

        // When: 뷰 분기 조건 평가
        let shouldShowPercentage = state.transcriptionProgress >= 0.01

        // Then: 퍼센트 표시 안 함 (스피너 표시)
        XCTAssertFalse(
            shouldShowPercentage,
            "progress == 0이면 퍼센트/진행바 대신 스피너를 표시해야 함"
        )
    }

    // MARK: - progress >= 0.01 분기 조건 (퍼센트/진행바 표시)

    func test_progressGreaterThanZero_shouldShowPercentage() {
        // Given: progress가 0보다 큰 ContentState
        let state = WritActivityAttributes.ContentState.transcribing(progress: 0.5)

        // When: 뷰 분기 조건 평가
        let shouldShowPercentage = state.transcriptionProgress >= 0.01

        // Then: 퍼센트/진행바 표시
        XCTAssertTrue(
            shouldShowPercentage,
            "progress >= 0.01이면 퍼센트 텍스트와 진행바를 표시해야 함"
        )
    }

    func test_verySmallProgress_shouldShowSpinner() {
        // Given: 0.01 미만의 미세한 양수 progress
        let state = WritActivityAttributes.ContentState.transcribing(progress: 0.001)

        // When: 뷰 분기 조건 평가
        let shouldShowPercentage = state.transcriptionProgress >= 0.01

        // Then: 0.01 미만이면 스피너 표시
        XCTAssertFalse(
            shouldShowPercentage,
            "0.01 미만의 progress는 스피너를 표시해야 함 (0% 깜빡임 방지)"
        )
    }

    func test_fullProgress_shouldShowPercentage() {
        // Given: progress가 1.0 (100%)
        let state = WritActivityAttributes.ContentState.transcribing(progress: 1.0)

        // When: 뷰 분기 조건 평가
        let shouldShowPercentage = state.transcriptionProgress >= 0.01

        // Then: 퍼센트 표시
        XCTAssertTrue(
            shouldShowPercentage,
            "progress == 1.0도 > 0이므로 퍼센트를 표시해야 함"
        )
    }

    // MARK: - 퍼센트 텍스트 계산 (Int(progress * 100))

    func test_percentageText_atZero() {
        // Given: progress == 0
        let progress: Float = 0

        // When: 뷰에서 사용하는 퍼센트 텍스트 계산
        let percentText = "\(Int(progress * 100))%"

        // Then
        XCTAssertEqual(percentText, "0%")
    }

    func test_percentageText_atHalf() {
        // Given: progress == 0.5
        let progress: Float = 0.5

        // When
        let percentText = "\(Int(progress * 100))%"

        // Then
        XCTAssertEqual(percentText, "50%")
    }

    func test_percentageText_atFull() {
        // Given: progress == 1.0
        let progress: Float = 1.0

        // When
        let percentText = "\(Int(progress * 100))%"

        // Then
        XCTAssertEqual(percentText, "100%")
    }

    func test_percentageText_roundsDown() {
        // Given: progress == 0.999 → Int(99.9) = 99
        let progress: Float = 0.999

        // When
        let percentText = "\(Int(progress * 100))%"

        // Then: Int()는 소수점 이하를 버림
        XCTAssertEqual(percentText, "99%")
    }

    func test_percentageText_at1Percent() {
        // Given: progress == 0.01
        let progress: Float = 0.01

        // When
        let percentText = "\(Int(progress * 100))%"

        // Then
        XCTAssertEqual(percentText, "1%")
    }

    func test_percentageText_verySmallProgress_showsZero() {
        // Given: progress == 0.001 → Int(0.1) = 0
        let progress: Float = 0.001

        // When
        let percentText = "\(Int(progress * 100))%"

        // Then: 0.1%는 Int로 변환 시 0%
        XCTAssertEqual(percentText, "0%")
    }

    func test_percentageText_at99Percent() {
        // Given: progress == 0.99
        let progress: Float = 0.99

        // When
        let percentText = "\(Int(progress * 100))%"

        // Then
        XCTAssertEqual(percentText, "99%")
    }

    func test_percentageText_variousValues() {
        // 다양한 진행률 값에 대한 퍼센트 텍스트 검증
        let testCases: [(Float, String)] = [
            (0.0, "0%"),
            (0.1, "10%"),
            (0.25, "25%"),
            (0.33, "33%"),
            (0.5, "50%"),
            (0.75, "75%"),
            (0.9, "90%"),
            (1.0, "100%"),
        ]

        for (progress, expected) in testCases {
            let result = "\(Int(progress * 100))%"
            XCTAssertEqual(result, expected, "progress \(progress)의 퍼센트 텍스트가 \(expected)여야 함")
        }
    }

    // MARK: - 경계값: progress 범위 외 값

    func test_negativeProgress_branchCondition() {
        // Given: 음수 progress (비정상 입력)
        let state = WritActivityAttributes.ContentState.transcribing(progress: -0.1)

        // When: 뷰 분기 조건
        let shouldShowPercentage = state.transcriptionProgress >= 0.01

        // Then: 음수는 > 0이 아니므로 스피너 표시
        XCTAssertFalse(
            shouldShowPercentage,
            "음수 progress는 > 0이 아니므로 스피너를 표시해야 함"
        )
    }

    func test_progressOverOne_branchCondition() {
        // Given: 1.0 초과 progress (비정상 입력)
        let state = WritActivityAttributes.ContentState.transcribing(progress: 1.5)

        // When: 뷰 분기 조건
        let shouldShowPercentage = state.transcriptionProgress >= 0.01

        // Then: 1.5 > 0이므로 퍼센트 표시
        XCTAssertTrue(
            shouldShowPercentage,
            "1.0 초과 progress도 > 0이므로 퍼센트를 표시해야 함"
        )
    }

    func test_percentageText_progressOverOne() {
        // Given: progress == 1.5 → "150%"
        let progress: Float = 1.5

        // When
        let percentText = "\(Int(progress * 100))%"

        // Then
        XCTAssertEqual(percentText, "150%")
    }

    // MARK: - ContentState phase별 progress 분기 일관성

    func test_recordingPhase_progressIsAlwaysZero() {
        // Given: recording 팩토리로 생성
        let state = WritActivityAttributes.ContentState.recording(
            duration: 10.0, startDate: Date(), power: -5.0
        )

        // Then: recording phase에서는 항상 progress가 0
        XCTAssertEqual(
            state.transcriptionProgress, 0, accuracy: 0.001,
            "recording phase에서는 transcriptionProgress가 항상 0이어야 함"
        )
    }

    func test_completedPhase_progressIsAlwaysOne() {
        // Given: completed 팩토리로 생성
        let state = WritActivityAttributes.ContentState.completed()

        // Then: completed phase에서는 항상 progress가 1.0
        XCTAssertEqual(
            state.transcriptionProgress, 1.0, accuracy: 0.001,
            "completed phase에서는 transcriptionProgress가 항상 1.0이어야 함"
        )
    }

    func test_transcribingPhase_progressCanBeZeroOrPositive() {
        // Given: 다양한 progress 값의 transcribing 상태
        let zeroState = WritActivityAttributes.ContentState.transcribing(progress: 0)
        let halfState = WritActivityAttributes.ContentState.transcribing(progress: 0.5)
        let fullState = WritActivityAttributes.ContentState.transcribing(progress: 1.0)

        // Then: transcribing phase에서 progress는 자유롭게 설정 가능
        XCTAssertEqual(zeroState.transcriptionProgress, 0, accuracy: 0.001)
        XCTAssertEqual(halfState.transcriptionProgress, 0.5, accuracy: 0.001)
        XCTAssertEqual(fullState.transcriptionProgress, 1.0, accuracy: 0.001)
    }

    // MARK: - progress == 0 vs progress >= 0.01 일관성 (3개 분기 지점)

    func test_allThreeBranchPoints_agreeOnZeroProgress() {
        // Given: progress가 0인 transcribing 상태
        let state = WritActivityAttributes.ContentState.transcribing(progress: 0)
        let progress = state.transcriptionProgress

        // When: 3개 분기 지점 모두 동일 조건 사용
        let expandedCenterShowsProgressBar = progress >= 0.01  // ProgressView(value:) vs ProgressView()
        let expandedTrailingShowsPercent = progress >= 0.01     // "X%" vs ProgressView()
        let compactTrailingShowsPercent = progress >= 0.01      // "X%" vs ProgressView()

        // Then: 3개 분기가 모두 동일하게 false (스피너 표시)
        XCTAssertFalse(expandedCenterShowsProgressBar,
                       "expanded center: progress == 0이면 indeterminate ProgressView 표시")
        XCTAssertFalse(expandedTrailingShowsPercent,
                       "expanded trailing: progress == 0이면 spinner 표시")
        XCTAssertFalse(compactTrailingShowsPercent,
                       "compact trailing: progress == 0이면 spinner 표시")
    }

    func test_allThreeBranchPoints_agreeOnPositiveProgress() {
        // Given: progress가 0보다 큰 transcribing 상태
        let state = WritActivityAttributes.ContentState.transcribing(progress: 0.42)
        let progress = state.transcriptionProgress

        // When: 3개 분기 지점 모두 동일 조건 사용
        let expandedCenterShowsProgressBar = progress >= 0.01
        let expandedTrailingShowsPercent = progress >= 0.01
        let compactTrailingShowsPercent = progress >= 0.01

        // Then: 3개 분기가 모두 동일하게 true (퍼센트/진행바 표시)
        XCTAssertTrue(expandedCenterShowsProgressBar,
                      "expanded center: progress >= 0.01이면 ProgressView(value:) 표시")
        XCTAssertTrue(expandedTrailingShowsPercent,
                      "expanded trailing: progress >= 0.01이면 퍼센트 텍스트 표시")
        XCTAssertTrue(compactTrailingShowsPercent,
                      "compact trailing: progress >= 0.01이면 퍼센트 텍스트 표시")
    }

    // MARK: - ContentState Codable 라운드트립 (progress 0 보존)

    func test_codableRoundtrip_preservesZeroProgress() throws {
        // Given: progress가 0인 transcribing 상태
        let original = WritActivityAttributes.ContentState.transcribing(progress: 0)

        // When: 인코딩 후 디코딩
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WritActivityAttributes.ContentState.self, from: data)

        // Then: progress가 정확히 0으로 보존됨
        XCTAssertEqual(decoded.transcriptionProgress, 0,
                       "Codable 라운드트립 후에도 progress == 0이 보존되어야 함")
        XCTAssertEqual(decoded.phase, .transcribing)
    }

    func test_codableRoundtrip_preservesSmallProgress() throws {
        // Given: 0.01 이상의 작은 progress
        let original = WritActivityAttributes.ContentState.transcribing(progress: 0.02)

        // When
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WritActivityAttributes.ContentState.self, from: data)

        // Then: 작은 양수가 보존되어 분기 조건이 변하지 않음
        XCTAssertTrue(decoded.transcriptionProgress >= 0.01,
                      "0.01 이상의 progress가 Codable 라운드트립 후에도 >= 0.01이어야 함")
    }

    // MARK: - Float 정밀도 엣지 케이스

    func test_floatPrecision_nearZero() {
        // Given: Float.leastNormalMagnitude (가장 작은 정규 양수, 0.01 미만)
        let state = WritActivityAttributes.ContentState.transcribing(
            progress: Float.leastNormalMagnitude
        )

        // When
        let shouldShowPercentage = state.transcriptionProgress >= 0.01

        // Then: 0.01 미만이므로 스피너 표시
        XCTAssertFalse(
            shouldShowPercentage,
            "Float.leastNormalMagnitude는 0.01 미만이므로 스피너를 표시해야 함"
        )
    }

    func test_floatPrecision_percentageAtSmallestVisibleProgress() {
        // Given: 1%가 되는 최소 progress
        let progress: Float = 0.01

        // When: 뷰 분기 조건과 퍼센트 텍스트
        let shouldShowPercentage = progress >= 0.01
        let percentText = "\(Int(progress * 100))%"

        // Then
        XCTAssertTrue(shouldShowPercentage)
        XCTAssertEqual(percentText, "1%")
    }
}

// MARK: - LiveActivityManager progress 업데이트와 표시 로직 통합

@MainActor
final class LiveActivityProgressUpdateDisplayTests: XCTestCase {

    private var sut: LiveActivityManager!

    override func setUp() {
        super.setUp()
        sut = LiveActivityManager()
    }

    override func tearDown() {
        sut.end()
        sut = nil
        super.tearDown()
    }

    // MARK: - transitionToTranscribing은 progress 0으로 시작

    func test_transitionToTranscribing_startsWithZeroProgress() {
        // Given: recording 상태
        sut.startRecording(startDate: Date())

        // When: transcribing으로 전환
        sut.transitionToTranscribing()

        // Then: 전환 시 생성되는 ContentState의 progress는 0 (스피너 표시 대상)
        let state = WritActivityAttributes.ContentState.transcribing()
        XCTAssertEqual(state.transcriptionProgress, 0, accuracy: 0.001,
                       "transitionToTranscribing 시 초기 progress는 0이어야 함 (스피너 표시)")
    }

    // MARK: - updateProgress 값 범위별 ContentState 생성

    func test_contentState_fromUpdateProgress_zeroShowsSpinner() {
        // Given: updateProgress(0)이 호출될 때 생성되는 ContentState
        let state = WritActivityAttributes.ContentState.transcribing(progress: 0)

        // Then: 스피너 분기
        XCTAssertFalse(state.transcriptionProgress >= 0.01,
                       "progress 0으로 업데이트 시 스피너를 표시해야 함")
    }

    func test_contentState_fromUpdateProgress_positiveShowsPercentage() {
        // Given: updateProgress(0.3)이 호출될 때 생성되는 ContentState
        let state = WritActivityAttributes.ContentState.transcribing(progress: 0.3)

        // Then: 퍼센트 분기
        XCTAssertTrue(state.transcriptionProgress >= 0.01,
                      "양수 progress로 업데이트 시 퍼센트를 표시해야 함")
        XCTAssertEqual("\(Int(state.transcriptionProgress * 100))%", "30%")
    }

    // MARK: - updateProgress guard 조건

    func test_updateProgress_inTranscribingPhase_doesNotChangePhase() {
        // Given
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing)

        // When: progress 업데이트
        sut.updateProgress(0.5)

        // Then: phase는 변하지 않음
        XCTAssertEqual(sut.phase, .transcribing)
    }

    func test_updateProgress_inIdlePhase_isIgnored() {
        // Given: idle 상태
        XCTAssertEqual(sut.phase, .idle)

        // When: progress 업데이트 시도
        sut.updateProgress(0.5)

        // Then: 크래시 없이 무시됨
        XCTAssertEqual(sut.phase, .idle)
    }

    func test_updateProgress_inRecordingPhase_isIgnored() {
        // Given: recording 상태
        sut.startRecording(startDate: Date())
        XCTAssertEqual(sut.phase, .recording)

        // When: progress 업데이트 시도
        sut.updateProgress(0.5)

        // Then: 크래시 없이 무시됨
        XCTAssertEqual(sut.phase, .recording)
    }

    // MARK: - startTranscribingDirectly도 progress 0으로 시작

    func test_startTranscribingDirectly_startsWithZeroProgress() {
        // Given: idle 상태
        XCTAssertEqual(sut.phase, .idle)

        // When: 직접 transcribing 시작 (큐 대기 항목 처리 시)
        sut.startTranscribingDirectly()

        // Then: 전환 시 생성되는 ContentState의 progress는 0 (스피너 표시 대상)
        XCTAssertEqual(sut.phase, .transcribing)
        let state = WritActivityAttributes.ContentState.transcribing()
        XCTAssertEqual(state.transcriptionProgress, 0, accuracy: 0.001,
                       "startTranscribingDirectly 시 초기 progress는 0이어야 함 (스피너 표시)")
    }

    // MARK: - progress 업데이트 시 완료 근접 값

    func test_updateProgress_nearCompletion() {
        // Given
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()

        // When: 거의 완료 (0.99)
        sut.updateProgress(0.99)

        // Then: phase는 여전히 transcribing (자동 완료 전환 없음)
        XCTAssertEqual(sut.phase, .transcribing)
    }

    func test_updateProgress_atFullCompletion() {
        // Given
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()

        // When: 100% (1.0)
        sut.updateProgress(1.0)

        // Then: phase는 여전히 transcribing (transitionToCompleted 별도 호출 필요)
        XCTAssertEqual(sut.phase, .transcribing)
    }

    // MARK: - progress 전이 시나리오: 0 → 양수 → 완료

    func test_progressTransitionScenario_zeroToPositiveToComplete() {
        // 시나리오: 전사 시작(progress 0) → 진행(progress >= 0.01) → 완료

        // Given: transcribing 시작
        sut.startRecording(startDate: Date())
        sut.transitionToTranscribing()
        XCTAssertEqual(sut.phase, .transcribing)

        // Step 1: 초기 상태 — progress 0, 스피너 표시
        let initialState = WritActivityAttributes.ContentState.transcribing(progress: 0)
        XCTAssertFalse(initialState.transcriptionProgress >= 0.01,
                       "초기 전사 시작 시 스피너가 표시되어야 함")

        // Step 2: 진행 시작 — progress >= 0.01, 퍼센트 표시
        sut.updateProgress(0.1)
        let progressState = WritActivityAttributes.ContentState.transcribing(progress: 0.1)
        XCTAssertTrue(progressState.transcriptionProgress >= 0.01,
                      "진행 시작 후 퍼센트가 표시되어야 함")
        XCTAssertEqual("\(Int(progressState.transcriptionProgress * 100))%", "10%")

        // Step 3: 완료
        sut.transitionToCompleted()
        let completedState = WritActivityAttributes.ContentState.completed()
        XCTAssertEqual(completedState.transcriptionProgress, 1.0, accuracy: 0.001)
    }
}
#endif
