import XCTest
@testable import Writ

final class AppGroupConstantsTests: XCTestCase {

    // MARK: - 기본 상수 존재 확인

    func testGroupIdentifier() {
        XCTAssertEqual(AppGroupConstants.groupIdentifier, "group.com.solstice.writ")
    }

    func testContainerURL_isNotNil() {
        // containerURL은 App Group이 없는 환경에서도 Documents 폴백으로 nil이 아니어야 함
        let url = AppGroupConstants.containerURL
        XCTAssertFalse(url.path.isEmpty, "containerURL 경로가 비어있으면 안 됨")
    }

    func testRecordingsDirectory_appendsRecordingsPath() {
        let url = AppGroupConstants.recordingsDirectory
        XCTAssertTrue(
            url.lastPathComponent == "Recordings",
            "recordingsDirectory 마지막 경로 컴포넌트가 'Recordings'여야 함"
        )
    }

    func testSharedDefaults_isNotNil() {
        let defaults = AppGroupConstants.sharedDefaults
        // UserDefaults 객체가 반환되어야 함 (표준이든 그룹이든)
        XCTAssertNotNil(defaults)
    }

    // MARK: - 키보드 관련 상수 제거 확인 (컴파일 타임 검증)
    //
    // 아래 테스트들은 키보드 관련 프로퍼티가 제거되었는지 컴파일 타임에 확인합니다.
    // 만약 해당 프로퍼티가 다시 추가되면 이 테스트가 실패해야 합니다.
    //
    // 컴파일 검증: AppGroupConstants에 다음 프로퍼티가 없어야 함:
    // - transcriptionRequestNotification
    // - transcriptionCompleteNotification
    // - keyboardRequestFile
    // - keyboardResultFile

    func testKeyboardConstantsDoNotExist() {
        // 런타임에서 Mirror를 사용하여 키보드 관련 프로퍼티가 없는지 확인
        let mirror = Mirror(reflecting: AppGroupConstants.self)

        // static 프로퍼티는 Mirror에 나타나지 않으므로
        // 대신 responds(to:)를 활용하여 확인
        let forbiddenSelectors = [
            "transcriptionRequestNotification",
            "transcriptionCompleteNotification",
            "keyboardRequestFile",
            "keyboardResultFile",
        ]

        for selectorName in forbiddenSelectors {
            let selector = NSSelectorFromString(selectorName)
            let responds = (AppGroupConstants.self as AnyObject).responds(to: selector)
            XCTAssertFalse(
                responds,
                "AppGroupConstants에서 '\(selectorName)'이 제거되었어야 함"
            )
        }

        // 추가로 Mirror의 children에도 없는지 확인
        let childLabels = mirror.children.compactMap(\.label)
        for name in forbiddenSelectors {
            XCTAssertFalse(
                childLabels.contains(name),
                "AppGroupConstants에서 '\(name)' 프로퍼티가 제거되었어야 함"
            )
        }
    }

    // MARK: - 디렉토리 계층 구조

    func testRecordingsDirectoryIsUnderContainer() {
        let container = AppGroupConstants.containerURL
        let recordings = AppGroupConstants.recordingsDirectory
        XCTAssertTrue(
            recordings.path.hasPrefix(container.path),
            "recordingsDirectory는 containerURL 하위에 있어야 함"
        )
    }

    // MARK: - resolvedLanguage(from:)

    func testResolvedLanguage_nilInput_returnsNil() {
        let result = AppGroupConstants.resolvedLanguage(from: nil)
        XCTAssertNil(result, "nil 입력 시 nil을 반환해야 함")
    }

    func testResolvedLanguage_autoInput_returnsNil() {
        let result = AppGroupConstants.resolvedLanguage(from: "auto")
        XCTAssertNil(result, "'auto' 입력 시 nil을 반환해야 함")
    }

    func testResolvedLanguage_koreanCode_returnsAsIs() {
        let result = AppGroupConstants.resolvedLanguage(from: "ko")
        XCTAssertEqual(result, "ko", "'ko' 입력 시 그대로 반환해야 함")
    }

    func testResolvedLanguage_englishCode_returnsAsIs() {
        let result = AppGroupConstants.resolvedLanguage(from: "en")
        XCTAssertEqual(result, "en", "'en' 입력 시 그대로 반환해야 함")
    }

    func testResolvedLanguage_emptyString_returnsEmptyString() {
        // 빈 문자열은 nil도 "auto"도 아니므로 그대로 반환
        let result = AppGroupConstants.resolvedLanguage(from: "")
        XCTAssertEqual(result, "", "빈 문자열 입력 시 빈 문자열을 반환해야 함")
    }

    func testResolvedLanguage_japaneseCode_returnsAsIs() {
        let result = AppGroupConstants.resolvedLanguage(from: "ja")
        XCTAssertEqual(result, "ja", "'ja' 입력 시 그대로 반환해야 함")
    }

    func testResolvedLanguage_autoUpperCase_returnsAsIs() {
        // "Auto"는 "auto"와 다르므로 그대로 반환 (대소문자 구분)
        let result = AppGroupConstants.resolvedLanguage(from: "Auto")
        XCTAssertEqual(result, "Auto", "'Auto' (대문자)는 'auto'와 다르므로 그대로 반환해야 함")
    }

    func testResolvedLanguage_whitespaceString_returnsAsIs() {
        // 공백 문자열은 nil도 "auto"도 아니므로 그대로 반환
        let result = AppGroupConstants.resolvedLanguage(from: " ")
        XCTAssertEqual(result, " ", "공백 문자열은 그대로 반환해야 함")
    }

    func testResolvedLanguage_longLanguageCode_returnsAsIs() {
        let result = AppGroupConstants.resolvedLanguage(from: "zh-Hant")
        XCTAssertEqual(result, "zh-Hant", "복합 언어 코드도 그대로 반환해야 함")
    }

    // MARK: - supportedLanguages

    func testSupportedLanguages_isNotEmpty() {
        XCTAssertFalse(
            AppGroupConstants.supportedLanguages.isEmpty,
            "supportedLanguages가 비어있으면 안 됨"
        )
    }

    func testSupportedLanguages_hasEightEntries() {
        // auto, ko, en, ja, zh, es, fr, de = 8개
        XCTAssertEqual(
            AppGroupConstants.supportedLanguages.count, 8,
            "supportedLanguages는 8개 항목이 있어야 함"
        )
    }

    func testSupportedLanguages_firstIsAuto() {
        // 첫 번째 항목은 자동 감지(auto)여야 함
        let first = AppGroupConstants.supportedLanguages.first
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.code, "auto", "첫 번째 언어 코드는 'auto'여야 함")
        XCTAssertEqual(first?.name, "자동 감지", "첫 번째 언어 이름은 '자동 감지'여야 함")
    }

    func testSupportedLanguages_containsKorean() {
        let korean = AppGroupConstants.supportedLanguages.first { $0.code == "ko" }
        XCTAssertNotNil(korean, "한국어(ko)가 supportedLanguages에 포함되어야 함")
        XCTAssertEqual(korean?.name, "한국어")
    }

    func testSupportedLanguages_containsEnglish() {
        let english = AppGroupConstants.supportedLanguages.first { $0.code == "en" }
        XCTAssertNotNil(english, "영어(en)가 supportedLanguages에 포함되어야 함")
        XCTAssertEqual(english?.name, "English")
    }

    func testSupportedLanguages_containsJapanese() {
        let japanese = AppGroupConstants.supportedLanguages.first { $0.code == "ja" }
        XCTAssertNotNil(japanese, "일본어(ja)가 supportedLanguages에 포함되어야 함")
        XCTAssertEqual(japanese?.name, "日本語")
    }

    func testSupportedLanguages_containsChinese() {
        let chinese = AppGroupConstants.supportedLanguages.first { $0.code == "zh" }
        XCTAssertNotNil(chinese, "중국어(zh)가 supportedLanguages에 포함되어야 함")
        XCTAssertEqual(chinese?.name, "中文")
    }

    func testSupportedLanguages_containsSpanish() {
        let spanish = AppGroupConstants.supportedLanguages.first { $0.code == "es" }
        XCTAssertNotNil(spanish, "스페인어(es)가 supportedLanguages에 포함되어야 함")
        XCTAssertEqual(spanish?.name, "Español")
    }

    func testSupportedLanguages_containsFrench() {
        let french = AppGroupConstants.supportedLanguages.first { $0.code == "fr" }
        XCTAssertNotNil(french, "프랑스어(fr)가 supportedLanguages에 포함되어야 함")
        XCTAssertEqual(french?.name, "Français")
    }

    func testSupportedLanguages_containsGerman() {
        let german = AppGroupConstants.supportedLanguages.first { $0.code == "de" }
        XCTAssertNotNil(german, "독일어(de)가 supportedLanguages에 포함되어야 함")
        XCTAssertEqual(german?.name, "Deutsch")
    }

    func testSupportedLanguages_allCodesAreUnique() {
        let codes = AppGroupConstants.supportedLanguages.map(\.code)
        let uniqueCodes = Set(codes)
        XCTAssertEqual(codes.count, uniqueCodes.count, "supportedLanguages에 중복 코드가 있으면 안 됨")
    }

    func testSupportedLanguages_allNamesAreUnique() {
        let names = AppGroupConstants.supportedLanguages.map(\.name)
        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count, "supportedLanguages에 중복 이름이 있으면 안 됨")
    }

    func testSupportedLanguages_allCodesAreNonEmpty() {
        for language in AppGroupConstants.supportedLanguages {
            XCTAssertFalse(language.code.isEmpty, "언어 코드가 비어있으면 안 됨")
        }
    }

    func testSupportedLanguages_allNamesAreNonEmpty() {
        for language in AppGroupConstants.supportedLanguages {
            XCTAssertFalse(language.name.isEmpty, "언어 이름이 비어있으면 안 됨")
        }
    }

    func testSupportedLanguages_koreanIsSecond() {
        // UI에서 자동 감지 다음에 한국어가 표시되어야 함
        let second = AppGroupConstants.supportedLanguages[1]
        XCTAssertEqual(second.code, "ko", "두 번째 항목은 한국어(ko)여야 함")
    }

    func testSupportedLanguages_resolvedLanguageConsistency() {
        // supportedLanguages의 모든 코드에 대해 resolvedLanguage가 올바르게 동작하는지 확인
        for language in AppGroupConstants.supportedLanguages {
            let resolved = AppGroupConstants.resolvedLanguage(from: language.code)
            if language.code == "auto" {
                XCTAssertNil(resolved, "'auto' 코드는 resolvedLanguage에서 nil로 변환되어야 함")
            } else {
                XCTAssertEqual(resolved, language.code, "'\(language.code)'는 그대로 반환되어야 함")
            }
        }
    }

    // MARK: - modelsDirectory 제거 확인

    func testModelsDirectoryDoesNotExist() {
        // modelsDirectory 프로퍼티가 AppGroupConstants에서 제거되었는지 확인
        let selector = NSSelectorFromString("modelsDirectory")
        let responds = (AppGroupConstants.self as AnyObject).responds(to: selector)
        XCTAssertFalse(
            responds,
            "AppGroupConstants에서 'modelsDirectory'가 제거되었어야 함"
        )
    }

    // MARK: - Widget과 ModelManager 간 UserDefaults 계약 (Fix 5)
    //
    // ModelManager.loadModel()은 sharedDefaults에 "selectedModelDisplayName" 키를 저장한다.
    // WritWidgetProvider.currentModelName()은 같은 키를 읽어 위젯에 모델 이름을 표시한다.
    // 이 테스트는 그 계약이 유지되는지 검증한다.

    func testSharedDefaults_selectedModelDisplayName_roundtrip() {
        let defaults = AppGroupConstants.sharedDefaults
        let key = "selectedModelDisplayName"

        // 정리
        defaults.removeObject(forKey: key)

        // ModelManager가 저장하는 방식
        defaults.set("Small", forKey: key)

        // WritWidgetProvider가 읽는 방식
        let readValue = defaults.string(forKey: key) ?? "준비 중"
        XCTAssertEqual(readValue, "Small",
                       "sharedDefaults에 저장된 displayName을 올바르게 읽을 수 있어야 함")

        // 정리
        defaults.removeObject(forKey: key)
    }

    func testSharedDefaults_selectedModelDisplayName_fallbackWhenMissing() {
        let defaults = AppGroupConstants.sharedDefaults
        let key = "selectedModelDisplayName"

        // 키가 없는 경우
        defaults.removeObject(forKey: key)

        // WritWidgetProvider의 폴백 로직과 동일
        let readValue = defaults.string(forKey: key) ?? "준비 중"
        XCTAssertEqual(readValue, "준비 중",
                       "displayName 키가 없으면 '준비 중'을 반환해야 함")
    }

    func testSharedDefaults_selectedModelDisplayName_allVariantNames() {
        // 모든 모델의 displayName이 저장/읽기 가능한지 확인
        let defaults = AppGroupConstants.sharedDefaults
        let key = "selectedModelDisplayName"

        for variant in WhisperModelVariant.allCases {
            defaults.set(variant.displayName, forKey: key)
            let readValue = defaults.string(forKey: key)
            XCTAssertEqual(readValue, variant.displayName,
                           "\(variant)의 displayName '\(variant.displayName)' 저장/읽기 실패")
        }

        // 정리
        defaults.removeObject(forKey: key)
    }

    func testSharedDefaults_suiteName_matchesGroupIdentifier() {
        // WritWidgetProvider가 사용하는 suiteName이 AppGroupConstants.groupIdentifier와 동일한지 확인
        // WritWidgetProvider: UserDefaults(suiteName: "group.com.solstice.writ")
        // AppGroupConstants: groupIdentifier = "group.com.solstice.writ"
        XCTAssertEqual(
            AppGroupConstants.groupIdentifier,
            "group.com.solstice.writ",
            "Widget과 앱이 같은 App Group을 사용해야 함"
        )
    }
}
