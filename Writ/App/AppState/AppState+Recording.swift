import Foundation
import SwiftData
#if os(iOS)
import UIKit
import BackgroundTasks
#endif

// MARK: - 녹음 중지 + 전사 (Intent 및 RecordingView에서 호출)

extension AppState {
    func stopRecordingAndTranscribe() {
        guard let (fileName, duration) = recorderService.stopRecording() else {
            #if os(iOS)
            liveActivityManager.end()
            #endif
            return
        }

        let language = AppGroupConstants.resolvedLanguage(
            from: UserDefaults.standard.string(forKey: "selectedLanguage")
        )
        let autoCopy = UserDefaults.standard.bool(forKey: "autoCopyEnabled")

        let context = ModelContext(modelContainer)

        let sourceDevice: SourceDevice = {
            #if os(macOS)
            return .mac
            #else
            return UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
            #endif
        }()

        let recording = Recording(
            duration: duration,
            audioFileName: fileName,
            languageCode: language,
            sourceDevice: sourceDevice
        )
        let transcription = Transcription(
            text: "",
            modelUsed: modelManager.activeModel?.displayName ?? "unknown",
            status: .pending
        )
        recording.transcription = transcription
        recording.audioData = try? Data(contentsOf: recording.audioURL)
        context.insert(recording)
        try? context.save()

        let recordingID = recording.persistentModelID

        let item = TranscriptionQueueItem(
            recordingID: recordingID,
            audioFileName: fileName,
            language: language,
            autoCopy: autoCopy
        )
        transcriptionQueue.append(item)

        #if os(iOS)
        // 큐 첫 항목: DI 전환 + BGTask 제출. 이미 큐 처리 중이면 대기.
        if !isProcessingQueue {
            liveActivityManager.transitionToTranscribing()

            let request = BGContinuedProcessingTaskRequest(
                identifier: "com.solstice.writ.transcribe",
                title: "전사 중",
                subtitle: "음성을 텍스트로 변환하고 있습니다"
            )
            request.strategy = .fail

            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                // BGTask 제출 실패 시 fallback: 직접 큐 처리
                Task {
                    await self.processNextInQueue()
                }
            }
        }
        #else
        // macOS: 백그라운드 제한 없음, 직접 큐 처리
        if !isProcessingQueue {
            Task {
                await self.processNextInQueue()
            }
        }
        #endif
    }
}
