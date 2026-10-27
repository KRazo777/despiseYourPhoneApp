import Foundation
import DeviceActivity

/// "Let me in": the block screen's second button.
/// The first tap starts a short wait. A tap after the wait lifts the group's shield for
/// `unlockMinutes`, then the monitor extension puts it back.
enum TempUnlock {
    static let waitSeconds = 10

    /// A first tap older than this no longer counts, so the button doesn't stay armed forever.
    private static let requestExpirySeconds: TimeInterval = 120
    /// DeviceActivity won't monitor an interval shorter than 15 minutes.
    private static let minimumIntervalMinutes = 15

    enum Stage {
        case idle, waiting, ready

        func buttonTitle(unlockMinutes: Int) -> String {
            switch self {
            case .idle: "Let me in"
            case .waiting: "Wait \(waitSeconds) seconds, then tap again"
            case .ready: "Unlock for \(unlockMinutes) minutes"
            }
        }
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

    /// Handles a tap on "Let me in". Returns true if the shield was lifted.
    static func letMeIn(_ group: BlockGroup, now: Date = .now) -> Bool {
        switch currentStage(for: group.id, now: now) {
        case .idle:
            AppGroup.defaults.set(now.timeIntervalSince1970, forKey: requestedAtKey(group.id))
            return false
        case .waiting:
            return false
        case .ready:
            AppGroup.defaults.removeObject(forKey: requestedAtKey(group.id))
            return start(group, now: now)
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

    private static func date(forKey key: String) -> Date? {
        let seconds = AppGroup.defaults.double(forKey: key)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }
}
