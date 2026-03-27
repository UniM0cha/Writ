import SwiftUI
import SwiftData

#if os(macOS)
struct MacMainView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var selectedRecording: Recording?
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""

    private var isRecording: Bool { appState.recorderService.isRecording }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let recording = selectedRecording {
                MacDetailView(recording: recording, onDelete: {
                    selectedRecording = nil
                })
                    .id(recording.id)
            } else {
                ContentUnavailableView(
                    "녹음을 선택하세요",
                    systemImage: "waveform",
                    description: Text("왼쪽 사이드바에서 녹음을 선택하면 여기에 표시됩니다")
                )
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "전사문 검색")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // 녹음 버튼
                Button(action: toggleRecording) {
                    HStack(spacing: WritSpacing.xxs) {
                        if isRecording {
                            Circle()
                                .fill(WritColor.recordingRed)
                                .frame(width: 8, height: 8)
                            Text(formatTime(appState.recorderService.currentTime))
                                .font(.system(size: 13, design: .monospaced))
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10))
                        } else {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.white)
                            Text("녹음")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, WritSpacing.sm)
                    .padding(.vertical, WritSpacing.xxs + 1)
                    .background(
                        isRecording ? Color.black : WritColor.recordingRed,
                        in: RoundedRectangle(cornerRadius: WritRadius.small)
                    )
                }
                .buttonStyle(.plain)
                .disabled(appState.modelManager.activeModel == nil && !isRecording)
            }

            ToolbarItemGroup(placement: .automatic) {
                // 모델 피커
                modelPicker

                // 설정
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .task {
            await appState.setup()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedRecording) {
            if filteredRecordings.isEmpty {
                Text(searchText.isEmpty ? "녹음 기록이 없습니다" : "검색 결과가 없습니다")
                    .font(WritFont.caption)
                    .foregroundStyle(WritColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, WritSpacing.xl)
            } else {
                ForEach(groupedByDate, id: \.key) { date, items in
                    Section {
                        ForEach(items) { recording in
                            MacSidebarRowView(recording: recording)
                                .tag(recording)
                                .contextMenu {
                                    if let text = recording.transcription?.text, !text.isEmpty {
                                        Button {
                                            ClipboardService.copy(text)
                                        } label: {
                                            Label("전체 복사", systemImage: "doc.on.doc")
                                        }
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        deleteRecording(recording)
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(formatSectionDate(date))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WritColor.secondaryText)
                            .textCase(.uppercase)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 260)
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
    }

    // MARK: - Model Picker

    private var modelPicker: some View {
        Menu {
            ForEach(appState.modelManager.currentEngineModels) { model in
                Button {
                    Task {
                        try? await appState.modelManager.loadModel(model.identifier)
                    }
                } label: {
                    HStack {
                        Text(model.identifier.displayName)
                        if model.identifier == appState.modelManager.activeModel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(!model.isSupported)
            }
        } label: {
            HStack(spacing: WritSpacing.xxs) {
                Circle()
                    .fill(appState.modelManager.activeModel != nil ? WritColor.success : WritColor.secondaryText)
                    .frame(width: WritDimension.modelDotSize, height: WritDimension.modelDotSize)
                Text(appState.modelManager.activeModel?.displayName ?? "모델 없음")
                    .font(.system(size: 12))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WritColor.secondaryText)
            }
            .padding(.horizontal, WritSpacing.sm)
            .padding(.vertical, WritSpacing.xxs)
            .background(WritColor.divider, in: RoundedRectangle(cornerRadius: WritRadius.small))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Date Grouping

    private var groupedByDate: [(key: Date, value: [Recording])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRecordings) { recording in
            calendar.startOfDay(for: recording.createdAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private var filteredRecordings: [Recording] {
        if searchText.isEmpty { return Array(recordings) }
        return recordings.filter { recording in
            recording.transcription?.text.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "오늘"
        } else if calendar.isDateInYesterday(date) {
            return "어제"
        } else {
            return date.formatted(.dateTime.month().day())
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        if isRecording {
            appState.stopRecordingAndTranscribe()
        } else {
            Task {
                try? await appState.startRecordingFlow()
            }
        }
    }

    private func deleteRecording(_ recording: Recording) {
        if selectedRecording == recording {
            selectedRecording = nil
        }
        try? FileManager.default.removeItem(at: recording.audioURL)
        modelContext.delete(recording)
        try? modelContext.save()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
#endif
