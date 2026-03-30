import SwiftUI

struct ExportSheet: View {
    let recording: Recording
    @Environment(\.dismiss) private var dismiss
    @State private var shareItem: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: WritSpacing.md) {
                // 핸들 바
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 36, height: 5)
                    .padding(.top, WritSpacing.xs)

                Text("내보내기")
                    .font(WritFont.caption)
                    .foregroundStyle(WritColor.secondaryText)
                    .textCase(.uppercase)

                // 내보내기 옵션 그리드
                HStack(spacing: 0) {
                    exportOption(
                        icon: "doc.text",
                        label: "텍스트",
                        description: ".txt",
                        action: exportTXT
                    )

                    Rectangle()
                        .fill(WritColor.divider)
                        .frame(width: 0.5)

                    exportOption(
                        icon: "captions.bubble",
                        label: "자막",
                        description: ".srt",
                        action: exportSRT
                    )

                    Rectangle()
                        .fill(WritColor.divider)
                        .frame(width: 0.5)

                    exportOption(
                        icon: "doc.on.doc",
                        label: "복사",
                        description: "클립보드",
                        action: copyToClipboard
                    )
                }
                .background(WritColor.cardBackground, in: RoundedRectangle(cornerRadius: WritRadius.card))
                .padding(.horizontal, WritSpacing.md)

                // 취소 버튼
                Button(action: { dismiss() }) {
                    Text("취소")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(WritColor.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, WritSpacing.sm + 2)
                        .background(WritColor.cardBackground, in: RoundedRectangle(cornerRadius: WritRadius.card))
                }
                .padding(.horizontal, WritSpacing.md)

                Spacer()
            }
            .background(WritColor.background.ignoresSafeArea())
            #if os(iOS)
            .sheet(item: $shareItem) { url in
                ShareSheet(activityItems: [url])
            }
            #endif
        }
        .presentationDetents([.medium])
    }

    private func exportOption(icon: String, label: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: WritSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: WritDimension.exportIconSize))
                    .foregroundStyle(WritColor.accent)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WritColor.primaryText)
                Text(description)
                    .font(WritFont.smallCaption)
                    .foregroundStyle(WritColor.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, WritSpacing.md)
        }
    }

    private func exportTXT() {
        guard let segments = recording.transcription?.segments else { return }
        let segmentOutputs = segments.sorted(by: { $0.orderIndex < $1.orderIndex }).map {
            SegmentOutput(text: $0.text, startTime: $0.startTime, endTime: $0.endTime, speaker: $0.speaker)
        }
        let text = TXTExporter.export(segments: segmentOutputs, includeTimestamps: true)
        shareText(text, fileName: "transcription.txt")
    }

    private func exportSRT() {
        guard let segments = recording.transcription?.segments else { return }
        let segmentOutputs = segments.sorted(by: { $0.orderIndex < $1.orderIndex }).map {
            SegmentOutput(text: $0.text, startTime: $0.startTime, endTime: $0.endTime, speaker: $0.speaker)
        }
        let text = SRTExporter.export(segments: segmentOutputs)
        shareText(text, fileName: "transcription.srt")
    }

    private func copyToClipboard() {
        guard let text = recording.transcription?.text else { return }
        ClipboardService.copy(text)
        dismiss()
    }

    private func shareText(_ text: String, fileName: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? text.write(to: tempURL, atomically: true, encoding: .utf8)
        #if os(iOS)
        shareItem = tempURL
        #elseif os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.copyItem(at: tempURL, to: url)
            }
        }
        dismiss()
        #endif
    }
}

// URL을 Identifiable로 확장 (sheet에서 사용)
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#if os(iOS)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
