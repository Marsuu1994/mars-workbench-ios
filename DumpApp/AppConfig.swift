import Foundation

/// What the build wrote into Info.plist from `Config/App.xcconfig` and the
/// developer's own `Config/Secrets.xcconfig` (README › Set up).
enum AppConfig {
    /// The mars-workbench deployment entries are sent to.
    static let apiBaseURL: URL? = infoString(for: "DumpAPIBaseURL").flatMap(URL.init(string:))
    /// mars-workbench's `NATIVE_API_TOKEN`; nil when the build had none.
    static let apiToken: String? = infoString(for: "DumpAPIToken")

    private static func infoString(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            return nil
        }
        return value
    }
}
