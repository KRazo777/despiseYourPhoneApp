import Foundation

/// Text on the block screen. Shared so the real shield and the app's demo preview match.
enum ShieldCopy {
    static let closeButton = "Close"

    // Close is the brightest thing on a near-black screen; Unlock sits just above the background.
    static let backgroundWhite = 0.04
    static let unlockWhite = 0.38

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

    /// Tapping Unlock opens this menu first (iOS 26.4 and later), in this order.
    static let confirmUnlock = "Yes, unlock"
    static let cancelUnlock = "Never mind"
    static let unlockMenu = [confirmUnlock, cancelUnlock]

    /// The Unlock button's text, or nil to hide the button.
    static func unlockButton(for group: BlockGroup?, opensLeft: Int?) -> String? {
        guard let group, opensLeft != 0 else { return nil }
        // Strict mode removes Unlock, but a daily opens limit still applies.
        if group.isStrict(at: .now) && group.opensPerDay == nil { return nil }
        return group.openDelay > 0 ? "Unlock (\(group.openDelay)s)" : "Unlock"
    }
}
