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
///    ↘ transcribing ↗ ↘ idle (cancel)  ↘ idle (fail)
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
    private var lastProgressUpdate: Date = .distantPast

    // MARK: - State Transitions

    /// 녹음 시작 → DI 표시
    func startRecording(startDate: Date) {
        guard phase == .idle else {
            logger.warning("startRecording ignored: phase=\(self.phase.rawValue)")
            return
        }

        phase = .recording
        recordingStartDate = startDate

        requestActivity(state: .recording(duration: 0, startDate: startDate, power: 0))
    }

    /// 녹음 → 전사 전환
    func transitionToTranscribing() {
        guard phase == .recording else {
            logger.warning("transitionToTranscribing ignored: phase=\(self.phase.rawValue)")
            return
        }

        phase = .transcribing
        lastProgressUpdate = .distantPast

        guard let activity = currentActivity else { return }
        let state = WritActivityAttributes.ContentState.transcribing()
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// 전사 진행률 업데이트 (1초 throttling — 빈번한 Activity update 방지)
    func updateProgress(_ progress: Float) {
        guard phase == .transcribing, let activity = currentActivity else { return }
        let now = Date()
        guard now.timeIntervalSince(lastProgressUpdate) >= 1.0 || progress >= 0.99 else { return }
        lastProgressUpdate = now
        let state = WritActivityAttributes.ContentState.transcribing(progress: progress)
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// 전사 → 완료 전환. DI에서 2초간 완료 상태를 보여준 후 종료.
    /// dismissalPolicy는 잠금 화면에만 영향 — DI는 end() 시 즉시 사라지므로 sleep으로 지연.
    /// phase는 즉시 idle로 전환하여 새 녹음 시작을 차단하지 않는다.
    func transitionToCompleted() {
        guard phase == .transcribing else {
            logger.warning("transitionToCompleted ignored: phase=\(self.phase.rawValue)")
            return
        }

        guard let activity = currentActivity else {
            phase = .idle
            return
        }

        currentActivity = nil
        phase = .idle

        let state = WritActivityAttributes.ContentState.completed()
        Task {
            await activity.update(.init(state: state, staleDate: nil))
            try? await Task.sleep(for: .seconds(2))
            await activity.end(
                .init(state: state, staleDate: nil),
                dismissalPolicy: .default
            )
        }
    }

    /// 큐 대기 항목 처리 시 idle→transcribing 직접 전환 (recording phase를 거치지 않음)
    func startTranscribingDirectly() {
        guard phase == .idle else {
            logger.warning("startTranscribingDirectly ignored: phase=\(self.phase.rawValue)")
            return
        }

        phase = .transcribing
        lastProgressUpdate = .distantPast

        requestActivity(state: .transcribing())
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

    // MARK: - Private Helpers

    /// Activity.request 공통 패턴
    private func requestActivity(state: WritActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
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
