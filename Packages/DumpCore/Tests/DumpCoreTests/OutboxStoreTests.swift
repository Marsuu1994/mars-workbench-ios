import Foundation
import Testing

@testable import DumpCore

@Suite("Outbox store")
struct OutboxStoreTests {
    let store = OutboxStore(directory: makeTemporaryDirectory())

    @Test("reads saved entries back, oldest first")
    func savesAndReads() throws {
        let later = PendingEntry(content: "later", capturedAt: Date(timeIntervalSince1970: 2000))
        let earlier = PendingEntry(content: "earlier", capturedAt: Date(timeIntervalSince1970: 1000))
        try store.save(later)
        try store.save(earlier)

        #expect(store.pendingEntries() == [earlier, later])
        #expect(store.pendingCount() == 2)
    }

    @Test("deletes accepted entries and keeps the rest")
    func removes() throws {
        let kept = PendingEntry(content: "kept", capturedAt: Date())
        let accepted = PendingEntry(content: "accepted", capturedAt: Date())
        try store.save(kept)
        try store.save(accepted)

        store.remove(ids: [accepted.id])

        #expect(store.pendingEntries() == [kept])
    }

    @Test("moves refused entries out of pending and keeps them")
    func rejects() throws {
        let refused = PendingEntry(content: "refused", capturedAt: Date())
        try store.save(refused)

        try store.reject(ids: [refused.id])

        #expect(store.pendingCount() == 0)
        #expect(store.rejectedCount() == 1)
    }

    @Test("starts empty when nothing was ever saved")
    func startsEmpty() {
        #expect(store.pendingEntries().isEmpty)
        #expect(store.pendingCount() == 0)
    }
}
