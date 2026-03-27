import Foundation

/// 다운로드/사용 가능한 모델 정보 (엔진 무관). UI에서 모델 목록 표시에 사용.
struct ModelInfo: Identifiable, Sendable {
    let identifier: ModelIdentifier
    var state: ModelState
    var isSupported: Bool
    var unsupportedReason: String?

    var id: String { identifier.id }

    init(
        identifier: ModelIdentifier,
        state: ModelState = .notDownloaded,
        isSupported: Bool = true,
        unsupportedReason: String? = nil
    ) {
        self.identifier = identifier
        self.state = state
        self.isSupported = isSupported
        self.unsupportedReason = unsupportedReason
    }
}
