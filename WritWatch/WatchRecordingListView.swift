import SwiftUI

struct WatchRecordingListView: View {
    // TODO: WatchConnectivity로 iPhone에서 전사 상태 수신

    var body: some View {
        List {
            // 플레이스홀더
            Text("녹음 기록이 없습니다")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("기록")
    }
}
