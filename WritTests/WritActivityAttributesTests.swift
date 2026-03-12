import XCTest
@testable import Writ

// MARK: - ActivityPhase Tests

@MainActor
final class ActivityPhaseTests: XCTestCase {

    // MARK: - Cases & RawValue

    func testAllCasesExist() {
        // ActivityPhase 열거형의 모든 케이스가 존재하는지 확인
        let recording = ActivityPhase.recording
        let transcribing = ActivityPhase.transcribing
        let completed = ActivityPhase.completed

        XCTAssertEqual(recording.rawValue, "recording")
        XCTAssertEqual(transcribing.rawValue, "transcribing")
        XCTAssertEqual(completed.rawValue, "completed")
    }

    func testInitFromValidRawValue() {
        XCTAssertEqual(ActivityPhase(rawValue: "recording"), .recording)
        XCTAssertEqual(ActivityPhase(rawValue: "transcribing"), .transcribing)
        XCTAssertEqual(ActivityPhase(rawValue: "completed"), .completed)
    }

    func testInitFromInvalidRawValue() {
        XCTAssertNil(ActivityPhase(rawValue: "invalid"))
        XCTAssertNil(ActivityPhase(rawValue: ""))
        XCTAssertNil(ActivityPhase(rawValue: "Recording")) // 대소문자 구분
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip_allCases() throws {
        let phases: [ActivityPhase] = [.recording, .transcribing, .completed]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for phase in phases {
            let data = try encoder.encode(phase)
            let decoded = try decoder.decode(ActivityPhase.self, from: data)
            XCTAssertEqual(decoded, phase, "\(phase) Codable 라운드트립 실패")
        }
    }

    func testDecodingFromRawString() throws {
        let json = Data("\"transcribing\"".utf8)
        let decoded = try JSONDecoder().decode(ActivityPhase.self, from: json)
        XCTAssertEqual(decoded, .transcribing)
    }

    func testDecodingInvalidValue_fallsBackToRecording() throws {
        // 수동 Codable 구현에서 유효하지 않은 값은 .recording으로 폴백
        let json = Data("\"unknown_phase\"".utf8)
        let decoded = try JSONDecoder().decode(ActivityPhase.self, from: json)
        XCTAssertEqual(decoded, .recording, "유효하지 않은 값은 .recording으로 폴백해야 함")
    }

    func testEncodingProducesRawValueString() throws {
        let data = try JSONEncoder().encode(ActivityPhase.completed)
        let string = String(data: data, encoding: .utf8)
        XCTAssertEqual(string, "\"completed\"")
    }

    // MARK: - Hashable

    func testHashable_equalValuesHaveSameHash() {
        let a = ActivityPhase.recording
        let b = ActivityPhase.recording
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testHashable_differentValuesAreDifferent() {
        // 다른 케이스는 동일하지 않아야 함
        XCTAssertNotEqual(ActivityPhase.recording, ActivityPhase.transcribing)
        XCTAssertNotEqual(ActivityPhase.transcribing, ActivityPhase.completed)
        XCTAssertNotEqual(ActivityPhase.recording, ActivityPhase.completed)
    }

    func testHashable_canBeUsedInSet() {
        let set: Set<ActivityPhase> = [.recording, .transcribing, .completed, .recording]
        XCTAssertEqual(set.count, 3, "Set에 중복 없이 3개 케이스가 있어야 함")
    }

    func testHashable_canBeUsedAsDictionaryKey() {
        var dict: [ActivityPhase: String] = [:]
        dict[.recording] = "rec"
        dict[.transcribing] = "trans"
        dict[.completed] = "done"
        XCTAssertEqual(dict[.recording], "rec")
        XCTAssertEqual(dict[.transcribing], "trans")
        XCTAssertEqual(dict[.completed], "done")
    }
}

// MARK: - WritActivityAttributes.ContentState Tests

@MainActor
final class ContentStateTests: XCTestCase {

    // MARK: - Initialization

    func testInit_allFieldsStored() {
        let date = Date(timeIntervalSince1970: 1000)
        let state = WritActivityAttributes.ContentState(
            phase: .transcribing,
            recordingDuration: 42.5,
            recordingStartDate: date,
            averagePower: -12.3,
            transcriptionProgress: 0.75
        )

        XCTAssertEqual(state.phase, .transcribing)
        XCTAssertEqual(state.recordingDuration, 42.5)
        XCTAssertEqual(state.recordingStartDate, date)
        XCTAssertEqual(state.averagePower, -12.3, accuracy: 0.001)
        XCTAssertEqual(state.transcriptionProgress, 0.75, accuracy: 0.001)
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip_recording() throws {
        let date = Date(timeIntervalSince1970: 1700000000)
        let original = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 10.5,
            recordingStartDate: date,
            averagePower: -20.0,
            transcriptionProgress: 0.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WritActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.phase, original.phase)
        XCTAssertEqual(decoded.recordingDuration, original.recordingDuration, accuracy: 0.001)
        XCTAssertEqual(decoded.recordingStartDate, original.recordingStartDate)
        XCTAssertEqual(decoded.averagePower, original.averagePower, accuracy: 0.001)
        XCTAssertEqual(decoded.transcriptionProgress, original.transcriptionProgress, accuracy: 0.001)
    }

    func testCodableRoundtrip_transcribing() throws {
        let date = Date()
        let original = WritActivityAttributes.ContentState(
            phase: .transcribing,
            recordingDuration: 0,
            recordingStartDate: date,
            averagePower: 0,
            transcriptionProgress: 0.5
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WritActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.phase, .transcribing)
        XCTAssertEqual(decoded.transcriptionProgress, 0.5, accuracy: 0.001)
    }

    func testCodableRoundtrip_completed() throws {
        let date = Date()
        let original = WritActivityAttributes.ContentState(
            phase: .completed,
            recordingDuration: 0,
            recordingStartDate: date,
            averagePower: 0,
            transcriptionProgress: 1.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WritActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.phase, .completed)
        XCTAssertEqual(decoded.transcriptionProgress, 1.0, accuracy: 0.001)
    }

    func testCodableRoundtrip_boundaryValues() throws {
        // 경계값: 매우 큰 duration, 음수 power, 0.0/1.0 progress
        let date = Date(timeIntervalSince1970: 0)
        let original = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 86400.0, // 24시간
            recordingStartDate: date,
            averagePower: -160.0, // 매우 낮은 파워
            transcriptionProgress: 0.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WritActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.recordingDuration, 86400.0, accuracy: 0.001)
        XCTAssertEqual(decoded.averagePower, -160.0, accuracy: 0.001)
    }

    func testEncodingContainsAllKeys() throws {
        let date = Date(timeIntervalSince1970: 1000)
        let state = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 5.0,
            recordingStartDate: date,
            averagePower: -10.0,
            transcriptionProgress: 0.3
        )

        let data = try JSONEncoder().encode(state)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // 모든 CodingKey가 JSON에 포함되어 있는지 확인
        XCTAssertNotNil(json?["phase"])
        XCTAssertNotNil(json?["recordingDuration"])
        XCTAssertNotNil(json?["recordingStartDate"])
        XCTAssertNotNil(json?["averagePower"])
        XCTAssertNotNil(json?["transcriptionProgress"])
    }

    // MARK: - Hashable & Equatable

    func testEquatable_sameValues() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 10.0,
            recordingStartDate: date,
            averagePower: -5.0,
            transcriptionProgress: 0.0
        )
        let b = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 10.0,
            recordingStartDate: date,
            averagePower: -5.0,
            transcriptionProgress: 0.0
        )
        XCTAssertEqual(a, b)
    }

    func testEquatable_differentPhase() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 10.0,
            recordingStartDate: date,
            averagePower: -5.0,
            transcriptionProgress: 0.0
        )
        let b = WritActivityAttributes.ContentState(
            phase: .transcribing,
            recordingDuration: 10.0,
            recordingStartDate: date,
            averagePower: -5.0,
            transcriptionProgress: 0.0
        )
        XCTAssertNotEqual(a, b)
    }

    func testEquatable_differentDuration() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 10.0,
            recordingStartDate: date,
            averagePower: -5.0,
            transcriptionProgress: 0.0
        )
        let b = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 20.0,
            recordingStartDate: date,
            averagePower: -5.0,
            transcriptionProgress: 0.0
        )
        XCTAssertNotEqual(a, b)
    }

    func testEquatable_differentProgress() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = WritActivityAttributes.ContentState(
            phase: .transcribing,
            recordingDuration: 0,
            recordingStartDate: date,
            averagePower: 0,
            transcriptionProgress: 0.5
        )
        let b = WritActivityAttributes.ContentState(
            phase: .transcribing,
            recordingDuration: 0,
            recordingStartDate: date,
            averagePower: 0,
            transcriptionProgress: 0.8
        )
        XCTAssertNotEqual(a, b)
    }

    func testEquatable_differentDate() {
        let a = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 10.0,
            recordingStartDate: Date(timeIntervalSince1970: 1000),
            averagePower: -5.0,
            transcriptionProgress: 0.0
        )
        let b = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 10.0,
            recordingStartDate: Date(timeIntervalSince1970: 2000),
            averagePower: -5.0,
            transcriptionProgress: 0.0
        )
        XCTAssertNotEqual(a, b)
    }

    func testEquatable_differentPower() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 10.0,
            recordingStartDate: date,
            averagePower: -5.0,
            transcriptionProgress: 0.0
        )
        let b = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 10.0,
            recordingStartDate: date,
            averagePower: -10.0,
            transcriptionProgress: 0.0
        )
        XCTAssertNotEqual(a, b)
    }

    func testHashable_equalObjectsSameHash() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 10.0,
            recordingStartDate: date,
            averagePower: -5.0,
            transcriptionProgress: 0.0
        )
        let b = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 10.0,
            recordingStartDate: date,
            averagePower: -5.0,
            transcriptionProgress: 0.0
        )
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testHashable_canBeUsedInSet() {
        let date = Date(timeIntervalSince1970: 1000)
        let state1 = WritActivityAttributes.ContentState(
            phase: .recording, recordingDuration: 0,
            recordingStartDate: date, averagePower: 0, transcriptionProgress: 0
        )
        let state2 = WritActivityAttributes.ContentState(
            phase: .transcribing, recordingDuration: 0,
            recordingStartDate: date, averagePower: 0, transcriptionProgress: 0.5
        )
        let state3 = WritActivityAttributes.ContentState(
            phase: .recording, recordingDuration: 0,
            recordingStartDate: date, averagePower: 0, transcriptionProgress: 0
        )

        let set: Set<WritActivityAttributes.ContentState> = [state1, state2, state3]
        XCTAssertEqual(set.count, 2, "state1과 state3이 동일하므로 Set에 2개만 있어야 함")
    }
}

// MARK: - ContentState Factory Methods Tests

@MainActor
final class ContentStateFactoryTests: XCTestCase {

    // MARK: - .recording(duration:startDate:power:)

    func testRecordingFactory_setsPhaseToRecording() {
        let date = Date(timeIntervalSince1970: 5000)
        let state = WritActivityAttributes.ContentState.recording(
            duration: 30.0, startDate: date, power: -15.5
        )

        XCTAssertEqual(state.phase, .recording)
    }

    func testRecordingFactory_storesAllParameters() {
        let date = Date(timeIntervalSince1970: 5000)
        let state = WritActivityAttributes.ContentState.recording(
            duration: 30.0, startDate: date, power: -15.5
        )

        XCTAssertEqual(state.recordingDuration, 30.0, accuracy: 0.001)
        XCTAssertEqual(state.recordingStartDate, date)
        XCTAssertEqual(state.averagePower, -15.5, accuracy: 0.001)
    }

    func testRecordingFactory_setsProgressToZero() {
        let state = WritActivityAttributes.ContentState.recording(
            duration: 10.0, startDate: Date(), power: -20.0
        )

        XCTAssertEqual(state.transcriptionProgress, 0, accuracy: 0.001)
    }

    func testRecordingFactory_equivalentToManualInit() {
        let date = Date(timeIntervalSince1970: 5000)
        let factory = WritActivityAttributes.ContentState.recording(
            duration: 30.0, startDate: date, power: -15.5
        )
        let manual = WritActivityAttributes.ContentState(
            phase: .recording,
            recordingDuration: 30.0,
            recordingStartDate: date,
            averagePower: -15.5,
            transcriptionProgress: 0
        )

        XCTAssertEqual(factory, manual)
    }

    func testRecordingFactory_zeroDuration() {
        let state = WritActivityAttributes.ContentState.recording(
            duration: 0, startDate: Date(), power: 0
        )

        XCTAssertEqual(state.recordingDuration, 0, accuracy: 0.001)
        XCTAssertEqual(state.phase, .recording)
    }

    func testRecordingFactory_veryLargeDuration() {
        let state = WritActivityAttributes.ContentState.recording(
            duration: 86400.0, startDate: Date(), power: -5.0
        )

        XCTAssertEqual(state.recordingDuration, 86400.0, accuracy: 0.001)
    }

    func testRecordingFactory_negativePower() {
        // 마이크 파워는 일반적으로 음수 (-160 ~ 0)
        let state = WritActivityAttributes.ContentState.recording(
            duration: 5.0, startDate: Date(), power: -160.0
        )

        XCTAssertEqual(state.averagePower, -160.0, accuracy: 0.001)
    }

    // MARK: - .transcribing(progress:)

    func testTranscribingFactory_defaultProgressIsZero() {
        let state = WritActivityAttributes.ContentState.transcribing()

        XCTAssertEqual(state.phase, .transcribing)
        XCTAssertEqual(state.transcriptionProgress, 0, accuracy: 0.001)
    }

    func testTranscribingFactory_explicitProgress() {
        let state = WritActivityAttributes.ContentState.transcribing(progress: 0.5)

        XCTAssertEqual(state.phase, .transcribing)
        XCTAssertEqual(state.transcriptionProgress, 0.5, accuracy: 0.001)
    }

    func testTranscribingFactory_fullProgress() {
        let state = WritActivityAttributes.ContentState.transcribing(progress: 1.0)

        XCTAssertEqual(state.transcriptionProgress, 1.0, accuracy: 0.001)
    }

    func testTranscribingFactory_setsRecordingFieldsToDefaults() {
        let state = WritActivityAttributes.ContentState.transcribing(progress: 0.3)

        XCTAssertEqual(state.recordingDuration, 0, accuracy: 0.001)
        XCTAssertEqual(state.averagePower, 0, accuracy: 0.001)
    }

    func testTranscribingFactory_startDateIsPopulated() {
        let before = Date()
        let state = WritActivityAttributes.ContentState.transcribing()
        let after = Date()

        // 팩토리가 Date()를 사용하므로 before <= startDate <= after
        XCTAssertTrue(state.recordingStartDate >= before)
        XCTAssertTrue(state.recordingStartDate <= after)
    }

    // MARK: - .completed()

    func testCompletedFactory_setsPhaseToCompleted() {
        let state = WritActivityAttributes.ContentState.completed()

        XCTAssertEqual(state.phase, .completed)
    }

    func testCompletedFactory_setsProgressToOne() {
        let state = WritActivityAttributes.ContentState.completed()

        XCTAssertEqual(state.transcriptionProgress, 1.0, accuracy: 0.001)
    }

    func testCompletedFactory_setsRecordingFieldsToDefaults() {
        let state = WritActivityAttributes.ContentState.completed()

        XCTAssertEqual(state.recordingDuration, 0, accuracy: 0.001)
        XCTAssertEqual(state.averagePower, 0, accuracy: 0.001)
    }

    func testCompletedFactory_startDateIsPopulated() {
        let before = Date()
        let state = WritActivityAttributes.ContentState.completed()
        let after = Date()

        XCTAssertTrue(state.recordingStartDate >= before)
        XCTAssertTrue(state.recordingStartDate <= after)
    }

    // MARK: - Factory Codable Roundtrip

    func testRecordingFactory_codableRoundtrip() throws {
        let date = Date(timeIntervalSince1970: 2000)
        let original = WritActivityAttributes.ContentState.recording(
            duration: 45.0, startDate: date, power: -8.5
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WritActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testTranscribingFactory_codableRoundtrip() throws {
        let original = WritActivityAttributes.ContentState.transcribing(progress: 0.75)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WritActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.phase, .transcribing)
        XCTAssertEqual(decoded.transcriptionProgress, 0.75, accuracy: 0.001)
    }

    func testCompletedFactory_codableRoundtrip() throws {
        let original = WritActivityAttributes.ContentState.completed()

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WritActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.phase, .completed)
        XCTAssertEqual(decoded.transcriptionProgress, 1.0, accuracy: 0.001)
    }

    // MARK: - Factory methods produce distinct phases

    func testFactoryMethods_produceDifferentPhases() {
        let recording = WritActivityAttributes.ContentState.recording(
            duration: 0, startDate: Date(), power: 0
        )
        let transcribing = WritActivityAttributes.ContentState.transcribing()
        let completed = WritActivityAttributes.ContentState.completed()

        XCTAssertEqual(recording.phase, .recording)
        XCTAssertEqual(transcribing.phase, .transcribing)
        XCTAssertEqual(completed.phase, .completed)

        // 각 팩토리의 phase가 서로 달라야 함
        XCTAssertNotEqual(recording.phase, transcribing.phase)
        XCTAssertNotEqual(transcribing.phase, completed.phase)
        XCTAssertNotEqual(recording.phase, completed.phase)
    }
}
