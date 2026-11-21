import Foundation
import Testing

@testable import DumpCore

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Answers every request with one status and body, and keeps the request.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    private let status: Int?
    private let body: String
    private(set) var lastRequest: URLRequest?

    /// - Parameter status: nil throws, as a request with no network does.
    init(status: Int?, body: String = "") {
        self.status = status
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        guard let status else { throw URLError(.notConnectedToInternet) }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

@Suite("API client")
struct DumpAPIClientTests {
    let entry = PendingEntry(
        id: UUID(uuidString: "6F0C7F8E-1D2B-4C3A-9E8F-0A1B2C3D4E5F")!,
        content: "thought",
        capturedAt: Date(timeIntervalSince1970: 1_700_000_000.25)
    )

    func send(status: Int?, body: String = "") async -> (SendResult, URLRequest?) {
        let transport = FakeTransport(status: status, body: body)
        let client = DumpAPIClient(baseURL: URL(string: "https://example.com")!, token: "secret", transport: transport)
        let result = await client.send([entry])
        return (result, transport.lastRequest)
    }

    @Test("posts the entries with the bearer token")
    func buildsRequest() async throws {
        let (_, request) = await send(status: 200, body: #"{"acceptedIds":[]}"#)
        let sent = try #require(request)

        #expect(sent.url?.absoluteString == "https://example.com/api/v1/dump-entries")
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        let body = String(decoding: try #require(sent.httpBody), as: UTF8.self)
        #expect(body.contains("2023-11-14T22:13:20.250Z"))
        #expect(body.contains("6F0C7F8E-1D2B-4C3A-9E8F-0A1B2C3D4E5F"))
    }

    @Test("reads the lowercase ids the server accepted")
    func accepted() async {
        let (result, _) = await send(status: 200, body: #"{"acceptedIds":["6f0c7f8e-1d2b-4c3a-9e8f-0a1b2c3d4e5f"]}"#)
        #expect(result == .accepted([entry.id]))
    }

    @Test("maps each refusal to what the outbox does next")
    func refusals() async {
        #expect(await send(status: 400).0 == .rejected)
        #expect(await send(status: 401).0 == .unauthorized)
        #expect(await send(status: 500).0 == .retryLater)
        #expect(await send(status: 429).0 == .retryLater)
        #expect(await send(status: nil).0 == .retryLater)
        #expect(await send(status: 200, body: "not json").0 == .retryLater)
    }
}
