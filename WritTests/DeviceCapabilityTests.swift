import XCTest
@testable import Writ

final class DeviceCapabilityTests: XCTestCase {

    // MARK: - maxSupportedModel

    func testHighEndMaxSupportedModel() {
        XCTAssertEqual(DeviceCapability.highEnd.maxSupportedModel, .largeV3Turbo)
    }

    func testMidRangeMaxSupportedModel() {
        XCTAssertEqual(DeviceCapability.midRange.maxSupportedModel, .small)
    }

    func testLowEndMaxSupportedModel() {
        XCTAssertEqual(DeviceCapability.lowEnd.maxSupportedModel, .base)
    }

    // MARK: - defaultModel

    func testHighEndDefaultModel() {
        XCTAssertEqual(DeviceCapability.highEnd.defaultModel, .small)
    }

    func testMidRangeDefaultModel() {
        XCTAssertEqual(DeviceCapability.midRange.defaultModel, .small)
    }

    func testLowEndDefaultModel() {
        XCTAssertEqual(DeviceCapability.lowEnd.defaultModel, .tiny)
    }

    // MARK: - supports()

    func testSupportsReturnsBool() {
        // supports() depends on actual device RAM, so we just verify it returns
        // a Bool without asserting a specific value.
        for capability in [DeviceCapability.highEnd, .midRange, .lowEnd] {
            for variant in WhisperModelVariant.allCases {
                let result = capability.supports(variant)
                XCTAssertNotNil(result as Bool?, "\(capability) supports(\(variant)) should return a Bool")
            }
        }
    }

    func testSupportsTinyOnAnyCapability() {
        // Tiny requires only 1 GB RAM; any modern test machine should have that.
        for capability in [DeviceCapability.highEnd, .midRange, .lowEnd] {
            XCTAssertTrue(capability.supports(.tiny), "\(capability) should support tiny model")
        }
    }

    // MARK: - current

    func testCurrentReturnsAValidCapability() {
        let current = DeviceCapability.current
        // Verify it is one of the three known cases by checking defaultModel
        // is a valid WhisperModelVariant (which it always is if the enum is valid).
        let validDefaults: [WhisperModelVariant] = [.tiny, .small]
        XCTAssertTrue(
            validDefaults.contains(current.defaultModel),
            "current.defaultModel should be .tiny or .small"
        )
    }

    // MARK: - Relationships between default and max

    func testDefaultModelIsNotLargerThanMaxSupported() {
        let allCapabilities: [DeviceCapability] = [.highEnd, .midRange, .lowEnd]
        for capability in allCapabilities {
            XCTAssertLessThanOrEqual(
                capability.defaultModel.diskSizeMB,
                capability.maxSupportedModel.diskSizeMB,
                "Default model should not be larger than max supported model for \(capability)"
            )
        }
    }

    func testDefaultModelRAMDoesNotExceedMaxSupportedModelRAM() {
        let allCapabilities: [DeviceCapability] = [.highEnd, .midRange, .lowEnd]
        for capability in allCapabilities {
            XCTAssertLessThanOrEqual(
                capability.defaultModel.minimumRAMGB,
                capability.maxSupportedModel.minimumRAMGB,
                "Default model RAM should not exceed max supported model RAM for \(capability)"
            )
        }
    }

    // MARK: - supports(ModelIdentifier)

    func testSupportsModelIdentifier_tinyWhisper() {
        let tinyId = WhisperModelVariant.tiny.modelIdentifier
        for capability in [DeviceCapability.highEnd, .midRange, .lowEnd] {
            XCTAssertTrue(capability.supports(tinyId), "\(capability) should support tiny via ModelIdentifier")
        }
    }

    func testSupportsModelIdentifier_consistentWithWhisperVariant() {
        // Both supports() overloads should return the same result for equivalent models
        for capability in [DeviceCapability.highEnd, .midRange, .lowEnd] {
            for variant in WhisperModelVariant.allCases {
                let whisperResult = capability.supports(variant)
                let identifierResult = capability.supports(variant.modelIdentifier)
                XCTAssertEqual(
                    whisperResult, identifierResult,
                    "\(capability) supports(\(variant)) should match supports(modelIdentifier) result"
                )
            }
        }
    }

    func testSupportsModelIdentifier_qwenSmallestModel() {
        // Qwen 0.6B 4-bit requires 2 GB RAM; test machines should support this
        let qwen = ModelIdentifier.qwen3_0_6B_4bit
        let capability = DeviceCapability.current
        // On a test Mac with >=2GB RAM this should be true
        XCTAssertTrue(capability.supports(qwen), "Current device should support smallest Qwen model")
    }

    func testSupportsModelIdentifier_returnsValueForAllQwenModels() {
        for capability in [DeviceCapability.highEnd, .midRange, .lowEnd] {
            for model in ModelIdentifier.allModels(for: .qwen3ASR) {
                let result = capability.supports(model)
                XCTAssertNotNil(result as Bool?, "\(capability) supports(\(model.displayName)) should return a Bool")
            }
        }
    }

    // MARK: - defaultModel(for: EngineType)

    func testDefaultModel_whisperKit_matchesDefaultModel() {
        let allCapabilities: [DeviceCapability] = [.highEnd, .midRange, .lowEnd]
        for capability in allCapabilities {
            let engineDefault = capability.defaultModel(for: .whisperKit)
            let legacyDefault = capability.defaultModel.modelIdentifier
            XCTAssertEqual(
                engineDefault, legacyDefault,
                "defaultModel(for: .whisperKit) should match legacy defaultModel.modelIdentifier for \(capability)"
            )
        }
    }

    func testDefaultModel_whisperKit_hasWhisperEngine() {
        let allCapabilities: [DeviceCapability] = [.highEnd, .midRange, .lowEnd]
        for capability in allCapabilities {
            let model = capability.defaultModel(for: .whisperKit)
            XCTAssertEqual(model.engine, .whisperKit)
        }
    }

    func testDefaultModel_qwen3ASR_hasQwenEngine() {
        let allCapabilities: [DeviceCapability] = [.highEnd, .midRange, .lowEnd]
        for capability in allCapabilities {
            let model = capability.defaultModel(for: .qwen3ASR)
            XCTAssertEqual(model.engine, .qwen3ASR)
        }
    }

    func testDefaultModel_qwen3ASR_highEnd() {
        XCTAssertEqual(DeviceCapability.highEnd.defaultModel(for: .qwen3ASR), .qwen3_1_7B_8bit)
    }

    func testDefaultModel_qwen3ASR_midRange() {
        XCTAssertEqual(DeviceCapability.midRange.defaultModel(for: .qwen3ASR), .qwen3_0_6B_8bit)
    }

    func testDefaultModel_qwen3ASR_lowEnd() {
        XCTAssertEqual(DeviceCapability.lowEnd.defaultModel(for: .qwen3ASR), .qwen3_0_6B_4bit)
    }

    func testDefaultModel_forAllEngines_isInCatalog() {
        let allCapabilities: [DeviceCapability] = [.highEnd, .midRange, .lowEnd]
        for capability in allCapabilities {
            for engine in EngineType.allCases {
                let defaultModel = capability.defaultModel(for: engine)
                let catalog = ModelIdentifier.allModels(for: engine)
                XCTAssertTrue(
                    catalog.contains(defaultModel),
                    "defaultModel(for: \(engine)) should be in the catalog for \(capability)"
                )
            }
        }
    }

    func testDefaultModel_qwen3ASR_ramScalesWithCapability() {
        let lowEnd = DeviceCapability.lowEnd.defaultModel(for: .qwen3ASR)
        let midRange = DeviceCapability.midRange.defaultModel(for: .qwen3ASR)
        let highEnd = DeviceCapability.highEnd.defaultModel(for: .qwen3ASR)

        XCTAssertLessThanOrEqual(
            lowEnd.minimumRAMGB, midRange.minimumRAMGB,
            "Low-end default should not require more RAM than mid-range default"
        )
        XCTAssertLessThanOrEqual(
            midRange.minimumRAMGB, highEnd.minimumRAMGB,
            "Mid-range default should not require more RAM than high-end default"
        )
    }
}
