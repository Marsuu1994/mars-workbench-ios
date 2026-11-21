import DumpCore
import Observation

/// The outbox's latest status, for the composer's hint. The outbox publishes
/// into it after every capture and every batch it sends.
@MainActor
@Observable
final class SyncStatus {
    static let shared = SyncStatus()

    private(set) var current = OutboxStatus()

    func apply(_ status: OutboxStatus) {
        current = status
    }
}
