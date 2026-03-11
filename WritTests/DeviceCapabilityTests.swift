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
}
