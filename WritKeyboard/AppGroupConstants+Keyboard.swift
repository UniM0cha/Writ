import Foundation

/// 키보드 확장용 App Group 상수 (메인 앱과 동일한 값)
enum AppGroupConstants {
    static let groupIdentifier = "group.com.solstice.writ"

    static var containerURL: URL {
        // App Group 컨테이너 사용 (키보드 확장은 메인 앱과 다른 샌드박스)
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    static var recordingsDirectory: URL {
        containerURL.appendingPathComponent("Recordings", isDirectory: true)
    }

    static let transcriptionRequestNotification = "com.solstice.writ.transcriptionRequest"
    static let transcriptionCompleteNotification = "com.solstice.writ.transcriptionComplete"

    static var keyboardRequestFile: URL {
        containerURL.appendingPathComponent("keyboard_request.json")
    }

    static var keyboardResultFile: URL {
        containerURL.appendingPathComponent("keyboard_result.json")
    }
}
