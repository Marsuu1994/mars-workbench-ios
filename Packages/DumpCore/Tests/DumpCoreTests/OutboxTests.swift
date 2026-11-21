import Foundation
import Testing

@testable import DumpCore

@Suite("Outbox")
struct OutboxTests {
    let store = OutboxStore(directory: makeTemporaryDirectory())
    let statuses = StatusLog()
    let sleeps = SleepLog()

    func makeOutbox(_ sender: FakeSender?) -> Outbox {
        let sleeps = self.sleeps
        let statuses = self.statuses
        return Outbox(
            store: store,
            sender: sender,
            sleep: { await sleeps.append($0) },
            onStatusChange: { await statuses.append($0) }
        )
    }

    @Test("a capture is saved on the phone before anything is sent")
    func captureSavesOnly() async throws {
        let sender = FakeSender([])
        let outbox = makeOutbox(sender)

        #expect(try await outbox.capture("  call the dentist  "))

        #expect(store.pendingEntries().map(\.content) == ["call the dentist"])
        #expect(await sender.batches.isEmpty)
        #expect(await statuses.last == OutboxStatus(pendingCount: 1))
    }

    @Test("an empty capture saves nothing")
    func emptyCapture() async throws {
        let outbox = makeOutbox(FakeSender([]))

        #expect(try await outbox.capture(" \n ") == false)

        #expect(store.pendingCount() == 0)
    }

    @Test("accepted entries leave the phone")
    func flushAccepted() async throws {
        let sender = FakeSender([.acceptAll])
        let outbox = makeOutbox(sender)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        try await outbox.capture("one", at: start)
        try await outbox.capture("two", at: start.addingTimeInterval(1))

        await outbox.flush()

        #expect(await sender.batches.map { $0.map(\.content) } == [["one", "two"]])
        #expect(store.pendingCount() == 0)
        #expect(await statuses.last == OutboxStatus(pendingCount: 0))
    }

    @Test("sends at most a batch at a time, oldest first")
    func flushInBatches() async throws {
        let sender = FakeSender([])
        let outbox = makeOutbox(sender)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<(Outbox.batchLimit + 3) {
            try await outbox.capture("entry \(index)", at: start.addingTimeInterval(Double(index)))
        }

        await outbox.flush()

        let batches = await sender.batches
        #expect(batches.map(\.count) == [Outbox.batchLimit, 3])
        #expect(batches[0].first?.content == "entry 0")
        #expect(store.pendingCount() == 0)
    }

    @Test("keeps entries and tries again later when sending fails")
    func flushRetries() async throws {
        let sender = FakeSender([.result(.retryLater), .acceptAll])
        let outbox = makeOutbox(sender)
        try await outbox.capture("offline thought")

        await outbox.flush()
        #expect(store.pendingCount() == 1)

        // The retry runs on its own once its wait is over (here, at once).
        try await waitUntil { store.pendingCount() == 0 }
        #expect(await sender.batches.count == 2)
        #expect(await sleeps.delays.count == 1)
    }

    @Test("stops on a refused token, shows it, and keeps the entries")
    func flushUnauthorized() async throws {
        let sender = FakeSender([.result(.unauthorized)])
        let outbox = makeOutbox(sender)
        try await outbox.capture("thought")

        await outbox.flush()

        #expect(store.pendingCount() == 1)
        #expect(await statuses.last == OutboxStatus(pendingCount: 1, isTokenInvalid: true))
        #expect(await sleeps.delays.isEmpty)
    }

    @Test("shows the token as invalid, and sends nothing, when the app has none")
    func noToken() async throws {
        let outbox = makeOutbox(nil)
        try await outbox.capture("thought")

        await outbox.flush()

        #expect(store.pendingCount() == 1)
        #expect(await statuses.last == OutboxStatus(pendingCount: 1, isTokenInvalid: true))
    }

    @Test("moves a refused batch aside, uncounted, and goes on with the rest")
    func flushRejected() async throws {
        let sender = FakeSender([.result(.rejected), .acceptAll])
        let outbox = makeOutbox(sender)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<(Outbox.batchLimit + 1) {
            try await outbox.capture("entry \(index)", at: start.addingTimeInterval(Double(index)))
        }

        await outbox.flush()

        #expect(store.pendingCount() == 0)
        #expect(store.rejectedCount() == Outbox.batchLimit)
        #expect(await statuses.last == OutboxStatus(pendingCount: 0))
    }

    @Test("an answer that accepts none of the batch doesn't loop")
    func flushAcceptsNone() async throws {
        let sender = FakeSender([.result(.accepted([])), .result(.retryLater)])
        let outbox = makeOutbox(sender)
        try await outbox.capture("thought")

        await outbox.flush()

        #expect(store.pendingCount() == 1)
        #expect(await sender.batches.count >= 1)
    }

    /// Polls a condition the outbox reaches on its own, failing after a second.
    private func waitUntil(_ condition: @escaping () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }
}
