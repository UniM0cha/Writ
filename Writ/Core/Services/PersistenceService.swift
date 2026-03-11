import Foundation
import SwiftData

/// SwiftData 기반 영속성 서비스
final class PersistenceService: Sendable {
    let modelContainer: ModelContainer

    init() throws {
        let schema = Schema([
            Recording.self,
            Transcription.self,
            WritSegment.self
        ])
        // TODO: 유료 계정 전환 후 App Group 컨테이너 사용
        // groupContainer: .identifier(AppGroupConstants.groupIdentifier)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        self.modelContainer = try ModelContainer(for: schema, configurations: [config])
    }
}
