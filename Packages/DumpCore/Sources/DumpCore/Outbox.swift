import Foundation

/// What the composer's status hint shows.
public struct OutboxStatus: Equatable, Sendable {
    /// Entries waiting to be sent (refused ones aren't counted).
    public var pendingCount: Int
    /// The server refused the token, or the app was built without one.
    public var isTokenInvalid: Bool

    public init(pendingCount: Int = 0, isTokenInvalid: Bool = false) {
        self.pendingCount = pendingCount
        self.isTokenInvalid = isTokenInvalid
    }
}

/// Entries written down on the phone, and the loop that sends them.
///
/// Capturing only saves a file, so it works offline and never waits on the
/// network. `flush()` sends what is pending in batches of up to
/// `batchLimit`, oldest first:
///
/// - accepted: the entries' files are deleted, and the next batch goes;
/// - refused (400): the batch moves to `rejected/` and the next batch goes;
/// - token refused (401): it stops, shows the token as invalid, and waits for
///   the next trigger (a capture, the app coming to the foreground);
/// - anything else: it stops and tries again after `retryPolicy`'s delay.
///
/// An actor, so only one flush runs at a time; a flush asked for while one
/// runs returns at once, since the running one will reach every pending
/// entry.
public actor Outbox {
    /// The server's limit per request (`DUMP_BATCH_LIMIT` in mars-workbench).
    public static let batchLimit = 50

    private let store: OutboxStore
    private let sender: (any DumpSending)?
    private let retryPolicy: RetryPolicy
    private let sleep: @Sendable (Duration) async throws -> Void
    private let onStatusChange: @Sendable (OutboxStatus) async -> Void

    private var isFlushing = false
    private var failuresInARow = 0
    private var retryTask: Task<Void, Never>?
    private var isTokenInvalid = false

    /// - Parameters:
    ///   - sender: nil when the app was built without a token; nothing is
    ///     sent and the status shows the token as invalid.
    ///   - sleep: how a retry waits; tests pass one that returns at once.
    public init(
        store: OutboxStore,
        sender: (any DumpSending)?,
        retryPolicy: RetryPolicy = RetryPolicy(),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        onStatusChange: @escaping @Sendable (OutboxStatus) async -> Void = { _ in }
    ) {
        self.store = store
        self.sender = sender
        self.retryPolicy = retryPolicy
        self.sleep = sleep
        self.onStatusChange = onStatusChange
        isTokenInvalid = sender == nil
    }

    /// Saves what was typed as a pending entry, or returns false when it
    /// breaks `EntryRules` (empty or too long). Throws when the file can't be
    /// written, so the composer keeps the text.
    @discardableResult
    public func capture(_ text: String, at capturedAt: Date = Date()) async throws -> Bool {
        guard let content = EntryRules.content(from: text) else { return false }
        try store.save(PendingEntry(content: content, capturedAt: capturedAt))
        await publishStatus()
        return true
    }

    public func status() -> OutboxStatus {
        OutboxStatus(pendingCount: store.pendingCount(), isTokenInvalid: isTokenInvalid)
    }

    /// Sends every pending entry it can now. Returns once the outbox is empty
    /// or a batch failed; a retry, if one is due, runs later on its own.
    public func flush() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }
        retryTask?.cancel()
        retryTask = nil

        guard let sender else {
            await publishStatus()
            return
        }

        while true {
            let batch = Array(store.pendingEntries().prefix(Self.batchLimit))
            guard !batch.isEmpty else {
                failuresInARow = 0
                await publishStatus()
                return
            }

            switch await sender.send(batch) {
            case .accepted(let acceptedIds):
                let batchIds = Set(batch.map(\.id))
                let sentAndAccepted = acceptedIds.filter(batchIds.contains)
                store.remove(ids: sentAndAccepted)
                isTokenInvalid = false
                failuresInARow = 0
                await publishStatus()
                // An answer that accepts none of the batch would loop forever.
                guard !sentAndAccepted.isEmpty else { return scheduleRetry() }
            case .rejected:
                try? store.reject(ids: batch.map(\.id))
                await publishStatus()
            case .unauthorized:
                isTokenInvalid = true
                await publishStatus()
                return
            case .retryLater:
                await publishStatus()
                return scheduleRetry()
            }
        }
    }

    private func scheduleRetry() {
        failuresInARow += 1
        let delay = retryPolicy.delay(afterFailures: failuresInARow)
        let sleep = self.sleep
        retryTask = Task { [weak self] in
            do {
                try await sleep(delay)
            } catch {
                return  // cancelled: a newer flush took over
            }
            await self?.runScheduledRetry()
        }
    }

    /// Forgets the retry before flushing, so the flush doesn't cancel the
    /// task it runs in (which would cancel its own request).
    private func runScheduledRetry() async {
        retryTask = nil
        await flush()
    }

    /// Sends the current status to `onStatusChange`, e.g. when the app comes
    /// back to the screen and its hint may be stale.
    public func publishStatus() async {
        await onStatusChange(status())
    }
}
