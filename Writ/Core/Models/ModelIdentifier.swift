import Foundation

/// 엔진에 무관한 범용 모델 식별자. WhisperKit과 Qwen3-ASR 모델을 통합 관리한다.
struct ModelIdentifier: Sendable, Identifiable {
    let engine: EngineType
    /// HuggingFace 모델 ID 또는 WhisperKit variant rawValue
    let variantKey: String
    let displayName: String
    /// 디스크 크기 (MB)
    let diskSizeMB: Int
    /// 최소 요구 RAM (GB)
    let minimumRAMGB: Int

    var id: String { "\(engine.rawValue)/\(variantKey)" }
}

// MARK: - Hashable / Equatable (nonisolated)

extension ModelIdentifier: Hashable {
    nonisolated static func == (lhs: ModelIdentifier, rhs: ModelIdentifier) -> Bool {
        lhs.engine == rhs.engine && lhs.variantKey == rhs.variantKey
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(engine)
        hasher.combine(variantKey)
    }
}

// MARK: - Codable (nonisolated)

extension ModelIdentifier: Codable {
    private enum CodingKeys: String, CodingKey {
        case engine, variantKey, displayName, diskSizeMB, minimumRAMGB
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        engine = try container.decode(EngineType.self, forKey: .engine)
        variantKey = try container.decode(String.self, forKey: .variantKey)
        displayName = try container.decode(String.self, forKey: .displayName)
        diskSizeMB = try container.decode(Int.self, forKey: .diskSizeMB)
        minimumRAMGB = try container.decode(Int.self, forKey: .minimumRAMGB)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(engine, forKey: .engine)
        try container.encode(variantKey, forKey: .variantKey)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(diskSizeMB, forKey: .diskSizeMB)
        try container.encode(minimumRAMGB, forKey: .minimumRAMGB)
    }
}

// MARK: - WhisperModelVariant 브릿지

extension WhisperModelVariant {
    var modelIdentifier: ModelIdentifier {
        ModelIdentifier(
            engine: .whisperKit,
            variantKey: rawValue,
            displayName: displayName,
            diskSizeMB: diskSizeMB,
            minimumRAMGB: minimumRAMGB
        )
    }
}

extension ModelIdentifier {
    /// WhisperKit 엔진인 경우 WhisperModelVariant로 변환
    var whisperVariant: WhisperModelVariant? {
        guard engine == .whisperKit else { return nil }
        return WhisperModelVariant(rawValue: variantKey)
    }
}

// MARK: - Qwen3-ASR 모델 카탈로그

extension ModelIdentifier {
    static let qwen3_0_6B_4bit = ModelIdentifier(
        engine: .qwen3ASR,
        variantKey: "aufklarer/Qwen3-ASR-0.6B-MLX-4bit",
        displayName: "0.6B 4-bit",
        diskSizeMB: 675,
        minimumRAMGB: 2
    )

    static let qwen3_0_6B_8bit = ModelIdentifier(
        engine: .qwen3ASR,
        variantKey: "aufklarer/Qwen3-ASR-0.6B-MLX-8bit",
        displayName: "0.6B 8-bit",
        diskSizeMB: 1000,
        minimumRAMGB: 3
    )

    static let qwen3_1_7B_4bit = ModelIdentifier(
        engine: .qwen3ASR,
        variantKey: "aufklarer/Qwen3-ASR-1.7B-MLX-4bit",
        displayName: "1.7B 4-bit",
        diskSizeMB: 1200,
        minimumRAMGB: 3
    )

    static let qwen3_1_7B_8bit = ModelIdentifier(
        engine: .qwen3ASR,
        variantKey: "aufklarer/Qwen3-ASR-1.7B-MLX-8bit",
        displayName: "1.7B 8-bit",
        diskSizeMB: 2349,
        minimumRAMGB: 4
    )

    /// 특정 엔진의 모든 모델 목록
    static func allModels(for engine: EngineType) -> [ModelIdentifier] {
        switch engine {
        case .whisperKit:
            WhisperModelVariant.allCases.map(\.modelIdentifier)
        case .qwen3ASR:
            [.qwen3_0_6B_4bit, .qwen3_0_6B_8bit, .qwen3_1_7B_4bit, .qwen3_1_7B_8bit]
        }
    }

    /// variantKey로 ModelIdentifier 검색
    static func find(engine: EngineType, variantKey: String) -> ModelIdentifier? {
        allModels(for: engine).first { $0.variantKey == variantKey }
    }
}
