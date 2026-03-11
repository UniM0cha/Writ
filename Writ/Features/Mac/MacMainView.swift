import SwiftUI
import SwiftData

#if os(macOS)
struct MacMainView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var selectedRecording: Recording?

    var body: some View {
        NavigationSplitView {
            List(recordings, selection: $selectedRecording) { recording in
                HistoryRowView(recording: recording)
                    .tag(recording)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 260)
            .navigationSplitViewColumnWidth(min: 260, ideal: 300)
            .toolbar {
                ToolbarItem {
                    Button(action: startRecording) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        } detail: {
            if let recording = selectedRecording {
                TranscriptionDetailView(recording: recording)
            } else {
                ContentUnavailableView(
                    "녹음을 선택하세요",
                    systemImage: "waveform",
                    description: Text("왼쪽 사이드바에서 녹음을 선택하면 여기에 표시됩니다")
                )
            }
        }
        .task {
            await appState.setup()
        }
    }

    private func startRecording() {
        Task {
            _ = try? await appState.recorderService.startRecording()
        }
    }
}
#endif
