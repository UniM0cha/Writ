import XCTest
@testable import Writ

/// TranscriptionStatus 열거형 및 Transcription 모델 테스트
final class TranscriptionStatusTests: XCTestCase {

    // MARK: - Cases & RawValue

    func testAllCasesExist() {
        let pending = TranscriptionStatus.pending
        let inProgress = TranscriptionStatus.inProgress
        let completed = TranscriptionStatus.completed
        let failed = TranscriptionStatus.failed

        XCTAssertEqual(pending.rawValue, "pending")
        XCTAssertEqual(inProgress.rawValue, "inProgress")
        XCTAssertEqual(completed.rawValue, "completed")
        XCTAssertEqual(failed.rawValue, "failed")
    }

    func testInitFromValidRawValue() {
        XCTAssertEqual(TranscriptionStatus(rawValue: "pending"), .pending)
        XCTAssertEqual(TranscriptionStatus(rawValue: "inProgress"), .inProgress)
        XCTAssertEqual(TranscriptionStatus(rawValue: "completed"), .completed)
        XCTAssertEqual(TranscriptionStatus(rawValue: "failed"), .failed)
    }

    func testInitFromInvalidRawValue() {
        XCTAssertNil(TranscriptionStatus(rawValue: ""))
        XCTAssertNil(TranscriptionStatus(rawValue: "unknown"))
        XCTAssertNil(TranscriptionStatus(rawValue: "Pending")) // 대소문자 구분
        XCTAssertNil(TranscriptionStatus(rawValue: "in_progress"))
        XCTAssertNil(TranscriptionStatus(rawValue: "COMPLETED"))
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip_allCases() throws {
        let statuses: [TranscriptionStatus] = [.pending, .inProgress, .completed, .failed]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for status in statuses {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(TranscriptionStatus.self, from: data)
            XCTAssertEqual(decoded, status, "\(status) Codable 라운드트립 실패")
        }
    }

    func testDecodingFromRawString() throws {
        let json = Data("\"inProgress\"".utf8)
        let decoded = try JSONDecoder().decode(TranscriptionStatus.self, from: json)
        XCTAssertEqual(decoded, .inProgress)
    }

    func testDecodingInvalidRawValueThrows() {
        let json = Data("\"invalid_status\"".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(TranscriptionStatus.self, from: json))
    }

    func testEncodingProducesRawValueString() throws {
        let data = try JSONEncoder().encode(TranscriptionStatus.completed)
        let string = String(data: data, encoding: .utf8)
        XCTAssertEqual(string, "\"completed\"")
    }

    // MARK: - Sendable

    func testSendable_canBePassedAcrossConcurrencyBoundary() async {
        let status: TranscriptionStatus = .inProgress
        let result = await Task.detached {
            return status
        }.value
        XCTAssertEqual(result, .inProgress)
    }

    // MARK: - Equatable

    func testEquatable_sameCases() {
        XCTAssertEqual(TranscriptionStatus.pending, TranscriptionStatus.pending)
        XCTAssertEqual(TranscriptionStatus.inProgress, TranscriptionStatus.inProgress)
        XCTAssertEqual(TranscriptionStatus.completed, TranscriptionStatus.completed)
        XCTAssertEqual(TranscriptionStatus.failed, TranscriptionStatus.failed)
    }

    func testEquatable_differentCases() {
        XCTAssertNotEqual(TranscriptionStatus.pending, TranscriptionStatus.inProgress)
        XCTAssertNotEqual(TranscriptionStatus.pending, TranscriptionStatus.completed)
        XCTAssertNotEqual(TranscriptionStatus.pending, TranscriptionStatus.failed)
        XCTAssertNotEqual(TranscriptionStatus.inProgress, TranscriptionStatus.completed)
        XCTAssertNotEqual(TranscriptionStatus.completed, TranscriptionStatus.failed)
    }
}

// MARK: - Transcription 모델 테스트

@MainActor
final class TranscriptionModelTests: XCTestCase {

    // MARK: - 기본 초기화

    func testInit_defaultValues() {
        let transcription = Transcription()
        XCTAssertFalse(transcription.id.uuidString.isEmpty, "id는 유효한 UUID여야 함")
        XCTAssertEqual(transcription.text, "", "기본 텍스트는 빈 문자열이어야 함")
        XCTAssertEqual(transcription.modelUsed, "", "기본 modelUsed는 빈 문자열이어야 함")
        XCTAssertEqual(transcription.status, .pending, "기본 상태는 pending이어야 함")
        XCTAssertEqual(transcription.progress, 0, "기본 progress는 0이어야 함")
        XCTAssertTrue(transcription.segments == nil || transcription.segments?.isEmpty == true, "기본 segments는 nil이거나 빈 배열이어야 함")
    }

    func testInit_customValues() {
        let customID = UUID()
        let customDate = Date.distantPast
        let transcription = Transcription(
            id: customID,
            text: "안녕하세요",
            modelUsed: "Tiny",
            createdAt: customDate,
            status: .completed
        )

        XCTAssertEqual(transcription.id, customID)
        XCTAssertEqual(transcription.text, "안녕하세요")
        XCTAssertEqual(transcription.modelUsed, "Tiny")
        XCTAssertEqual(transcription.createdAt, customDate)
        XCTAssertEqual(transcription.status, .completed)
    }

    // MARK: - progress 필드

    func testProgress_defaultIsZero() {
        let transcription = Transcription()
        XCTAssertEqual(transcription.progress, 0, accuracy: 0.001)
    }

    func testProgress_canBeSetToOne() {
        // 전사 완료 시 progress가 1로 설정되는지 확인
        let transcription = Transcription(status: .inProgress)
        transcription.progress = 1
        XCTAssertEqual(transcription.progress, 1, accuracy: 0.001)
    }

    func testProgress_canBeSetToPartialValue() {
        let transcription = Transcription()
        transcription.progress = 0.5
        XCTAssertEqual(transcription.progress, 0.5, accuracy: 0.001)
    }

    func testProgress_boundaryValues() {
        let transcription = Transcription()

        // 0% (시작)
        transcription.progress = 0
        XCTAssertEqual(transcription.progress, 0, accuracy: 0.001)

        // 100% (완료)
        transcription.progress = 1
        XCTAssertEqual(transcription.progress, 1, accuracy: 0.001)
    }

    // MARK: - status 변경

    func testStatus_canTransitionFromPendingToInProgress() {
        let transcription = Transcription(status: .pending)
        transcription.status = .inProgress
        XCTAssertEqual(transcription.status, .inProgress)
    }

    func testStatus_canTransitionFromInProgressToCompleted() {
        let transcription = Transcription(status: .inProgress)
        transcription.status = .completed
        XCTAssertEqual(transcription.status, .completed)
    }

    func testStatus_canTransitionFromInProgressToFailed() {
        let transcription = Transcription(status: .inProgress)
        transcription.status = .failed
        XCTAssertEqual(transcription.status, .failed)
    }

    func testStatus_canTransitionFromInProgressToPending() {
        // 백그라운드 태스크 만료 시 inProgress → pending으로 되돌림
        let transcription = Transcription(status: .inProgress)
        transcription.status = .pending
        XCTAssertEqual(transcription.status, .pending)
    }

    // MARK: - text 업데이트

    func testText_canBeUpdatedAfterInit() {
        let transcription = Transcription()
        XCTAssertEqual(transcription.text, "")

        transcription.text = "전사된 텍스트입니다."
        XCTAssertEqual(transcription.text, "전사된 텍스트입니다.")
    }

    func testText_canHandleLongString() {
        let longText = String(repeating: "가나다라마바사 ", count: 1000)
        let transcription = Transcription(text: longText)
        XCTAssertEqual(transcription.text, longText)
    }

    func testText_canHandleMultilineString() {
        let multilineText = "첫 번째 줄\n두 번째 줄\n세 번째 줄"
        let transcription = Transcription(text: multilineText)
        XCTAssertEqual(transcription.text, multilineText)
    }

    // MARK: - modelUsed 업데이트

    func testModelUsed_canBeUpdated() {
        let transcription = Transcription(modelUsed: "Tiny")
        transcription.modelUsed = "Small"
        XCTAssertEqual(transcription.modelUsed, "Small")
    }

    // MARK: - 고유 ID

    func testEachTranscription_hasUniqueId() {
        let t1 = Transcription()
        let t2 = Transcription()
        XCTAssertNotEqual(t1.id, t2.id, "각 Transcription은 고유한 ID를 가져야 함")
    }
}
