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
    /// While a confirmed Unlock waits out the open delay, a line under the count says so.
    static func subtitle(for group: BlockGroup?, opensLeft: Int?, request: TempUnlock.Request = .none, now: Date = .now) -> String? {
        var lines: [String] = []
        if let limit = group?.opensPerDay, let opensLeft {
            let squares = String(repeating: "■ ", count: opensLeft) + String(repeating: "□ ", count: limit - opensLeft)
            lines += [squares.trimmingCharacters(in: .whitespaces), "\(opensLeft)/\(limit) opens left"]
        }
        switch request {
        case .none: break
        case .waiting(let until): lines.append("Opening in \(max(1, Int(until.timeIntervalSince(now).rounded(.up))))s")
        case .ready: lines.append("Your open is ready")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// Tapping Unlock opens this menu first (iOS 26.4nd later), in this order.
    static let confirmUnlock = "Unlock"
    static let cancelUnlock = "Nevermind"
    static let unlockMenu = [confirmUnlock, cancelUnlock]

    /// While waiting out the open delay, the Unlock button gives the open back instead.
    static let cancelOpenButton = "Cancel Unlock"
    /// If iOS stopped the wait early, this lets the app through without using another open.
    static let openNowButton = "Open now"

    /// The Unlock button's text, or nil to hide the button.
    static func unlockButton(for group: BlockGroup?, opensLeft: Int?, request: TempUnlock.Request = .none) -> String? {
        switch request {
        case .waiting: return cancelOpenButton
        case .ready: return openNowButton
        case .none: break
        }
        guard let group, opensLeft != 0 else { return nil }
        // Strict mode removes Unlock, but a daily opens limit still applies.
        if group.isStrict(at: .now) && group.opensPerDay == nil { return nil }
        return group.openDelay > 0 ? "Unlock (\(group.openDelay)s)" : "Unlock"
    }
}
