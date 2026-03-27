import Foundation
import SwiftData

// MARK: - 전사 큐 처리

extension AppState {
    /// 큐에서 항목을 하나씩 꺼내어 순차 전사. ANE 경합 방지.
    func processNextInQueue() async {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true
        defer { isProcessingQueue = false }

        while let item = transcriptionQueue.first {
            transcriptionQueue.removeFirst()

            // 큐 대기 항목: idle→transcribing 직접 전환 (recording phase 없이)
            #if os(iOS)
            if liveActivityManager.phase == .idle {
                liveActivityManager.startTranscribingDirectly()
            }
            #endif

            await transcribeInBackground(
                recordingID: item.recordingID,
                audioFileName: item.audioFileName,
                language: item.language,
                autoCopy: item.autoCopy
            )

            // 다음 항목 전 딜레이 (DI 완료 표시 시간 확보)
            #if os(iOS)
            if !transcriptionQueue.isEmpty {
                try? await Task.sleep(for: .milliseconds(500))
            }
            #endif
        }
    }

    // MARK: - 중단된 전사 복구

    func resumePendingTranscriptions() {
        // scenePhase 변경마다 호출되므로 5초 throttle
        let now = Date()
        guard now.timeIntervalSince(lastResumeDate) >= 5 else { return }
        lastResumeDate = now

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Recording>()

        guard let allRecordings = try? context.fetch(descriptor) else { return }
        let pendingRecordings = allRecordings.filter {
            $0.transcription?.status == .pending || $0.transcription?.status == .inProgress
        }
        guard !pendingRecordings.isEmpty else { return }

        let autoCopy = UserDefaults.standard.bool(forKey: "autoCopyEnabled")
        let language = AppGroupConstants.resolvedLanguage(
            from: UserDefaults.standard.string(forKey: "selectedLanguage")
        )

        // ModelContext 해제 후에도 안전하도록 값을 미리 추출
        let items = pendingRecordings.map { ($0.persistentModelID, $0.audioFileName) }

        for (id, fileName) in items {
            // 이미 전사 중이거나 큐에 있는 항목은 중복 enqueue 방지
            guard !activeTranscriptionIDs.contains(id),
                  !transcriptionQueue.contains(where: { $0.recordingID == id })
            else { continue }
            transcriptionQueue.append(TranscriptionQueueItem(
                recordingID: id,
                audioFileName: fileName,
                language: language,
                autoCopy: autoCopy
            ))
        }

        Task {
            await processNextInQueue()
        }
    }
}
