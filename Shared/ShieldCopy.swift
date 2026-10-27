import Foundation

/// Text on the block screen. Shared so the real shield and the app's demo preview match.
enum ShieldCopy {
    static let closeButton = "Close"

    static func title(for name: String?) -> String {
        "\(name ?? "This app") is blocked"
    }

    static func subtitle(for group: BlockGroup?, opensLeft: Int?) -> String {
        let breath = "Take a breath. Is this what you meant to do?"
        guard let group else { return breath }
        if opensLeft == 0 {
            return "Blocked by \(group.name). You've used all your opens for today."
        }
        if let until = group.strictUntil, group.isStrict(at: .now) {
            return "Blocked by \(group.name). Strict mode is on until \(until.formatted(date: .omitted, time: .shortened))."
        }
        return "Blocked by \(group.name). \(breath)"
    }

    /// The second button's text, or nil to hide the button.
    static func secondaryButton(for group: BlockGroup?, stage: TempUnlock.Stage, opensLeft: Int?) -> String? {
        guard let group, opensLeft != 0 else { return nil }
        // Strict mode removes "Let me in", but a daily opens limit still applies.
        if group.isStrict(at: .now) && group.opensPerDay == nil { return nil }
        switch stage {
        case .idle:
            if let opensLeft, let limit = group.opensPerDay {
                return "Use an open (\(opensLeft) of \(limit) left today)"
            }
            return "Let me in"
        case .waiting:
            return "Wait \(TempUnlock.waitSeconds) seconds, then tap again"
        case .ready:
            return "Open for \(group.unlockMinutes) minutes"
        }
    }
}
