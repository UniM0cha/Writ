import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var searchText = ""
    @State private var shareItem: URL?
    @State private var navigateToRecording: Recording?

    var body: some View {
        NavigationStack {
            Group {
                if recordings.isEmpty {
                    emptyState
                } else {
                    recordingsList
                }
            }
            .navigationTitle("기록")
            .searchable(text: $searchText, prompt: "전사문 검색")
            .background(WritColor.background.ignoresSafeArea())
            .navigationDestination(item: $navigateToRecording) { recording in
                TranscriptionDetailView(recording: recording)
            }
            .onChange(of: appState.pendingRecordingID) { _, newID in
                guard let idString = newID else { return }
                if let target = recordings.first(where: { $0.id.uuidString == idString }) {
                    navigateToRecording = target
                }
                appState.pendingRecordingID = nil
            }
        }
        #if os(iOS)
        .sheet(item: $shareItem) { url in
            ShareSheet(activityItems: [url])
        }
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: WritSpacing.md) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 48))
                .foregroundStyle(WritColor.secondaryText)
            Text("녹음 기록이 없습니다")
                .font(.headline)
                .foregroundStyle(WritColor.secondaryText)
            Text("녹음 탭에서 첫 녹음을 시작해보세요")
                .font(.subheadline)
                .foregroundStyle(WritColor.tertiaryText)
        }
    }

    private var recordingsList: some View {
        List {
            ForEach(groupedByDate, id: \.key) { date, items in
                Section {
                    ForEach(items) { recording in
                        NavigationLink(destination: TranscriptionDetailView(recording: recording)) {
                            HistoryRowView(recording: recording)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRecording(recording)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                shareItem = recording.audioURL
                            } label: {
                                Label("공유", systemImage: "square.and.arrow.up")
                            }
                            .tint(WritColor.accent)
                        }
                    }
                } header: {
                    Text(formatSectionDate(date))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WritColor.tertiaryText)
                        .textCase(.uppercase)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    private var groupedByDate: [(key: Date, value: [Recording])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRecordings) { recording in
            calendar.startOfDay(for: recording.createdAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private var filteredRecordings: [Recording] {
        if searchText.isEmpty { return recordings }
        return recordings.filter { recording in
            recording.transcription?.text.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    private func deleteRecording(_ recording: Recording) {
        try? FileManager.default.removeItem(at: recording.audioURL)
        modelContext.delete(recording)
        try? modelContext.save()
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
}
