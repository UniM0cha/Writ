import Foundation

/// Whisper 모델 변형. 디바이스 성능에 따라 사용 가능 모델이 달라진다.
enum WhisperModelVariant: String, CaseIterable, Codable, Sendable, Identifiable {
    case tiny = "openai_whisper-tiny"
    case base = "openai_whisper-base"
    case small = "openai_whisper-small"
    case largeV3 = "openai_whisper-large-v3"
    case largeV3Turbo = "openai_whisper-large-v3_turbo"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny: "Tiny"
        case .base: "Base"
        case .small: "Small"
        case .largeV3: "Large v3"
        case .largeV3Turbo: "Large v3 Turbo"
        }
    }

    /// 디스크 크기 (MB)
    var diskSizeMB: Int {
        switch self {
        case .tiny: 75
        case .base: 142
        case .small: 466
        case .largeV3: 947
        case .largeV3Turbo: 954
        }
    }

    /// 최소 요구 RAM (GB)
    var minimumRAMGB: Int {
        switch self {
        case .tiny: 1
        case .base: 1
        case .small: 2
        case .largeV3: 4
        case .largeV3Turbo: 4
        }
    }
}

/// 모델의 로컬 상태
enum ModelState: Codable, Sendable {
    case notDownloaded
    case downloading(progress: Float, status: String? = nil)
    case downloaded
    case optimizing
    case loading
    case loaded
    case error(String)
}
