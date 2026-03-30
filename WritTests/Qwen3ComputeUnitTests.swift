#if os(iOS) || os(macOS)
import XCTest
import CoreML
@testable import Writ

/// Qwen3CoreMLInference의 플랫폼별 compute unit 선택 검증
final class Qwen3ComputeUnitTests: XCTestCase {

    // MARK: - Encoder Compute Units

    func test_encoderComputeUnits_returnsExpectedValue() {
        let units = Qwen3CoreMLInference.encoderComputeUnits()
        #if os(macOS)
        XCTAssertEqual(units, .cpuAndGPU, "macOS 인코더는 GPU를 사용해야 함")
        #else
        XCTAssertEqual(units, .cpuAndNeuralEngine, "iOS 인코더는 ANE를 사용해야 함")
        #endif
    }

    // MARK: - Decoder Compute Units

    func test_decoderComputeUnits_returnsExpectedValue() {
        let units = Qwen3CoreMLInference.decoderComputeUnits()
        #if os(macOS)
        XCTAssertEqual(units, .cpuAndGPU, "macOS 디코더는 GPU를 사용해야 함")
        #else
        XCTAssertEqual(units, .cpuOnly, "iOS 디코더는 CPU만 사용해야 함")
        #endif
    }

    // MARK: - Encoder vs Decoder 차별화

    func test_encoderAndDecoder_differOnIOS() {
        #if os(iOS)
        let enc = Qwen3CoreMLInference.encoderComputeUnits()
        let dec = Qwen3CoreMLInference.decoderComputeUnits()
        XCTAssertNotEqual(enc, dec, "iOS에서 인코더와 디코더는 다른 compute unit을 사용해야 함")
        #endif
    }

    func test_encoderAndDecoder_sameOnMacOS() {
        #if os(macOS)
        let enc = Qwen3CoreMLInference.encoderComputeUnits()
        let dec = Qwen3CoreMLInference.decoderComputeUnits()
        XCTAssertEqual(enc, dec, "macOS에서 인코더와 디코더는 모두 GPU를 사용해야 함")
        #endif
    }

    // MARK: - Static Method Signature (Compile-time)

    func test_encoderComputeUnits_isStaticMethod() {
        // static func encoderComputeUnits() -> MLComputeUnits 시그니처 컴파일 타임 검증
        typealias EncoderFunc = () -> MLComputeUnits
        let _: EncoderFunc = Qwen3CoreMLInference.encoderComputeUnits
    }

    func test_decoderComputeUnits_isStaticMethod() {
        // static func decoderComputeUnits() -> MLComputeUnits 시그니처 컴파일 타임 검증
        typealias DecoderFunc = () -> MLComputeUnits
        let _: DecoderFunc = Qwen3CoreMLInference.decoderComputeUnits
    }

    // MARK: - Return Value Consistency

    func test_encoderComputeUnits_isIdempotent() {
        // 동일한 플랫폼에서 반복 호출 시 동일한 값 반환
        let first = Qwen3CoreMLInference.encoderComputeUnits()
        let second = Qwen3CoreMLInference.encoderComputeUnits()
        XCTAssertEqual(first, second, "encoderComputeUnits()는 항상 동일한 값을 반환해야 함")
    }

    func test_decoderComputeUnits_isIdempotent() {
        // 동일한 플랫폼에서 반복 호출 시 동일한 값 반환
        let first = Qwen3CoreMLInference.decoderComputeUnits()
        let second = Qwen3CoreMLInference.decoderComputeUnits()
        XCTAssertEqual(first, second, "decoderComputeUnits()는 항상 동일한 값을 반환해야 함")
    }

    // MARK: - Neither Uses .all (Explicit Unit Selection)

    func test_encoderComputeUnits_neverReturnsAll() {
        // .all은 런타임에 예기치 않은 유닛을 선택할 수 있으므로 사용하지 않아야 함
        let units = Qwen3CoreMLInference.encoderComputeUnits()
        XCTAssertNotEqual(units, .all, "인코더는 .all을 사용하지 않아야 함 (명시적 유닛 선택 필요)")
    }

    func test_decoderComputeUnits_neverReturnsAll() {
        let units = Qwen3CoreMLInference.decoderComputeUnits()
        XCTAssertNotEqual(units, .all, "디코더는 .all을 사용하지 않아야 함 (명시적 유닛 선택 필요)")
    }

    // MARK: - iOS Decoder Never Uses ANE (MLState Incompatibility)

    func test_decoderComputeUnits_neverUsesNeuralEngine() {
        // iOS 디코더는 MLState KV 캐시가 ANE와 호환되지 않으므로 ANE를 사용하면 안 됨
        let units = Qwen3CoreMLInference.decoderComputeUnits()
        XCTAssertNotEqual(units, .cpuAndNeuralEngine,
                         "디코더는 cpuAndNeuralEngine을 사용하면 안 됨 (MLState KV 캐시 미호환)")
    }
}
#endif
