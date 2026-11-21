import Foundation

/// The rules an entry meets before it is saved on the phone. They are the
/// server's (`createDumpEntrySchema` in mars-workbench), so the server never
/// refuses an entry the app accepted.
public enum EntryRules {
    /// The most characters an entry may have, counted in UTF-16 code units as
    /// the server counts them.
    public static let maxLength = 10_000

    /// The content to save for what was typed: trimmed of surrounding spaces
    /// and newlines, or nil when nothing is left or it is too long.
    public static func content(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf16.count <= maxLength else { return nil }
        return trimmed
    }
}
