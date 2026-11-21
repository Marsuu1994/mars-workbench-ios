import SwiftUI

/// The small text left of the Dump button: how many entries are waiting to be
/// sent, or that the token is invalid. Nothing while all is sent.
struct StatusHint: View {
    @Environment(SyncStatus.self) private var status

    var body: some View {
        let current = status.current
        if current.isTokenInvalid {
            Label("Token invalid", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.red)
        } else if current.pendingCount > 0 {
            Text("\(current.pendingCount) pending")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
