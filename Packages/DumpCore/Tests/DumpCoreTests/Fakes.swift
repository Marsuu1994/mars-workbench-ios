import Foundation

@testable import DumpCore

/// A server that answers each send with the next scripted result, and records
/// what it was sent. `.accepted` with no ids accepts the whole batch.
actor FakeSender: DumpSending {
    enum Answer {
        case acceptAll
        case result(SendResult)
    }

    private var answers: [Answer]
    private(set) var batches: [[PendingEntry]] = []

    init(_ answers: [Answer]) {
        self.answers = answers
    }

    func send(_ entries: [PendingEntry]) async -> SendResult {
        batches.append(entries)
        let answer = answers.isEmpty ? .acceptAll : answers.removeFirst()
        switch answer {
        case .acceptAll: return .accepted(entries.map(\.id))
        case .result(let result): return result
        }
    }
}

/// Collects every status the outbox publishes.
actor StatusLog {
    private(set) var statuses: [OutboxStatus] = []
    func append(_ status: OutboxStatus) { statuses.append(status) }
    var last: OutboxStatus? { statuses.last }
}

/// Records the waits a retry asks for, and returns at once.
actor SleepLog {
    private(set) var delays: [Duration] = []
    func append(_ delay: Duration) { delays.append(delay) }
}

func makeTemporaryDirectory() -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "DumpCoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
