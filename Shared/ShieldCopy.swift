import Foundation

/// Text on the block screen. Shared so the real shield and the app's demo preview match.
enum ShieldCopy {
    static let closeButton = "Close"

    static func title(for name: String?) -> String {
        "\(name ?? "This app") is blocked"
    }

    static func subtitle(for group: BlockGroup?) -> String {
        let breath = "Take a breath. Is this what you meant to do?"
        guard let group else { return breath }
        return "Blocked by \(group.name). \(breath)"
    }

    /// The second button's text, or nil to hide the button.
    static func secondaryButton(for group: BlockGroup?, stage: TempUnlock.Stage) -> String? {
        guard let group else { return nil }
        return stage.buttonTitle(unlockMinutes: group.unlockMinutes)
    }
}
