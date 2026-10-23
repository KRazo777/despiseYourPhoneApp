import Foundation

/// Text on the block screen. Shared so the real shield and the app's demo preview match.
enum ShieldCopy {
    static let subtitle = "Take a breath. Is this what you meant to do?"
    static let closeButton = "Close"

    static func title(for name: String?) -> String {
        "\(name ?? "This app") is blocked"
    }
}
