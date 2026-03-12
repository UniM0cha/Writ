import XCTest
@testable import Writ

/// StartRecordingIntent 및 TranscribeFileIntent 테스트
/// - openAppWhenRun 프로퍼티 검증
/// - AppIntent 프로토콜 준수 확인
final class WritIntentsTests: XCTestCase {

    // MARK: - StartRecordingIntent

    func test_startRecordingIntent_openAppWhenRunIsTrue() {
        // StartRecordingIntent는 ForegroundContinuableIntent에서 AppIntent로 변경됨
        // openAppWhenRun = true 로 설정되어 즉시 앱을 열어야 함
        XCTAssertTrue(
            StartRecordingIntent.openAppWhenRun,
            "StartRecordingIntent는 openAppWhenRun이 true여야 함"
        )
    }

    func test_startRecordingIntent_titleIsNotEmpty() {
        let title = StartRecordingIntent.title
        XCTAssertNotNil(title, "StartRecordingIntent.title은 nil이 아니어야 함")
    }

    func test_startRecordingIntent_descriptionIsNotEmpty() {
        let description = StartRecordingIntent.description
        XCTAssertNotNil(description, "StartRecordingIntent.description은 nil이 아니어야 함")
    }

    func test_startRecordingIntent_canBeInstantiated() {
        // 기본 생성자로 인스턴스 생성이 가능한지 확인
        let intent = StartRecordingIntent()
        XCTAssertNotNil(intent)
    }

    // MARK: - TranscribeFileIntent

    func test_transcribeFileIntent_openAppWhenRunIsTrue() {
        XCTAssertTrue(
            TranscribeFileIntent.openAppWhenRun,
            "TranscribeFileIntent는 openAppWhenRun이 true여야 함"
        )
    }

    func test_transcribeFileIntent_titleIsNotEmpty() {
        let title = TranscribeFileIntent.title
        XCTAssertNotNil(title, "TranscribeFileIntent.title은 nil이 아니어야 함")
    }

    // MARK: - 파일 확장자 추출 로직 (Fix 9)
    //
    // TranscribeFileIntent.perform()에서 사용하는 확장자 추출 로직:
    //   let ext = (audioFile.filename as NSString).pathExtension
    //   let safeExt = ext.isEmpty ? "m4a" : ext
    //
    // NSString.pathExtension 동작을 직접 검증한다.

    func test_fileExtension_wavFile() {
        let ext = ("recording.wav" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "wav")
    }

    func test_fileExtension_mp3File() {
        let ext = ("recording.mp3" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "mp3")
    }

    func test_fileExtension_m4aFile() {
        let ext = ("recording.m4a" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "m4a")
    }

    func test_fileExtension_noExtension() {
        // 확장자가 없는 파일명 -> 빈 문자열 -> 기본값 "m4a"
        let ext = ("recording" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "m4a", "확장자가 없으면 기본값 m4a를 사용해야 함")
    }

    func test_fileExtension_dotOnly() {
        // "recording." -> pathExtension은 빈 문자열
        let ext = ("recording." as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "m4a", "빈 확장자는 기본값 m4a를 사용해야 함")
    }

    func test_fileExtension_doubleExtension() {
        // "recording.tar.gz" -> pathExtension은 "gz"
        let ext = ("recording.tar.gz" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "gz", "이중 확장자에서는 마지막 확장자를 사용해야 함")
    }

    func test_fileExtension_uppercaseExtension() {
        // 대문자 확장자도 그대로 보존되어야 함
        let ext = ("recording.WAV" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "WAV")
    }

    func test_fileExtension_flacFile() {
        let ext = ("voice_memo.flac" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "flac")
    }

    func test_fileExtension_cafFile() {
        // macOS Core Audio Format
        let ext = ("recording.caf" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "caf")
    }

    func test_fileExtension_hiddenFile() {
        // ".hidden" -> NSString.pathExtension은 빈 문자열을 반환 (숨김 파일 취급)
        // 따라서 기본값 "m4a"로 폴백된다
        let ext = (".hidden" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "m4a", "숨김 파일명은 확장자 없음으로 처리되어 m4a로 폴백")
    }

    func test_fileExtension_pathWithDirectories() {
        // 경로에 디렉토리가 포함된 경우에도 올바르게 동작해야 함
        let ext = ("path/to/recording.opus" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "opus")
    }

    func test_fileExtension_emptyString() {
        // 빈 문자열 -> pathExtension은 빈 문자열
        let ext = ("" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "m4a", "빈 파일명은 기본값 m4a를 사용해야 함")
    }

    func test_fileExtension_spaceInFileName() {
        let ext = ("my recording.aac" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "aac")
    }

    func test_fileExtension_koreanFileName() {
        // 한글 파일명에서도 확장자 추출이 정상 동작해야 함
        let ext = ("녹음파일.wav" as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        XCTAssertEqual(safeExt, "wav")
    }

    func test_fileExtension_intentFileURL_generatesCorrectPath() {
        // TranscribeFileIntent에서 생성하는 파일 경로의 확장자가 올바른지 확인
        let filename = "test_audio.mp3"
        let ext = (filename as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        let destURL = AppGroupConstants.recordingsDirectory
            .appendingPathComponent("intent_\(UUID().uuidString).\(safeExt)")
        XCTAssertEqual(destURL.pathExtension, "mp3",
                       "생성된 URL의 확장자가 원본 파일의 확장자와 일치해야 함")
    }

    func test_fileExtension_intentFileURL_fallbackForNoExtension() {
        // 확장자 없는 파일은 .m4a로 폴백
        let filename = "audio_without_extension"
        let ext = (filename as NSString).pathExtension
        let safeExt = ext.isEmpty ? "m4a" : ext
        let destURL = AppGroupConstants.recordingsDirectory
            .appendingPathComponent("intent_\(UUID().uuidString).\(safeExt)")
        XCTAssertEqual(destURL.pathExtension, "m4a",
                       "확장자 없는 파일은 .m4a 확장자로 저장되어야 함")
    }
}
