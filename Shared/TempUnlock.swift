import Foundation
import DeviceActivity

/// "Let me in": the block screen's second button.
/// The first tap starts a short wait. A tap after the wait lifts the group's shield for
/// `unlockMinutes`, then the monitor extension puts it back.
/// Groups with an opens limit use up one open each time, and the count resets at midnight.
enum TempUnlock {
    static let waitSeconds = 10

    /// A first tap older than this no longer counts, so the button doesn't stay armed forever.
    private static let requestExpirySeconds: TimeInterval = 120
    /// DeviceActivity won't monitor an interval shorter than 15 minutes.
    private static let minimumIntervalMinutes = 15

    enum Stage {
        case idle, waiting, ready
    }

    static func stage(requestedAt: Date?, now: Date = .now) -> Stage {
        guard let requestedAt else { return .idle }
        let elapsed = now.timeIntervalSince(requestedAt)
        if elapsed < 0 || elapsed > requestExpirySeconds { return .idle }
        return elapsed < TimeInterval(waitSeconds) ? .waiting : .ready
    }

    /// The stage of a group's real shield, from the time saved by the last tap.
    static func currentStage(for groupID: UUID, now: Date = .now) -> Stage {
        stage(requestedAt: date(forKey: requestedAtKey(groupID)), now: now)
    }

    static func isUnlocked(_ groupID: UUID, at date: Date = .now) -> Bool {
        guard let until = unlockedUntil(groupID) else { return false }
        return date < until
    }

    static func unlockedUntil(_ groupID: UUID) -> Date? {
        date(forKey: unlockedUntilKey(groupID))
    }

    // MARK: - Opens per day

    /// Opens left today, or nil when the group has no limit.
    static func opensLeft(_ group: BlockGroup, now: Date = .now) -> Int? {
        guard let limit = group.opensPerDay else { return nil }
        return max(0, limit - opensUsed(group.id, now: now))
    }

    static func opensUsed(_ groupID: UUID, now: Date = .now) -> Int {
        let defaults = AppGroup.defaults
        guard defaults.double(forKey: opensDayKey(groupID)) == today(now) else { return 0 }
        return defaults.integer(forKey: opensUsedKey(groupID))
    }

    private static func useOpen(_ groupID: UUID, now: Date) {
        let used = opensUsed(groupID, now: now)
        AppGroup.defaults.set(today(now), forKey: opensDayKey(groupID))
        AppGroup.defaults.set(used + 1, forKey: opensUsedKey(groupID))
    }

    private static func today(_ now: Date) -> Double {
        Calendar.current.startOfDay(for: now).timeIntervalSince1970
    }

    // MARK: - Tapping the button

    /// Handles a tap on "Let me in". Returns true if the shield was lifted.
    static func letMeIn(_ group: BlockGroup, now: Date = .now) -> Bool {
        if opensLeft(group, now: now) == 0 { return false }
        switch currentStage(for: group.id, now: now) {
        case .idle:
            AppGroup.defaults.set(now.timeIntervalSince1970, forKey: requestedAtKey(group.id))
            return false
        case .waiting:
            return false
        case .ready:
            AppGroup.defaults.removeObject(forKey: requestedAtKey(group.id))
            guard start(group, now: now) else { return false }
            if group.opensPerDay != nil { useOpen(group.id, now: now) }
            return true
        }
    }

    /// Called by the monitor extension when the unlock time is up.
    static func end(_ groupID: UUID) {
        AppGroup.defaults.removeObject(forKey: unlockedUntilKey(groupID))
        guard let group = GroupStore.group(id: groupID) else { return }
        DeviceActivityCenter().stopMonitoring([group.unlockActivity])
        GroupStore.refresh(group)
    }

    /// Forgets a deleted group's unlock state.
    static func reset(_ groupID: UUID) {
        AppGroup.defaults.removeObject(forKey: requestedAtKey(groupID))
        AppGroup.defaults.removeObject(forKey: unlockedUntilKey(groupID))
        AppGroup.defaults.removeObject(forKey: opensDayKey(groupID))
        AppGroup.defaults.removeObject(forKey: opensUsedKey(groupID))
    }

    private static func start(_ group: BlockGroup, now: Date) -> Bool {
        // Monitor at least 15 minutes and re-block at the warning, `unlockMinutes` in.
        let intervalMinutes = max(minimumIntervalMinutes, group.unlockMinutes)
        let warningMinutes = intervalMinutes - group.unlockMinutes
        let calendar = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(parts, from: now),
            intervalEnd: calendar.dateComponents(parts, from: now.addingTimeInterval(TimeInterval(intervalMinutes * 60))),
            repeats: false,
            warningTime: warningMinutes > 0 ? DateComponents(minute: warningMinutes) : nil
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([group.unlockActivity])
        do {
            try center.startMonitoring(group.unlockActivity, during: schedule)
        } catch {
            // Without a monitor nothing would re-block, so keep the shield up.
            return false
        }
        let until = now.addingTimeInterval(TimeInterval(group.unlockMinutes * 60))
        AppGroup.defaults.set(until.timeIntervalSince1970, forKey: unlockedUntilKey(group.id))
        GroupStore.clearShield(group)
        return true
    }

    private static func requestedAtKey(_ id: UUID) -> String { "unlockRequestedAt-\(id.uuidString)" }
    private static func unlockedUntilKey(_ id: UUID) -> String { "unlockedUntil-\(id.uuidString)" }
    private static func opensDayKey(_ id: UUID) -> String { "opensDay-\(id.uuidString)" }
    private static func opensUsedKey(_ id: UUID) -> String { "opensUsed-\(id.uuidString)" }

    private static func date(forKey key: String) -> Date? {
        let seconds = AppGroup.defaults.double(forKey: key)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }
}
