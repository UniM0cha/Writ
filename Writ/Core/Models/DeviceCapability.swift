import Foundation

/// 디바이스 성능 등급. Neural Engine 세대에 따라 분류.
enum DeviceCapability: Sendable {
    /// A17 Pro+ (iPhone 15 Pro~): large 모델 지원
    case highEnd
    /// A15/A16 (iPhone 13~14): small 모델까지
    case midRange
    /// A14 이하: base/tiny만
    case lowEnd

    /// 현재 디바이스의 성능 등급
    static var current: DeviceCapability {
        #if os(watchOS)
        return .lowEnd
        #else
        let processInfo = ProcessInfo.processInfo
        let ramGB = processInfo.physicalMemory / (1024 * 1024 * 1024)
        if ramGB >= 6 {
            return .highEnd
        } else if ramGB >= 4 {
            return .midRange
        } else {
            return .lowEnd
        }
        #endif
    }

    /// 이 등급에서 지원하는 최대 모델
    var maxSupportedModel: WhisperModelVariant {
        switch self {
        case .highEnd: .largeV3Turbo
        case .midRange: .small
        case .lowEnd: .base
        }
    }

    /// 기본 모델
    var defaultModel: WhisperModelVariant {
        switch self {
        case .highEnd: .small
        case .midRange: .small
        case .lowEnd: .tiny
        }
    }

    /// WhisperKit 모델 지원 여부
    func supports(_ model: WhisperModelVariant) -> Bool {
        model.minimumRAMGB * 1024 * 1024 * 1024 <= Int(ProcessInfo.processInfo.physicalMemory)
    }

    /// 범용 모델 지원 여부 (ModelIdentifier 기반)
    func supports(_ model: ModelIdentifier) -> Bool {
        model.minimumRAMGB * 1024 * 1024 * 1024 <= Int(ProcessInfo.processInfo.physicalMemory)
    }

    /// 특정 엔진의 기본 모델
    func defaultModel(for engine: EngineType) -> ModelIdentifier {
        switch engine {
        case .whisperKit:
            defaultModel.modelIdentifier
        case .qwen3ASR:
            switch self {
            case .highEnd: .qwen3_1_7B_int8
            case .midRange: .qwen3_0_6B_int8
            case .lowEnd: .qwen3_0_6B_int4
            }
        }
    }
}
