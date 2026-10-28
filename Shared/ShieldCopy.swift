import Foundation

/// Text on the block screen. Shared so the real shield and the app's demo preview match.
enum ShieldCopy {
    static let closeButton = "Close"

    static func title(for name: String?) -> String {
        "\(name ?? "This app") is blocked"
    }

    /// Only groups with an opens limit get a subtitle: a row of squares, one per open
    /// (filled for opens left, empty for opens used), and the count.
    static func subtitle(for group: BlockGroup?, opensLeft: Int?) -> String? {
        guard let limit = group?.opensPerDay, let opensLeft else { return nil }
        let squares = String(repeating: "■ ", count: opensLeft) + String(repeating: "□ ", count: limit - opensLeft)
        return "\(squares.trimmingCharacters(in: .whitespaces))\n\(opensLeft)/\(limit) opens left"
    }

    /// The Unlock button's text, or nil to hide the button.
    static func unlockButton(for group: BlockGroup?) -> String? {
        guard let group, TempUnlock.canUnlock(group) else { return nil }
        return group.openDelay > 0 ? "Unlock (\(group.openDelay)s)" : "Unlock"
    }
}
