import DumpCore
import Foundation

/// The one outbox the app captures into and sends from, built on first use.
enum Dependencies {
    static let outbox: Outbox = {
        let sender: (any DumpSending)? =
            if let baseURL = AppConfig.apiBaseURL, let token = AppConfig.apiToken {
                DumpAPIClient(baseURL: baseURL, token: token, transport: URLSession.shared)
            } else {
                nil
            }
        return Outbox(
            store: OutboxStore(directory: outboxDirectory),
            sender: sender,
            onStatusChange: { status in
                await MainActor.run { SyncStatus.shared.apply(status) }
            }
        )
    }()

    /// Application Support, which iOS never clears to free space (unlike
    /// Caches).
    private static var outboxDirectory: URL {
        URL.applicationSupportDirectory.appending(path: AppConstants.outboxFolderName, directoryHint: .isDirectory)
    }
}
