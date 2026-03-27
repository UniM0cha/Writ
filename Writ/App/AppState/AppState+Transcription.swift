import Foundation
import SwiftData

// MARK: - 백그라운드 전사

extension AppState {
    func transcribeInBackground(
        recordingID: PersistentIdentifier,
        audioFileName: String,
        language: String?,
        autoCopy: Bool
    ) async {
        // 중복 전사 방지
        guard !activeTranscriptionIDs.contains(recordingID) else { return }
        activeTranscriptionIDs.insert(recordingID)
        defer { activeTranscriptionIDs.remove(recordingID) }

        #if os(iOS)
        // Live Activity 정리 보장 — 큐에 다음 항목이 없을 때만 종료
        // (다음 항목이 있으면 processNextInQueue에서 재활용)
        defer {
            let p = liveActivityManager.phase
            if p != .idle && p != .completed && transcriptionQueue.isEmpty {
                liveActivityManager.end()
            }
        }
        #endif

        let audioURL = AppGroupConstants.recordingsDirectory.appendingPathComponent(audioFileName)

        // 모델이 아직 로드되지 않았으면 로드 대기
        if modelManager.activeModel == nil {
            await modelManager.loadDefaultModelIfNeeded()
        }

        let backgroundContext = ModelContext(modelContainer)

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            if let recording = backgroundContext.model(for: recordingID) as? Recording {
                recording.transcription?.status = .failed
                try? backgroundContext.save()
            }
            return
        }

        // 상태를 inProgress로 업데이트
        if let recording = backgroundContext.model(for: recordingID) as? Recording {
            recording.transcription?.status = .inProgress
            try? backgroundContext.save()
        } else {
            return
        }

        do {
            let output = try await modelManager.transcribe(
                audioURL: audioURL,
                language: language,
                progressCallback: { @Sendable progress in
                    Task { @MainActor in
                        let appState = AppState.shared
                        #if os(iOS)
                        appState.liveActivityManager.updateProgress(progress)
                        appState.activeBGTask?.progress.completedUnitCount = Int64(progress * 100)
                        #endif
                        // SwiftData에 진행률 저장 (throttled)
                        let now = Date()
                        if now.timeIntervalSince(appState.lastProgressSaveDate) >= 0.5 {
                            appState.lastProgressSaveDate = now
                            let ctx = ModelContext(appState.modelContainer)
                            if let rec = ctx.model(for: recordingID) as? Recording {
                                rec.transcription?.progress = progress
                                try? ctx.save()
                            }
                        }
                    }
                }
            )

            // 발화자 구분 (iOS + 설정 활성화 시)
            var finalOutput = output
            #if os(iOS)
            let diarizationEnabled = UserDefaults.standard.bool(forKey: "diarizationEnabled")
            if diarizationEnabled {
                let diarService = diarizationService
                if !diarService.isLoaded {
                    try? await diarService.loadModels()
                }
                if diarService.isLoaded {
                    let diarResult = try? await diarService.diarize(audioURL: audioURL)
                    if let diarResult {
                        finalOutput = diarService.merge(transcription: output, diarization: diarResult)
                    }
                }
            }
            #endif

            if let recording = backgroundContext.model(for: recordingID) as? Recording {
                let segments = finalOutput.segments.enumerated().map { index, seg in
                    WritSegment(
                        text: seg.text,
                        startTime: seg.startTime,
                        endTime: seg.endTime,
                        orderIndex: index,
                        speaker: seg.speaker
                    )
                }

                recording.transcription?.text = finalOutput.text
                recording.transcription?.modelUsed = modelManager.activeModel?.displayName ?? "unknown"
                recording.transcription?.status = .completed
                recording.transcription?.progress = 1
                recording.transcription?.segments = segments
                try backgroundContext.save()

                if autoCopy {
                    ClipboardService.copy(finalOutput.text)
                }

                // Live Activity → 완료 상태
                #if os(iOS)
                liveActivityManager.transitionToCompleted()
                #endif

                await sendCompletionNotification(
                    text: finalOutput.text,
                    recordingID: recording.id
                )
            }
        } catch {
            if let recording = backgroundContext.model(for: recordingID) as? Recording {
                recording.transcription?.status = .failed
                try? backgroundContext.save()
            }
        }
    }
}
