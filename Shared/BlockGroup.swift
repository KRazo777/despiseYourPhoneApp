import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// A set of apps with its own blocking rules. Each group has its own shield store
/// and its own DeviceActivity names, so groups never interfere with each other.
struct BlockGroup: Codable, Identifiable, Equatable {
    /// Each group can use two DeviceActivity names, and iOS allows about 20 at once.
    static let maxCount = 10

    var id = UUID()
    var name: String
    var selection = FamilyActivitySelection()
    /// Sample app names used instead of `selection` in demo mode.
    var demoApps: [String] = []
    var isOn = true
    /// Off means the group blocks all day.
    var usesSchedule = false
    /// Minutes after midnight.
    var startMinutes = 22 * 60
    var endMinutes = 7 * 60
    /// How long each open (or "Let me in") unlocks the group for.
    var unlockMinutes = 5
    /// How many times a day the block screen lets you in. nil means no limit.
    var opensPerDay: Int?
    /// Until this time the group can't be turned off, edited, or deleted,
    /// and the block screen has no "Let me in" (daily opens still work).
    var strictUntil: Date?

    var hasApps: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty || !demoApps.isEmpty
    }

    func isStrict(at date: Date) -> Bool {
        guard isOn, let strictUntil else { return false }
        return date < strictUntil
    }

    /// Whether the group's rules say it should block at `date`, ignoring any temporary unlock.
    func isScheduledToBlock(at date: Date) -> Bool {
        guard isOn else { return false }
        guard usesSchedule else { return true }
        return Self.isInWindow(start: startMinutes, end: endMinutes, at: date)
    }

    static func isInWindow(start: Int, end: Int, at date: Date) -> Bool {
        guard start != end else { return false }
        let time = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (time.hour ?? 0) * 60 + (time.minute ?? 0)
        // A window like 22:00-07:00 wraps past midnight.
        return start < end
            ? minutes >= start && minutes < end
            : minutes >= start || minutes < end
    }

    // MARK: - Names for Screen Time

    var storeName: ManagedSettingsStore.Name { .init("group-\(id.uuidString)") }
    var scheduleActivity: DeviceActivityName { .init(Self.schedulePrefix + id.uuidString) }
    var unlockActivity: DeviceActivityName { .init(Self.unlockPrefix + id.uuidString) }

    static let schedulePrefix = "schedule-"
    static let unlockPrefix = "unlock-"

    /// The group ID inside an activity name like "schedule-<id>".
    static func id(from activity: DeviceActivityName, prefix: String) -> UUID? {
        guard activity.rawValue.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(activity.rawValue.dropFirst(prefix.count)))
    }
}
