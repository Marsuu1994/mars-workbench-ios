import Foundation
import Testing

@testable import DumpCore

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The real client and outbox against a running mars-workbench, offline first.
/// Runs only when `DUMP_E2E_BASE_URL` (and `DUMP_E2E_TOKEN`) are set, e.g.
/// against `npm run dev` on the local stack:
///
///     DUMP_E2E_BASE_URL=http://localhost:3000 DUMP_E2E_TOKEN=local-dev-token swift test --filter EndToEnd
@Suite("End to end", .enabled(if: ProcessInfo.processInfo.environment["DUMP_E2E_BASE_URL"] != nil))
struct EndToEndTests {
    let environment = ProcessInfo.processInfo.environment

    @Test("an entry written offline is sent once the server is reachable")
    func offlineThenOnline() async throws {
        let baseURL = try #require(URL(string: environment["DUMP_E2E_BASE_URL"] ?? ""))
        let token = environment["DUMP_E2E_TOKEN"] ?? ""
        let store = OutboxStore(directory: makeTemporaryDirectory())

        // Offline: nothing listens on this port.
        let offline = Outbox(
            store: store,
            sender: DumpAPIClient(
                baseURL: URL(string: "http://127.0.0.1:9")!, token: token, transport: URLSession.shared),
            sleep: { _ in throw CancellationError() }
        )
        try await offline.capture("written offline \(UUID().uuidString)")
        await offline.flush()
        #expect(store.pendingCount() == 1)

        // Online: the same outbox directory, the real server.
        let online = Outbox(
            store: store,
            sender: DumpAPIClient(baseURL: baseURL, token: token, transport: URLSession.shared)
        )
        await online.flush()
        #expect(store.pendingCount() == 0)
        #expect(await online.status() == OutboxStatus(pendingCount: 0))
    }

    @Test("a wrong token keeps the entry and shows the token as invalid")
    func wrongToken() async throws {
        let baseURL = try #require(URL(string: environment["DUMP_E2E_BASE_URL"] ?? ""))
        let store = OutboxStore(directory: makeTemporaryDirectory())
        let outbox = Outbox(
            store: store,
            sender: DumpAPIClient(baseURL: baseURL, token: "wrong", transport: URLSession.shared)
        )
        try await outbox.capture("never sent")

        await outbox.flush()

        #expect(await outbox.status() == OutboxStatus(pendingCount: 1, isTokenInvalid: true))
    }
}
