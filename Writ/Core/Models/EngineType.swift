import Foundation

/// 음성 인식 엔진 종류
enum EngineType: String, CaseIterable, Sendable, Identifiable {
    case whisperKit
    case qwen3ASR

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whisperKit: "Whisper"
        case .qwen3ASR: "Qwen3-ASR"
        }
    }

    /// 현재 플랫폼에서 사용 가능한 엔진 목록 (macOS/watchOS에서는 Qwen3-ASR 제외)
    static var availableCases: [EngineType] {
        #if os(iOS)
        allCases.map { $0 }
        #else
        [.whisperKit]
        #endif
    }

    /// 현재 플랫폼에서 이 엔진을 사용할 수 있는지
    var isAvailableOnCurrentPlatform: Bool {
        Self.availableCases.contains(self)
    }
}

// MARK: - Codable (nonisolated — MainActor isolation 대응)

extension EngineType: Codable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = EngineType(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown EngineType: \(raw)")
        }
        self = value
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
