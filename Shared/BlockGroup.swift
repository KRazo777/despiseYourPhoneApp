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
    /// How long the block screen's Unlock button unlocks the group for.
    var unlockMinutes = 5
    /// Seconds between the first tap on Unlock and the tap that works.
    /// Groups saved before this setting existed have nil and keep the old 10-second wait.
    var openDelaySeconds: Int? = 0
    /// How many times a day the block screen lets you in. nil means no limit.
    var opensPerDay: Int?
    /// Until this time the group can't be turned off, edited, or deleted,
    /// and the block screen has no Unlock button (daily opens still work).
    var strictUntil: Date?

    /// iOS stops waiting for the block screen's answer at about 30 seconds, after which the
    /// app can't open on its own, so longer delays saved earlier are cut to this.
    static let maxOpenDelay = 25

    var openDelay: Int { min(openDelaySeconds ?? 10, Self.maxOpenDelay) }

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

    // MARK: - One group per app

    /// A copy holding only the apps, categories, and websites `other` also has.
    /// A category in one group and an app from it in another can't be matched,
    /// since iOS hides which apps a category holds.
    func shared(with other: BlockGroup) -> BlockGroup {
        var copy = self
        copy.selection.applicationTokens.formIntersection(other.selection.applicationTokens)
        copy.selection.categoryTokens.formIntersection(other.selection.categoryTokens)
        copy.selection.webDomainTokens.formIntersection(other.selection.webDomainTokens)
        copy.demoApps = demoApps.filter(other.demoApps.contains)
        return copy
    }

    func overlaps(_ other: BlockGroup) -> Bool {
        shared(with: other).hasApps
    }

    /// A copy without anything `other` also has.
    func removingItems(of other: BlockGroup) -> BlockGroup {
        var copy = self
        copy.selection.applicationTokens.subtract(other.selection.applicationTokens)
        copy.selection.categoryTokens.subtract(other.selection.categoryTokens)
        copy.selection.webDomainTokens.subtract(other.selection.webDomainTokens)
        copy.demoApps.removeAll(where: other.demoApps.contains)
        return copy
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
