import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("autoCopyEnabled") private var autoCopyEnabled = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    @AppStorage("selectedLanguage") private var selectedLanguage = "auto"
    @AppStorage("autoDeleteDays") private var autoDeleteDays = 0

    private let languages = [
        ("auto", "자동 감지"),
        ("ko", "한국어"),
        ("en", "English"),
        ("ja", "日本語"),
        ("zh", "中文"),
        ("es", "Español"),
        ("fr", "Français"),
        ("de", "Deutsch")
    ]

    var body: some View {
        NavigationStack {
            List {
                modelSection
                languageSection
                convenienceSection
                syncSection
                storageSection
            }
            .navigationTitle("설정")
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        Section {
            ForEach(appState.modelManager.models) { model in
                ModelRowView(
                    model: model,
                    isActive: model.variant == appState.modelManager.activeModel,
                    onSelect: {
                        Task { try? await appState.modelManager.loadModel(model.variant) }
                    },
                    onDelete: {
                        Task { await appState.modelManager.deleteModel(model.variant) }
                    }
                )
            }
        } header: {
            Text("음성 인식 모델")
        } footer: {
            Text("기기에서 지원하는 모델만 다운로드할 수 있습니다")
        }
    }

    // MARK: - Language Section

    private var languageSection: some View {
        Section("언어") {
            Picker("인식 언어", selection: $selectedLanguage) {
                ForEach(languages, id: \.0) { code, name in
                    Text(name).tag(code)
                }
            }
        }
    }

    // MARK: - Convenience Section

    private var convenienceSection: some View {
        Section("편의 기능") {
            Toggle("전사 완료 시 자동 복사", isOn: $autoCopyEnabled)
        }
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        Section("동기화") {
            Toggle("iCloud 동기화", isOn: $iCloudSyncEnabled)
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section("저장 관리") {
            Picker("자동 삭제", selection: $autoDeleteDays) {
                Text("사용 안 함").tag(0)
                Text("7일 후").tag(7)
                Text("30일 후").tag(30)
                Text("90일 후").tag(90)
            }
        }
    }
}

// MARK: - Model Row

struct ModelRowView: View {
    let model: WhisperModelInfo
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    private var isDownloaded: Bool {
        switch model.state {
        case .downloaded, .loaded: return true
        default: return false
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: WritSpacing.sm) {
                // 상태 점
                Circle()
                    .fill(statusDotColor)
                    .frame(width: WritDimension.statusDotSize, height: WritDimension.statusDotSize)

                VStack(alignment: .leading, spacing: WritSpacing.xxxs) {
                    HStack(spacing: WritSpacing.xxs) {
                        Text(model.variant.displayName)
                            .font(WritFont.body)
                            .foregroundStyle(model.isSupported ? WritColor.primaryText : WritColor.secondaryText)

                        if isActive {
                            Text("사용 중")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(WritColor.accent)
                                .padding(.horizontal, WritSpacing.xxs)
                                .padding(.vertical, 1)
                                .background(WritColor.accentLight, in: Capsule())
                        }
                    }

                    Text("\(model.variant.diskSizeMB) MB")
                        .font(WritFont.caption)
                        .foregroundStyle(WritColor.secondaryText)

                    if let reason = model.unsupportedReason {
                        Text(reason)
                            .font(WritFont.caption)
                            .foregroundStyle(WritColor.recordingRed)
                    }
                }

                Spacer()

                modelStateView
            }
        }
        .disabled(!model.isSupported)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isDownloaded {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            if isDownloaded {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("모델 삭제", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "\(model.variant.displayName) 모델을 삭제하시겠습니까?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { onDelete() }
        } message: {
            Text("모델 파일(\(model.variant.diskSizeMB) MB)이 삭제됩니다. 다시 사용하려면 재다운로드가 필요합니다.")
        }
    }

    // MARK: - Status Dot Color

    private var statusDotColor: Color {
        switch model.state {
        case .loaded: WritColor.success
        case .downloaded: WritColor.accent
        case .downloading: WritColor.warning
        case .loading: WritColor.warning
        case .error: WritColor.recordingRed
        case .notDownloaded: WritColor.secondaryText.opacity(0.3)
        }
    }

    // MARK: - State View

    @ViewBuilder
    private var modelStateView: some View {
        switch model.state {
        case .notDownloaded:
            Text("다운로드")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(WritColor.accent)
                .padding(.horizontal, WritSpacing.sm)
                .padding(.vertical, WritSpacing.xxs)
                .background(WritColor.accentLight, in: Capsule())

        case .downloading(let progress):
            ZStack {
                Circle()
                    .stroke(WritColor.secondaryText.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(WritColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WritColor.secondaryText)
            }
            .frame(width: 36, height: 36)

        case .downloaded:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(WritColor.success)

        case .loaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(WritColor.success)

        case .loading:
            ProgressView()
                .controlSize(.small)

        case .error(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(WritColor.recordingRed)
                .help(message)
        }
    }
}
