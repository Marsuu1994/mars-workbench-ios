import BackgroundTasks
import UIKit

/// The outbox's chances to send while the app isn't on screen
/// (`docs/specs/capture.md` › Send).
@MainActor
enum BackgroundSync {
    /// Asks iOS for about 30 more seconds, so a flush started as the app
    /// leaves the screen can finish before the app is suspended.
    static func flushBeforeSuspension() {
        let backgroundTask = BackgroundTaskHandle()
        backgroundTask.id = UIApplication.shared.beginBackgroundTask(withName: AppConstants.refreshTaskIdentifier) {
            backgroundTask.end()
        }
        Task {
            await Dependencies.outbox.flush()
            backgroundTask.end()
        }
    }

    /// Asks iOS to wake the app later to send what is still waiting. iOS
    /// picks the moment, and skips it for an app the user swiped away.
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: AppConstants.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: AppConstants.refreshDelay)
        try? BGTaskScheduler.shared.submit(request)
    }
}

/// The extra time `beginBackgroundTask` granted, ended exactly once: when the
/// flush finishes, or when iOS says the time is up.
@MainActor
private final class BackgroundTaskHandle {
    var id: UIBackgroundTaskIdentifier = .invalid

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
