#if os(iOS)
import ActivityKit
import Foundation
import os

private let logger = Logger(subsystem: AppGroupConstants.logSubsystem, category: "LiveActivity")

/// Live Activity 상태머신. DI 생애주기를 명시적으로 관리.
///
/// 상태 전이:
/// ```
/// idle → recording → transcribing → completed → idle
///                  ↘ idle (cancel)  ↘ idle (fail)
/// ```
@MainActor
final class LiveActivityManager: ObservableObject {
    enum Phase: String {
        case idle
        case recording
        case transcribing
        case completed
    }

    @Published private(set) var phase: Phase = .idle

    private var currentActivity: Activity<WritActivityAttributes>?
    private var recordingStartDate: Date?

    // MARK: - State Transitions

    /// 녹음 시작 → DI 표시
    func startRecording(startDate: Date) {
        guard phase == .idle else {
            logger.warning("startRecording ignored: phase=\(self.phase.rawValue)")
            return
        }

        phase = .recording
        recordingStartDate = startDate

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activities disabled by user")
            return
        }

        let state = WritActivityAttributes.ContentState.recording(
            duration: 0, startDate: startDate, power: 0
        )
        do {
            let activity = try Activity.request(
                attributes: WritActivityAttributes(),
                content: .init(state: state, staleDate: nil)
            )
            currentActivity = activity
            logger.debug("Activity started: \(activity.id)")
        } catch {
            logger.error("Activity.request failed: \(error)")
        }
    }

    /// 녹음 → 전사 전환
    func transitionToTranscribing() {
        guard phase == .recording else {
            logger.warning("transitionToTranscribing ignored: phase=\(self.phase.rawValue)")
            return
        }

        phase = .transcribing

        guard let activity = currentActivity else { return }
        let state = WritActivityAttributes.ContentState.transcribing()
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// 전사 진행률 업데이트
    func updateProgress(_ progress: Float) {
        guard phase == .transcribing, let activity = currentActivity else { return }
        let state = WritActivityAttributes.ContentState.transcribing(progress: progress)
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// 전사 → 완료 전환. 2초 후 자동 종료.
    func transitionToCompleted() {
        guard phase == .transcribing else {
            logger.warning("transitionToCompleted ignored: phase=\(self.phase.rawValue)")
            return
        }

        phase = .completed

        guard let activity = currentActivity else {
            phase = .idle
            return
        }

        currentActivity = nil
        let state = WritActivityAttributes.ContentState.completed()
        Task {
            await activity.update(.init(state: state, staleDate: nil))
            await activity.end(
                .init(state: state, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(2))
            )
            self.phase = .idle
        }
    }

    /// 즉시 종료 (취소/에러). 어떤 phase에서든 호출 가능.
    func end() {
        if let activity = currentActivity {
            let state = WritActivityAttributes.ContentState.completed()
            Task {
                await activity.end(
                    .init(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
            currentActivity = nil
        }

        phase = .idle
        recordingStartDate = nil
    }

    // MARK: - Orphaned Activity 정리

    /// 앱 시작 시 이전 세션의 남은 Activity를 모두 종료
    func cleanupOrphanedActivities() async {
        let activities = Activity<WritActivityAttributes>.activities
        guard !activities.isEmpty else { return }

        logger.info("Cleaning up \(activities.count) orphaned activities")
        for activity in activities {
            await activity.end(
                .init(state: .completed(), staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        currentActivity = nil
        phase = .idle
    }

}
#endif
