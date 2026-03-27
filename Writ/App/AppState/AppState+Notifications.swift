import Foundation
import SwiftData
import UserNotifications

// MARK: - 알림

extension AppState {
    func sendCompletionNotification(text: String, recordingID: UUID) async {
        let content = UNMutableNotificationContent()
        content.title = "전사 완료"
        content.body = String(text.prefix(100))
        content.sound = .default
        content.userInfo = ["recordingID": recordingID.uuidString]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - 오래된 녹음 자동 삭제

    func cleanupOldRecordings() {
        let autoDeleteDays = UserDefaults.standard.integer(forKey: "autoDeleteDays")
        guard autoDeleteDays > 0 else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -autoDeleteDays, to: Date()) ?? Date()
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<Recording> { recording in
            recording.createdAt < cutoffDate
        }
        let descriptor = FetchDescriptor<Recording>(predicate: predicate)

        guard let oldRecordings = try? context.fetch(descriptor) else { return }

        for recording in oldRecordings {
            try? FileManager.default.removeItem(at: recording.audioURL)
            context.delete(recording)
        }
        try? context.save()
    }
}
