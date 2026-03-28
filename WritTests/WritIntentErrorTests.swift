import XCTest
@testable import Writ

/// WritIntentError 에러 타입 및 TranscribeFileIntent 모델 미선택 가드 로직 검증
final class WritIntentErrorTests: XCTestCase {

    // MARK: - WritIntentError.noModelSelected

    func test_noModelSelected_isLocalizedError() {
        // WritIntentError가 LocalizedError를 준수하는지 확인
        let error: any LocalizedError = WritIntentError.noModelSelected
        XCTAssertNotNil(error.errorDescription,
                        "WritIntentError.noModelSelected는 errorDescription을 제공해야 함")
    }

    func test_noModelSelected_errorDescriptionIsNotEmpty() {
        let error = WritIntentError.noModelSelected
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true,
                       "errorDescription이 비어있으면 안 됨")
    }

    func test_noModelSelected_errorDescriptionContainsModelKeyword() {
        // 에러 메시지에 "모델"이 포함되어야 사용자가 원인을 이해할 수 있음
        let error = WritIntentError.noModelSelected
        let description = error.errorDescription ?? ""
        XCTAssertTrue(description.contains("모델"),
                      "에러 메시지에 '모델' 키워드가 포함되어야 함. 실제: \(description)")
    }

    func test_noModelSelected_errorDescriptionContainsActionGuidance() {
        // 에러 메시지에 사용자에게 행동 지침이 있어야 함
        let error = WritIntentError.noModelSelected
        let description = error.errorDescription ?? ""
        // "다운로드"라는 단어로 사용자에게 해결 방법을 안내
        XCTAssertTrue(description.contains("다운로드"),
                      "에러 메시지에 해결 방법 안내('다운로드')가 포함되어야 함. 실제: \(description)")
    }

    func test_noModelSelected_matchesExpectedMessage() {
        let error = WritIntentError.noModelSelected
        XCTAssertEqual(
            error.errorDescription,
            "음성 인식 모델이 선택되지 않았습니다. Writ 앱에서 모델을 먼저 다운로드해주세요.",
            "에러 메시지가 기대값과 일치해야 함"
        )
    }

    // MARK: - Error 프로토콜 준수

    func test_noModelSelected_conformsToError() {
        let error: any Error = WritIntentError.noModelSelected
        XCTAssertNotNil(error, "WritIntentError는 Error 프로토콜을 준수해야 함")
    }

    func test_noModelSelected_localizedDescription_isNotEmpty() {
        // Error 프로토콜의 localizedDescription을 통해서도 메시지 접근 가능
        let error: any Error = WritIntentError.noModelSelected
        XCTAssertFalse(error.localizedDescription.isEmpty,
                       "localizedDescription이 비어있으면 안 됨")
    }

    func test_noModelSelected_canBeThrown() {
        // throw/catch 흐름이 올바르게 동작하는지 확인
        do {
            throw WritIntentError.noModelSelected
        } catch let error as WritIntentError {
            switch error {
            case .noModelSelected:
                break // 올바르게 catch됨
            }
        } catch {
            XCTFail("WritIntentError.noModelSelected가 WritIntentError로 catch되지 않음")
        }
    }

    func test_noModelSelected_patternMatchingWorks() {
        let error = WritIntentError.noModelSelected
        if case .noModelSelected = error {
            // OK
        } else {
            XCTFail("패턴 매칭이 실패함")
        }
    }

    // MARK: - 엣지 케이스: 여러 번 생성해도 동일한 메시지

    func test_noModelSelected_consistentAcrossInstances() {
        let error1 = WritIntentError.noModelSelected
        let error2 = WritIntentError.noModelSelected
        XCTAssertEqual(error1.errorDescription, error2.errorDescription,
                       "동일한 에러 케이스는 항상 같은 메시지를 반환해야 함")
    }
}
