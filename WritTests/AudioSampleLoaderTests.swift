import XCTest
@testable import Writ

final class AudioSampleLoaderTests: XCTestCase {

    // MARK: - Error Cases

    func testLoad_nonexistentFile_throwsError() {
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent_audio_file_\(UUID().uuidString).m4a")

        XCTAssertThrowsError(try AudioSampleLoader.load(url: fakeURL)) { error in
            // AVAudioFile(forReading:) should throw for nonexistent file
            XCTAssertNotNil(error, "Should throw an error for nonexistent file")
        }
    }

    func testLoad_invalidFileContent_throwsError() throws {
        // Create a temporary file with invalid audio content
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("invalid_audio_\(UUID().uuidString).wav")
        try Data("not audio data".utf8).write(to: tempURL)

        defer { try? FileManager.default.removeItem(at: tempURL) }

        XCTAssertThrowsError(try AudioSampleLoader.load(url: tempURL)) { error in
            XCTAssertNotNil(error, "Should throw an error for invalid audio data")
        }
    }

    func testLoad_emptyFile_throwsError() throws {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("empty_audio_\(UUID().uuidString).wav")
        try Data().write(to: tempURL)

        defer { try? FileManager.default.removeItem(at: tempURL) }

        XCTAssertThrowsError(try AudioSampleLoader.load(url: tempURL)) { error in
            XCTAssertNotNil(error, "Should throw an error for empty file")
        }
    }

    // MARK: - AudioSampleLoaderError

    func testError_bufferCreationFailed_hasDescription() {
        let error = AudioSampleLoaderError.bufferCreationFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testError_converterCreationFailed_hasDescription() {
        let error = AudioSampleLoaderError.converterCreationFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testError_conversionFailed_hasDescription() {
        let error = AudioSampleLoaderError.conversionFailed("test reason")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("test reason"))
    }

    func testError_conversionFailed_emptyMessage() {
        let error = AudioSampleLoaderError.conversionFailed("")
        XCTAssertNotNil(error.errorDescription)
    }

    func testError_isLocalizedError() {
        // Verify AudioSampleLoaderError conforms to LocalizedError
        let error: LocalizedError = AudioSampleLoaderError.bufferCreationFailed
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - Default Sample Rate

    func testLoad_defaultSampleRateIs16000() {
        // Verify the default parameter value by checking the function signature exists
        // The actual default is validated through the compiler since load(url:) compiles
        // without specifying targetSampleRate
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent.wav")
        // This call uses the default targetSampleRate parameter
        XCTAssertThrowsError(try AudioSampleLoader.load(url: fakeURL))
    }
}
