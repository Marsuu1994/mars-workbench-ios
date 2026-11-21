import Foundation

/// One entry written down on the phone and not yet accepted by the server.
/// Its id is made here and kept by the server, so sending it again after a
/// lost answer stores nothing twice.
public struct PendingEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let content: String
    /// When it was written down, in whole milliseconds since 1970: the
    /// precision the server stores. Kept as an integer, since a `Date` cut to
    /// milliseconds in floating point doesn't compare equal to the same
    /// moment read back from JSON.
    public let capturedAtMilliseconds: Int64

    public var capturedAt: Date {
        Date(timeIntervalSince1970: Double(capturedAtMilliseconds) / 1000)
    }

    public init(id: UUID = UUID(), content: String, capturedAt: Date) {
        self.id = id
        self.content = content
        capturedAtMilliseconds = Int64((capturedAt.timeIntervalSince1970 * 1000).rounded(.down))
    }

    private enum CodingKeys: String, CodingKey {
        case id, content, capturedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        capturedAtMilliseconds = try EntryTime.milliseconds(
            from: try container.decode(String.self, forKey: .capturedAt)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(EntryTime.string(fromMilliseconds: capturedAtMilliseconds), forKey: .capturedAt)
    }
}

/// `capturedAt` on the wire and on disk: ISO 8601 in UTC with milliseconds,
/// `2026-11-21T08:15:02.123Z`, which the server's schema reads.
enum EntryTime {
    private static let wholeSeconds = Date.ISO8601FormatStyle()
    private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// Formats the whole seconds and writes the milliseconds itself, so no
    /// floating-point rounding can change them.
    static func string(fromMilliseconds milliseconds: Int64) -> String {
        let (seconds, remainder) = milliseconds.quotientAndRemainder(dividingBy: 1000)
        let base = wholeSeconds.format(Date(timeIntervalSince1970: Double(seconds)))
        let fraction = String(remainder)
        let padded = String(repeating: "0", count: 3 - fraction.count) + fraction
        return "\(base.dropLast()).\(padded)Z"
    }

    static func milliseconds(from string: String) throws -> Int64 {
        let date = try withFraction.parse(string)
        return Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}
