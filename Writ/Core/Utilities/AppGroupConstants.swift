import Foundation

nonisolated enum AppGroupConstants {
    static let groupIdentifier = "group.com.solstice.writ"

    /// os.Logger 공통 subsystem
    static let logSubsystem = "com.solstice.writ"

    /// 앱 컨테이너 URL (App Group 공유 컨테이너)
    static var containerURL: URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// 기존 Documents/Recordings 파일을 App Group 컨테이너로 마이그레이션
    static func migrateFromDocumentsIfNeeded() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let oldRecordingsDir = documentsURL.appendingPathComponent("Recordings", isDirectory: true)

        guard FileManager.default.fileExists(atPath: oldRecordingsDir.path) else { return }

        let newRecordingsDir = recordingsDirectory
        try? FileManager.default.createDirectory(at: newRecordingsDir, withIntermediateDirectories: true)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: oldRecordingsDir,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files {
            let dest = newRecordingsDir.appendingPathComponent(file.lastPathComponent)
            if !FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.moveItem(at: file, to: dest)
            }
        }

        // 이동 완료 후 빈 디렉토리 삭제
        if (try? FileManager.default.contentsOfDirectory(at: oldRecordingsDir, includingPropertiesForKeys: nil))?.isEmpty == true {
            try? FileManager.default.removeItem(at: oldRecordingsDir)
        }
    }

    /// 녹음 파일 저장 디렉토리
    static var recordingsDirectory: URL {
        containerURL.appendingPathComponent("Recordings", isDirectory: true)
    }

    /// App Group 공유 UserDefaults
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: groupIdentifier) ?? .standard
    }

    /// "auto" 또는 nil → nil, 그 외 → 그대로 반환
    static func resolvedLanguage(from raw: String?) -> String? {
        (raw == nil || raw == "auto") ? nil : raw
    }

    /// 지원 언어 목록 (code, displayName)
    static let supportedLanguages: [(code: String, name: String)] = [
        ("auto", "자동 감지"),
        ("ko", "한국어"),
        ("en", "English"),
        ("ja", "日本語"),
        ("zh", "中文"),
        ("es", "Español"),
        ("fr", "Français"),
        ("de", "Deutsch")
    ]
}
