import Foundation

/// Text on the block screen. Shared so the real shield and the app's demo preview match.
enum ShieldCopy {
    static let closeButton = "Close"

    // Close is the brightest thing on a near-black screen; Unlock sits just above the background.
    static let backgroundWhite = 0.04
    static let unlockWhite = 0.38
    static let iconName = "hourglass"
    static let iconPointSize: CGFloat = 72

    static func title(for name: String?) -> String {
        "\(name ?? "This app") is blocked"
    }

    /// Only groups with an opens limit get a subtitle: a row of squares, one per open
    /// (filled for opens left, empty for opens used), and the count.
    /// With an open delay, a line under the count says when the app will open.
    static func subtitle(for group: BlockGroup?, opensLeft: Int?) -> String? {
        var lines: [String] = []
        if let limit = group?.opensPerDay, let opensLeft {
            let squares = String(repeating: "■ ", count: opensLeft) + String(repeating: "□ ", count: limit - opensLeft)
            lines += [squares.trimmingCharacters(in: .whitespaces), "\(opensLeft)/\(limit) opens left"]
        }
        // The shield can't change while the delay runs, so say it up front.
        if let group, group.openDelay > 0, unlockButton(for: group, opensLeft: opensLeft) != nil {
            lines.append("Opens \(group.openDelay)s after you confirm")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// Tapping Unlock opens this menu first (iOS 26.4nd later), in this order.
    static func confirmUnlock(for group: BlockGroup) -> String {
        group.openDelay > 0 ? "Unlock in \(group.openDelay)s" : "Unlock"
    }
    static let cancelUnlock = "Nevermind"
    static func unlockMenu(for group: BlockGroup) -> [String] {
        [confirmUnlock(for: group), cancelUnlock]
    }

    /// The Unlock button's text, or nil to hide the button.
    static func unlockButton(for group: BlockGroup?, opensLeft: Int?) -> String? {
        guard let group, opensLeft != 0 else { return nil }
        // Strict mode removes Unlock, but a daily opens limit still applies.
        if group.isStrict(at: .now) && group.opensPerDay == nil { return nil }
        return group.openDelay > 0 ? "Unlock (\(group.openDelay)s)" : "Unlock"
    }
}
