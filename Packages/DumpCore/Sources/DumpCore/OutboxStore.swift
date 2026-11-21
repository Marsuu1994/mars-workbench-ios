import Foundation

/// The entries not yet accepted by the server, one JSON file each:
///
/// - `pending/`: waiting to be sent; a file is deleted once the server
///   accepts its entry.
/// - `rejected/`: entries the server refused (it answered 400). They are kept,
///   never sent again and not counted as pending, so a rule change on the
///   server can't lose anything written down.
///
/// The directory must survive the system clearing space: Application
/// Support, never Caches.
public struct OutboxStore: Sendable {
    private let pendingDirectory: URL
    private let rejectedDirectory: URL

    public init(directory: URL) {
        pendingDirectory = directory.appending(path: "pending", directoryHint: .isDirectory)
        rejectedDirectory = directory.appending(path: "rejected", directoryHint: .isDirectory)
    }

    /// Saves an entry. The write is atomic: an app killed mid-write leaves
    /// either the whole file or none.
    public func save(_ entry: PendingEntry) throws {
        try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(entry)
        try data.write(to: fileURL(for: entry.id, in: pendingDirectory), options: .atomic)
    }

    /// The pending entries, oldest first (entries from the same millisecond
    /// in id order). A file that doesn't decode is left
    /// where it is and skipped.
    public func pendingEntries() -> [PendingEntry] {
        let decoder = JSONDecoder()
        return entryFiles(in: pendingDirectory)
            .compactMap { file in
                guard let data = try? Data(contentsOf: file) else { return nil }
                return try? decoder.decode(PendingEntry.self, from: data)
            }
            .sorted {
                ($0.capturedAtMilliseconds, $0.id.uuidString) < ($1.capturedAtMilliseconds, $1.id.uuidString)
            }
    }

    public func pendingCount() -> Int {
        entryFiles(in: pendingDirectory).count
    }

    /// Deletes the files of entries the server accepted.
    public func remove(ids: [UUID]) {
        for id in ids {
            try? FileManager.default.removeItem(at: fileURL(for: id, in: pendingDirectory))
        }
    }

    /// Moves the files of entries the server refused into `rejected/`.
    public func reject(ids: [UUID]) throws {
        try FileManager.default.createDirectory(at: rejectedDirectory, withIntermediateDirectories: true)
        for id in ids {
            let destination = fileURL(for: id, in: rejectedDirectory)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: fileURL(for: id, in: pendingDirectory), to: destination)
        }
    }

    public func rejectedCount() -> Int {
        entryFiles(in: rejectedDirectory).count
    }

    private func fileURL(for id: UUID, in directory: URL) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }

    private func entryFiles(in directory: URL) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
    }
}
