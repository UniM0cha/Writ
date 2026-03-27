import XCTest
@testable import Writ

final class ModelIdentifierTests: XCTestCase {

    // MARK: - Init & Properties

    func testInit_storesAllProperties() {
        let identifier = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "test-key",
            displayName: "Test Model",
            diskSizeMB: 500,
            minimumRAMGB: 2
        )

        XCTAssertEqual(identifier.engine, .whisperKit)
        XCTAssertEqual(identifier.variantKey, "test-key")
        XCTAssertEqual(identifier.displayName, "Test Model")
        XCTAssertEqual(identifier.diskSizeMB, 500)
        XCTAssertEqual(identifier.minimumRAMGB, 2)
    }

    // MARK: - Identifiable

    func testId_combinesEngineAndVariantKey() {
        let identifier = ModelIdentifier(
            engine: .qwen3ASR,
            variantKey: "some/model",
            displayName: "Model",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )
        XCTAssertEqual(identifier.id, "qwen3ASR/some/model")
    }

    func testId_whisperKit() {
        let identifier = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "openai_whisper-tiny",
            displayName: "Tiny",
            diskSizeMB: 75,
            minimumRAMGB: 1
        )
        XCTAssertEqual(identifier.id, "whisperKit/openai_whisper-tiny")
    }

    func testId_allModelsHaveUniqueIds() {
        var allIds: [String] = []
        for engine in EngineType.allCases {
            allIds.append(contentsOf: ModelIdentifier.allModels(for: engine).map(\.id))
        }
        let uniqueIds = Set(allIds)
        XCTAssertEqual(allIds.count, uniqueIds.count, "All model identifiers should have unique ids")
    }

    // MARK: - Hashable / Equatable

    func testEquatable_sameEngineAndVariantKey_areEqual() {
        let a = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "key",
            displayName: "Name A",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )
        let b = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "key",
            displayName: "Name B",
            diskSizeMB: 200,
            minimumRAMGB: 3
        )
        XCTAssertEqual(a, b, "Equality should be based on engine + variantKey only")
    }

    func testEquatable_differentVariantKey_areNotEqual() {
        let a = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "key-a",
            displayName: "Name",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )
        let b = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "key-b",
            displayName: "Name",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )
        XCTAssertNotEqual(a, b)
    }

    func testEquatable_differentEngine_areNotEqual() {
        let a = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "same-key",
            displayName: "Name",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )
        let b = ModelIdentifier(
            engine: .qwen3ASR,
            variantKey: "same-key",
            displayName: "Name",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )
        XCTAssertNotEqual(a, b)
    }

    func testHashable_equalIdentifiersHaveSameHash() {
        let a = ModelIdentifier(
            engine: .qwen3ASR,
            variantKey: "key",
            displayName: "A",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )
        let b = ModelIdentifier(
            engine: .qwen3ASR,
            variantKey: "key",
            displayName: "B",
            diskSizeMB: 200,
            minimumRAMGB: 3
        )
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testHashable_canBeUsedInSet() {
        let a = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "key",
            displayName: "A",
            diskSizeMB: 100,
            minimumRAMGB: 1
        )
        let b = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "key",
            displayName: "B",
            diskSizeMB: 200,
            minimumRAMGB: 3
        )
        let set: Set<ModelIdentifier> = [a, b]
        XCTAssertEqual(set.count, 1, "Equal identifiers should collapse in Set")
    }

    func testHashable_differentIdentifiersInSet() {
        let models = ModelIdentifier.allModels(for: .qwen3ASR)
        let set = Set(models)
        XCTAssertEqual(set.count, models.count, "All Qwen models should be distinct in Set")
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip_whisperKit() throws {
        let original = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "openai_whisper-small",
            displayName: "Small",
            diskSizeMB: 466,
            minimumRAMGB: 2
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelIdentifier.self, from: data)

        XCTAssertEqual(decoded.engine, original.engine)
        XCTAssertEqual(decoded.variantKey, original.variantKey)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.diskSizeMB, original.diskSizeMB)
        XCTAssertEqual(decoded.minimumRAMGB, original.minimumRAMGB)
    }

    func testCodableRoundtrip_qwen3ASR() throws {
        let original = ModelIdentifier.qwen3_1_7B_8bit
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelIdentifier.self, from: data)

        XCTAssertEqual(decoded.engine, .qwen3ASR)
        XCTAssertEqual(decoded.variantKey, original.variantKey)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.diskSizeMB, original.diskSizeMB)
        XCTAssertEqual(decoded.minimumRAMGB, original.minimumRAMGB)
    }

    func testCodableRoundtrip_allQwenModels() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for model in ModelIdentifier.allModels(for: .qwen3ASR) {
            let data = try encoder.encode(model)
            let decoded = try decoder.decode(ModelIdentifier.self, from: data)
            XCTAssertEqual(decoded, model, "\(model.displayName) should survive Codable roundtrip")
        }
    }

    func testCodableRoundtrip_preservesAllFields() throws {
        let original = ModelIdentifier(
            engine: .qwen3ASR,
            variantKey: "custom/key",
            displayName: "Custom Model",
            diskSizeMB: 999,
            minimumRAMGB: 8
        )
        let data = try JSONEncoder().encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Verify all keys are present in JSON
        XCTAssertNotNil(json["engine"])
        XCTAssertNotNil(json["variantKey"])
        XCTAssertNotNil(json["displayName"])
        XCTAssertNotNil(json["diskSizeMB"])
        XCTAssertNotNil(json["minimumRAMGB"])
    }

    func testDecoding_missingFieldThrows() {
        let incompleteJSON = """
        {"engine":"whisperKit","variantKey":"test"}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ModelIdentifier.self, from: incompleteJSON))
    }

    // MARK: - WhisperModelVariant Bridge

    func testWhisperVariantBridge_roundTrip() {
        for variant in WhisperModelVariant.allCases {
            let identifier = variant.modelIdentifier
            XCTAssertEqual(identifier.engine, .whisperKit)
            XCTAssertEqual(identifier.variantKey, variant.rawValue)
            XCTAssertEqual(identifier.displayName, variant.displayName)
            XCTAssertEqual(identifier.diskSizeMB, variant.diskSizeMB)
            XCTAssertEqual(identifier.minimumRAMGB, variant.minimumRAMGB)

            // Round trip back to variant
            let recovered = identifier.whisperVariant
            XCTAssertEqual(recovered, variant, "\(variant) should round-trip through ModelIdentifier")
        }
    }

    func testWhisperVariant_qwenModel_returnsNil() {
        XCTAssertNil(ModelIdentifier.qwen3_0_6B_4bit.whisperVariant)
        XCTAssertNil(ModelIdentifier.qwen3_0_6B_8bit.whisperVariant)
        XCTAssertNil(ModelIdentifier.qwen3_1_7B_4bit.whisperVariant)
        XCTAssertNil(ModelIdentifier.qwen3_1_7B_8bit.whisperVariant)
    }

    func testWhisperVariant_arbitraryWhisperKey_returnsNil() {
        let identifier = ModelIdentifier(
            engine: .whisperKit,
            variantKey: "nonexistent-whisper-model",
            displayName: "Fake",
            diskSizeMB: 1,
            minimumRAMGB: 1
        )
        XCTAssertNil(identifier.whisperVariant, "Invalid variantKey should return nil whisperVariant")
    }

    // MARK: - Qwen3-ASR Catalog Statics

    func testQwen3Catalog_count() {
        let qwenModels = ModelIdentifier.allModels(for: .qwen3ASR)
        XCTAssertEqual(qwenModels.count, 4)
    }

    func testQwen3Catalog_allHaveQwen3ASREngine() {
        for model in ModelIdentifier.allModels(for: .qwen3ASR) {
            XCTAssertEqual(model.engine, .qwen3ASR, "\(model.displayName) should have qwen3ASR engine")
        }
    }

    func testQwen3Catalog_specificValues_0_6B_4bit() {
        let model = ModelIdentifier.qwen3_0_6B_4bit
        XCTAssertEqual(model.variantKey, "aufklarer/Qwen3-ASR-0.6B-MLX-4bit")
        XCTAssertEqual(model.displayName, "0.6B 4-bit")
        XCTAssertEqual(model.diskSizeMB, 675)
        XCTAssertEqual(model.minimumRAMGB, 2)
    }

    func testQwen3Catalog_specificValues_0_6B_8bit() {
        let model = ModelIdentifier.qwen3_0_6B_8bit
        XCTAssertEqual(model.variantKey, "aufklarer/Qwen3-ASR-0.6B-MLX-8bit")
        XCTAssertEqual(model.displayName, "0.6B 8-bit")
        XCTAssertEqual(model.diskSizeMB, 1000)
        XCTAssertEqual(model.minimumRAMGB, 3)
    }

    func testQwen3Catalog_specificValues_1_7B_4bit() {
        let model = ModelIdentifier.qwen3_1_7B_4bit
        XCTAssertEqual(model.variantKey, "aufklarer/Qwen3-ASR-1.7B-MLX-4bit")
        XCTAssertEqual(model.displayName, "1.7B 4-bit")
        XCTAssertEqual(model.diskSizeMB, 1200)
        XCTAssertEqual(model.minimumRAMGB, 3)
    }

    func testQwen3Catalog_specificValues_1_7B_8bit() {
        let model = ModelIdentifier.qwen3_1_7B_8bit
        XCTAssertEqual(model.variantKey, "aufklarer/Qwen3-ASR-1.7B-MLX-8bit")
        XCTAssertEqual(model.displayName, "1.7B 8-bit")
        XCTAssertEqual(model.diskSizeMB, 2349)
        XCTAssertEqual(model.minimumRAMGB, 4)
    }

    func testQwen3Catalog_diskSizePositive() {
        for model in ModelIdentifier.allModels(for: .qwen3ASR) {
            XCTAssertGreaterThan(model.diskSizeMB, 0, "\(model.displayName) diskSizeMB should be positive")
        }
    }

    func testQwen3Catalog_minimumRAMPositive() {
        for model in ModelIdentifier.allModels(for: .qwen3ASR) {
            XCTAssertGreaterThan(model.minimumRAMGB, 0, "\(model.displayName) minimumRAMGB should be positive")
        }
    }

    func testQwen3Catalog_displayNamesAreNonEmpty() {
        for model in ModelIdentifier.allModels(for: .qwen3ASR) {
            XCTAssertFalse(model.displayName.isEmpty, "\(model.variantKey) displayName should not be empty")
        }
    }

    func testQwen3Catalog_variantKeysContainHuggingFacePrefix() {
        for model in ModelIdentifier.allModels(for: .qwen3ASR) {
            XCTAssertTrue(
                model.variantKey.contains("aufklarer/"),
                "\(model.displayName) variantKey should contain HuggingFace org prefix"
            )
        }
    }

    // MARK: - allModels(for:)

    func testAllModels_whisperKit_matchesWhisperVariantAllCases() {
        let models = ModelIdentifier.allModels(for: .whisperKit)
        XCTAssertEqual(models.count, WhisperModelVariant.allCases.count)

        // Verify each WhisperModelVariant is represented
        for variant in WhisperModelVariant.allCases {
            let found = models.contains { $0.variantKey == variant.rawValue }
            XCTAssertTrue(found, "\(variant) should be in allModels(for: .whisperKit)")
        }
    }

    func testAllModels_whisperKit_allHaveWhisperEngine() {
        for model in ModelIdentifier.allModels(for: .whisperKit) {
            XCTAssertEqual(model.engine, .whisperKit)
        }
    }

    func testAllModels_qwen3ASR_hasFourModels() {
        XCTAssertEqual(ModelIdentifier.allModels(for: .qwen3ASR).count, 4)
    }

    // MARK: - find(engine:variantKey:)

    func testFind_existingWhisperModel() {
        let found = ModelIdentifier.find(engine: .whisperKit, variantKey: "openai_whisper-tiny")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.engine, .whisperKit)
        XCTAssertEqual(found?.variantKey, "openai_whisper-tiny")
    }

    func testFind_existingQwenModel() {
        let found = ModelIdentifier.find(engine: .qwen3ASR, variantKey: "aufklarer/Qwen3-ASR-0.6B-MLX-4bit")
        XCTAssertNotNil(found)
        XCTAssertEqual(found, .qwen3_0_6B_4bit)
    }

    func testFind_nonexistentVariantKey_returnsNil() {
        let found = ModelIdentifier.find(engine: .whisperKit, variantKey: "nonexistent")
        XCTAssertNil(found)
    }

    func testFind_wrongEngine_returnsNil() {
        // Whisper variant key searched in Qwen engine
        let found = ModelIdentifier.find(engine: .qwen3ASR, variantKey: "openai_whisper-tiny")
        XCTAssertNil(found)
    }

    func testFind_emptyVariantKey_returnsNil() {
        let found = ModelIdentifier.find(engine: .whisperKit, variantKey: "")
        XCTAssertNil(found)
    }

    func testFind_allWhisperModelsAreFoundable() {
        for variant in WhisperModelVariant.allCases {
            let found = ModelIdentifier.find(engine: .whisperKit, variantKey: variant.rawValue)
            XCTAssertNotNil(found, "\(variant) should be findable")
            XCTAssertEqual(found?.whisperVariant, variant)
        }
    }

    func testFind_allQwenModelsAreFoundable() {
        let qwenModels = ModelIdentifier.allModels(for: .qwen3ASR)
        for model in qwenModels {
            let found = ModelIdentifier.find(engine: .qwen3ASR, variantKey: model.variantKey)
            XCTAssertNotNil(found, "\(model.displayName) should be findable")
            XCTAssertEqual(found, model)
        }
    }
}
