import Network

/// Calls back whenever the phone has a network connection: once when it
/// starts, if there is one, and each time the connection comes back.
final class NetworkMonitor {
    private let monitor = NWPathMonitor()

    func start(onConnected: @escaping @Sendable () -> Void) {
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied { onConnected() }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
}
