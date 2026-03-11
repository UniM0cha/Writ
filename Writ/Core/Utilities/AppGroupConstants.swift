import Foundation

enum AppGroupConstants {
    static let groupIdentifier = "group.com.solstice.writ"

    /// 앱 컨테이너 URL (유료 계정 전환 시 App Group 컨테이너로 변경)
    // static var containerURL: URL {
    //     FileManager.default.containerURL(
    //         forSecurityApplicationGroupIdentifier: groupIdentifier
    //     ) ?? FileManager.default.temporaryDirectory
    // }
    static var containerURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// 녹음 파일 저장 디렉토리
    static var recordingsDirectory: URL {
        containerURL.appendingPathComponent("Recordings", isDirectory: true)
    }

    /// 키보드 확장 → 메인 앱 전사 요청용 Darwin Notification 이름
    static let transcriptionRequestNotification = "com.solstice.writ.transcriptionRequest"

    /// 메인 앱 → 키보드 확장 전사 완료 Darwin Notification 이름
    static let transcriptionCompleteNotification = "com.solstice.writ.transcriptionComplete"

    /// 키보드 확장이 전사 요청 데이터를 저장하는 파일
    static var keyboardRequestFile: URL {
        containerURL.appendingPathComponent("keyboard_request.json")
    }

    /// 메인 앱이 전사 결과를 저장하는 파일
    static var keyboardResultFile: URL {
        containerURL.appendingPathComponent("keyboard_result.json")
    }
}
