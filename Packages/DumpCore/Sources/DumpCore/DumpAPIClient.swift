import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// What the server did with a batch of entries.
public enum SendResult: Equatable, Sendable {
    /// Stored, or stored before: these entries can leave the phone.
    case accepted([UUID])
    /// The batch broke the server's rules (400). Sending it again won't help.
    case rejected
    /// The token is missing or wrong (401). Sending again won't help until
    /// the app is built with the right one.
    case unauthorized
    /// No network, a timeout, or a server error: try again later.
    case retryLater
}

/// Sends entries to the server. A protocol so tests can stand in for it.
public protocol DumpSending: Sendable {
    func send(_ entries: [PendingEntry]) async -> SendResult
}

/// Whatever answers an HTTP request: `URLSession` in the app, a fake in tests.
public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

#if canImport(FoundationNetworking)
    // Linux's URLSession has no `data(for:)` of this shape; this one lets
    // the end-to-end check run the real client from a Linux machine.
    extension URLSession: HTTPTransport {
        public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            try await withCheckedThrowingContinuation { continuation in
                dataTask(with: request) { data, response, error in
                    if let data, let response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: error ?? URLError(.badServerResponse))
                    }
                }
                .resume()
            }
        }
    }
#else
    extension URLSession: HTTPTransport {}
#endif

/// The client for mars-workbench's `POST /api/v1/dump-entries`
/// (`design/reference.md` › Native API in mars-workbench).
public struct DumpAPIClient: DumpSending {
    static let path = "api/v1/dump-entries"

    private let baseURL: URL
    private let token: String
    private let transport: any HTTPTransport

    public init(baseURL: URL, token: String, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    public func send(_ entries: [PendingEntry]) async -> SendResult {
        do {
            let (data, response) = try await transport.data(for: try request(for: entries))
            guard let status = (response as? HTTPURLResponse)?.statusCode else { return .retryLater }
            return result(status: status, body: data)
        } catch {
            return .retryLater
        }
    }

    private func request(for entries: [PendingEntry]) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: Self.path))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CaptureRequest(entries: entries))
        return request
    }

    private func result(status: Int, body: Data) -> SendResult {
        switch status {
        case 200..<300:
            guard let answer = try? JSONDecoder().decode(CaptureResponse.self, from: body) else {
                return .retryLater
            }
            // The server lowercases ids; UUID(uuidString:) reads either case.
            return .accepted(answer.acceptedIds.compactMap(UUID.init(uuidString:)))
        case 400:
            return .rejected
        case 401:
            return .unauthorized
        default:
            return .retryLater
        }
    }
}

private struct CaptureRequest: Encodable {
    let entries: [PendingEntry]
}

private struct CaptureResponse: Decodable {
    let acceptedIds: [String]
}
