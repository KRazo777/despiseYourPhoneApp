import Foundation

/// Values shared by the app and every extension.
/// The App Group ID must match the one you add under Signing & Capabilities on all four targets.
enum AppGroup {
    static let id = "group.com.kevinrazo.despiseyourphone"
    static let defaults = UserDefaults(suiteName: id)!
}
