import DumpCore
import SwiftUI

@main
struct DumpApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let networkMonitor = NetworkMonitor()

    init() {
        // Sends whatever is waiting once there is a connection: at launch if
        // there is one, and whenever it comes back.
        networkMonitor.start {
            Task { await Dependencies.outbox.flush() }
        }
    }

    var body: some Scene {
        WindowGroup {
            ComposerView()
                .environment(SyncStatus.shared)
        }
        .onChange(of: scenePhase) { _, phase in
            handle(phase)
        }
        .backgroundTask(.appRefresh(AppConstants.refreshTaskIdentifier)) {
            await Dependencies.outbox.flush()
            if await Dependencies.outbox.status().pendingCount > 0 {
                await BackgroundSync.scheduleRefresh()
            }
        }
    }

    private func handle(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Task {
                await Dependencies.outbox.publishStatus()
                await Dependencies.outbox.flush()
            }
        case .background:
            BackgroundSync.flushBeforeSuspension()
            if SyncStatus.shared.current.pendingCount > 0 {
                BackgroundSync.scheduleRefresh()
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
