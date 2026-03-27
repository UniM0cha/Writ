import SwiftUI
import SwiftData

struct RetranscribeSheet: View {
    let recording: Recording
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isTranscribing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 엔진 선택
                Picker("엔진", selection: Binding(
                    get: { appState.modelManager.selectedEngine },
                    set: { appState.modelManager.selectedEngine = $0 }
                )) {
                    ForEach(EngineType.availableCases) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, WritSpacing.md)
                .padding(.top, WritSpacing.sm)

                // 모델 카드 리스트
                ScrollView {
                    VStack(spacing: WritSpacing.xs) {
                        ForEach(appState.modelManager.currentEngineModels) { model in
                            modelCard(model)
                        }
                    }
                    .padding(WritSpacing.md)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(WritFont.caption)
                        .foregroundStyle(WritColor.recordingRed)
                        .padding()
                }

                Text("더 큰 모델을 사용하면 정확도가 높아지지만 시간이 더 걸립니다.")
                    .font(WritFont.caption)
                    .foregroundStyle(WritColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, WritSpacing.lg)
                    .padding(.bottom, WritSpacing.md)
            }
            .background(WritColor.background)
            .navigationTitle("재전사")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .overlay {
                if isTranscribing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: WritSpacing.sm) {
                            ProgressView()
                                .controlSize(.large)
                            Text("재전사 중...")
                                .font(WritFont.caption)
                                .foregroundStyle(.white)
                        }
                        .padding(WritSpacing.lg)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: WritRadius.card))
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func modelCard(_ model: ModelInfo) -> some View {
        Button {
            retranscribe(with: model.identifier)
        } label: {
            HStack(spacing: WritSpacing.sm) {
                // 상태 점
                Circle()
                    .fill(model.identifier == appState.modelManager.activeModel
                          ? WritColor.success : WritColor.secondaryText.opacity(0.3))
                    .frame(width: WritDimension.modelDotSize, height: WritDimension.modelDotSize)

                VStack(alignment: .leading, spacing: WritSpacing.xxxs) {
                    Text(model.identifier.displayName)
                        .font(WritFont.body)
                        .foregroundStyle(model.isSupported ? WritColor.primaryText : WritColor.secondaryText)
                    Text("\(model.identifier.diskSizeMB) MB")
                        .font(WritFont.caption)
                        .foregroundStyle(WritColor.secondaryText)
                }

                Spacer()

                if !model.isSupported {
                    Text("미지원")
                        .font(WritFont.caption)
                        .foregroundStyle(WritColor.recordingRed)
                } else if model.identifier == appState.modelManager.activeModel {
                    Text("사용 중")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WritColor.accent)
                        .padding(.horizontal, WritSpacing.xs)
                        .padding(.vertical, WritSpacing.xxxs)
                        .background(WritColor.accentLight, in: Capsule())
                }
            }
            .padding(WritSpacing.sm)
            .background(WritColor.cardBackground, in: RoundedRectangle(cornerRadius: WritRadius.card))
        }
        .disabled(!model.isSupported || isTranscribing)
    }

    private func retranscribe(with identifier: ModelIdentifier) {
        isTranscribing = true
        errorMessage = nil
        Task {
            do {
                if identifier != appState.modelManager.activeModel {
                    try await appState.modelManager.loadModel(identifier)
                }
                let output = try await appState.modelManager.transcribe(
                    audioURL: recording.audioURL,
                    language: recording.languageCode,
                    progressCallback: nil
                )

                if let oldTranscription = recording.transcription {
                    modelContext.delete(oldTranscription)
                }

                let segments = output.segments.enumerated().map { index, seg in
                    WritSegment(
                        text: seg.text,
                        startTime: seg.startTime,
                        endTime: seg.endTime,
                        orderIndex: index,
                        speaker: seg.speaker
                    )
                }

                let transcription = Transcription(
                    text: output.text,
                    modelUsed: identifier.displayName,
                    status: .completed,
                    segments: segments
                )

                recording.transcription = transcription
                try modelContext.save()

                dismiss()
            } catch {
                errorMessage = "재전사 실패: \(error.localizedDescription)"
            }
            isTranscribing = false
        }
    }
}
