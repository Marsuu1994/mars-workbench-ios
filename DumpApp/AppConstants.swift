import Foundation

enum AppConstants {
    /// The background refresh task; listed in Info.plist's
    /// `BGTaskSchedulerPermittedIdentifiers` (project.yml).
    static let refreshTaskIdentifier = "com.marsuu1994.workbench.dump.flush"
    /// The earliest a background refresh may run after the app leaves the
    /// screen. iOS decides when it actually runs, or whether it does.
    static let refreshDelay: TimeInterval = 15 * 60
    /// Where the composer's unsent text is kept between launches.
    static let draftKey = "composerDraft"
    /// The outbox's folder under Application Support.
    static let outboxFolderName = "Outbox"
    static let composerPadding: CGFloat = 12
}
