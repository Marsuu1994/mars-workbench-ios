import Foundation
import Testing

@testable import DumpCore

@Suite("Entry rules")
struct EntryRulesTests {
    @Test("trims surrounding spaces and newlines and keeps the ones inside")
    func trims() {
        #expect(EntryRules.content(from: "  an idea\nwith two lines \n") == "an idea\nwith two lines")
    }

    @Test("refuses an entry with nothing in it")
    func refusesEmpty() {
        #expect(EntryRules.content(from: "") == nil)
        #expect(EntryRules.content(from: " \n\t ") == nil)
    }

    @Test("counts length in UTF-16 code units, as the server does")
    func countsUTF16() {
        #expect(EntryRules.content(from: String(repeating: "a", count: EntryRules.maxLength)) != nil)
        #expect(EntryRules.content(from: String(repeating: "a", count: EntryRules.maxLength + 1)) == nil)
        // An emoji is one character but two UTF-16 code units.
        #expect(EntryRules.content(from: String(repeating: "😀", count: EntryRules.maxLength / 2 + 1)) == nil)
    }
}

@Suite("Pending entry")
struct PendingEntryTests {
    @Test("keeps the capture time to the millisecond, as the server stores it")
    func truncatesToMilliseconds() {
        let entry = PendingEntry(content: "x", capturedAt: Date(timeIntervalSince1970: 1_700_000_000.123_456))
        #expect(entry.capturedAtMilliseconds == 1_700_000_000_123)
    }

    @Test("writes milliseconds without rounding them")
    func writesMilliseconds() {
        #expect(EntryTime.string(fromMilliseconds: 1_700_000_000_007) == "2023-11-14T22:13:20.007Z")
        #expect(EntryTime.string(fromMilliseconds: 1_700_000_000_999) == "2023-11-14T22:13:20.999Z")
        #expect(EntryTime.string(fromMilliseconds: 1_700_000_000_000) == "2023-11-14T22:13:20.000Z")
    }

    @Test("writes dates as ISO 8601 with milliseconds and reads them back")
    func roundTripsJSON() throws {
        let entry = PendingEntry(content: "x", capturedAt: Date(timeIntervalSince1970: 1_700_000_000.5))
        let json = String(decoding: try JSONEncoder().encode(entry), as: UTF8.self)
        #expect(json.contains("2023-11-14T22:13:20.500Z"))
        #expect(try JSONDecoder().decode(PendingEntry.self, from: Data(json.utf8)) == entry)
    }
}

@Suite("Retry policy")
struct RetryPolicyTests {
    @Test("waits one second, then doubles up to five minutes")
    func doubles() {
        let policy = RetryPolicy()
        #expect(policy.baseDelay(afterFailures: 1) == .seconds(1))
        #expect(policy.baseDelay(afterFailures: 2) == .seconds(2))
        #expect(policy.baseDelay(afterFailures: 4) == .seconds(8))
        #expect(policy.baseDelay(afterFailures: 9) == .seconds(256))
        #expect(policy.baseDelay(afterFailures: 10) == .seconds(300))
        #expect(policy.baseDelay(afterFailures: 1000) == .seconds(300))
    }

    @Test("adds at most half a second of jitter")
    func jitters() {
        let delay = RetryPolicy().delay(afterFailures: 1)
        #expect(delay >= .seconds(1))
        #expect(delay <= .milliseconds(1500))
    }
}
