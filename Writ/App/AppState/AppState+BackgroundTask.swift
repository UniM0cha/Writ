#if os(iOS)
import Foundation
import SwiftData
import BackgroundTasks

// MARK: - BGContinuedProcessingTask Handler

extension AppState {
    func performBGTranscription(bgTask: BGContinuedProcessingTask) async {
        guard !transcriptionQueue.isEmpty else {
            bgTask.setTaskCompleted(success: false)
            return
        }
        activeBGTask = bgTask

        // expiration handler: 진행 중인 전사를 pending으로 되돌림
        let container = modelContainer
        bgTask.expirationHandler = { @Sendable [weak bgTask] in
            Task { @MainActor in
                let appState = AppState.shared
                // 진행 중인 전사를 pending으로 복원
                let ctx = ModelContext(container)
                for id in appState.activeTranscriptionIDs {
                    if let rec = ctx.model(for: id) as? Recording,
                       rec.transcription?.status == .inProgress {
                        rec.transcription?.status = .pending
                    }
                }
                try? ctx.save()
                appState.activeBGTask = nil
                bgTask?.setTaskCompleted(success: false)
            }
        }
        bgTask.progress.totalUnitCount = 100
        bgTask.progress.completedUnitCount = 0

        await processNextInQueue()

        // expiration handler에서 이미 처리되지 않은 경우에만 완료 처리
        if activeBGTask != nil {
            bgTask.setTaskCompleted(success: true)
            activeBGTask = nil
        }
    }
}
#endif
