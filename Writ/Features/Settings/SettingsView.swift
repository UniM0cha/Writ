import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("autoCopyEnabled") private var autoCopyEnabled = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    @AppStorage("selectedLanguage") private var selectedLanguage = "auto"
    @AppStorage("autoDeleteDays") private var autoDeleteDays = 0

    private var languages: [(code: String, name: String)] {
        AppGroupConstants.supportedLanguages
    }

    var body: some View {
        NavigationStack {
            List {
                engineSection
                modelSection
                languageSection
                convenienceSection
                syncSection
                storageSection
            }
            .navigationTitle("설정")
        }
    }

    // MARK: - Engine Section

    private var engineSection: some View {
        Section("음성 인식 엔진") {
            Picker("엔진", selection: Binding(
                get: { appState.modelManager.selectedEngine },
                set: { appState.modelManager.selectedEngine = $0 }
            )) {
                ForEach(EngineType.availableCases) { engine in
                    Text(engine.displayName).tag(engine)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        Section {
            ForEach(appState.modelManager.currentEngineModels) { model in
                ModelRowView(
                    model: model,
                    isActive: model.identifier == appState.modelManager.activeModel,
                    onSelect: {
                        Task { try? await appState.modelManager.loadModel(model.identifier) }
                    },
                    onDelete: {
                        Task { await appState.modelManager.deleteModel(model.identifier) }
                    },
                    onCancel: {
                        appState.modelManager.cancelDownload(model.identifier)
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
                ForEach(languages, id: \.code) { code, name in
                    Text(name).tag(code)
                }
            }
            .onChange(of: selectedLanguage) { _, newValue in
                AppGroupConstants.sharedDefaults.set(newValue, forKey: "selectedLanguage")
            }
        }
    }

    // MARK: - Convenience Section

    private var convenienceSection: some View {
        Section {
            Toggle("전사 완료 시 자동 복사", isOn: $autoCopyEnabled)
        } header: {
            Text("편의 기능")
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
    let model: ModelInfo
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

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
                        Text(model.identifier.displayName)
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

                    Text("\(model.identifier.diskSizeMB) MB")
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
            "\(model.identifier.displayName) 모델을 삭제하시겠습니까?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { onDelete() }
        } message: {
            Text("모델 파일(\(model.identifier.diskSizeMB) MB)이 삭제됩니다. 다시 사용하려면 재다운로드가 필요합니다.")
        }
    }

    // MARK: - Status Dot Color

    private var statusDotColor: Color {
        switch model.state {
        case .loaded: WritColor.success
        case .downloaded: WritColor.accent
        case .downloading: WritColor.warning
        case .optimizing: WritColor.warning
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

        case .downloading(let progress, let status):
            HStack(spacing: WritSpacing.xs) {
                if let status {
                    Text(status)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WritColor.secondaryText)
                }

                Button(action: onCancel) {
                    ZStack {
                        Circle()
                            .stroke(WritColor.accent.opacity(0.2), lineWidth: 3.5)
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(WritColor.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(WritColor.accent)
                            .frame(width: 10, height: 10)
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

        case .downloaded:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(WritColor.success)

        case .loaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(WritColor.success)

        case .optimizing:
            VStack(spacing: 2) {
                ProgressView()
                    .controlSize(.small)
                Text("최적화 중")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WritColor.secondaryText)
            }

        case .loading:
            ProgressView()
                .controlSize(.small)

        case .error(let message):
            HStack(spacing: WritSpacing.xs) {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WritColor.recordingRed)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)

                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(WritColor.recordingRed)
            }
        }
    }
}
