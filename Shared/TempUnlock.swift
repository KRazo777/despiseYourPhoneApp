import Foundation
import CryptoKit
import DeviceActivity
import ManagedSettings

/// What a block screen is shielding: one app, one website, or (when iOS only tells us
/// the category) the whole group.
enum ShieldTarget {
    case app(ApplicationToken)
    case web(WebDomainToken)
    case group

    /// A stable name for the target, used in saved counts and unlocks.
    var key: String {
        switch self {
        case .app(let token): "app-" + Self.hash(token)
        case .web(let token): "web-" + Self.hash(token)
        case .group: "group"
        }
    }

    fileprivate var tokenData: Data? {
        switch self {
        case .app(let token): try? JSONEncoder().encode(token)
        case .web(let token): try? JSONEncoder().encode(token)
        case .group: nil
        }
    }

    private static func hash<T: Encodable>(_ token: T) -> String {
        let data = (try? JSONEncoder().encode(token)) ?? Data()
        return SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
    }
}

/// "Unlock": the block screen's second button.
/// Confirming uses one of that app's opens and lets the app through once the group's open
/// delay is over. Close during the delay gives the open back.
/// Each app has its own daily opens count. The rest of the group stays blocked, and the
/// monitor extension blocks the app again when its open duration is up.
enum TempUnlock {
    /// DeviceActivity won't monitor an interval shorter than 15 minutes.
    private static let minimumIntervalMinutes = 15
    /// The re-block warning only has minute precision, so it can fire a little early.
    private static let expiryTolerance: TimeInterval = 60

    // MARK: - Opens per day

    /// Opens left today for this app, or nil when the group has no limit.
    static func opensLeft(_ group: BlockGroup, _ target: ShieldTarget, now: Date = .now) -> Int? {
        guard let limit = group.opensPerDay else { return nil }
        return max(0, limit - (opensUsedToday(group.id, now: now)[target.key] ?? 0))
    }

    /// Every target's opens used today. The counts start over on a new day.
    private static func opensUsedToday(_ groupID: UUID, now: Date) -> [String: Int] {
        let defaults = AppGroup.defaults
        guard defaults.double(forKey: opensDayKey(groupID)) == today(now) else { return [:] }
        return defaults.dictionary(forKey: opensKey(groupID)) as? [String: Int] ?? [:]
    }

    /// Adds `count` to this target's opens used today (-1 gives one back).
    private static func useOpen(_ groupID: UUID, _ target: ShieldTarget, count: Int = 1, now: Date) {
        var used = opensUsedToday(groupID, now: now)
        used[target.key] = max(0, used[target.key, default: 0] + count)
        AppGroup.defaults.set(today(now), forKey: opensDayKey(groupID))
        AppGroup.defaults.set(used, forKey: opensKey(groupID))
    }

    private static func today(_ now: Date) -> Double {
        Calendar.current.startOfDay(for: now).timeIntervalSince1970
    }

    // MARK: - Tapping the button

    /// Whether the block screen should offer Unlock at all.
    static func canUnlock(_ group: BlockGroup, _ target: ShieldTarget, now: Date = .now) -> Bool {
        if opensLeft(group, target, now: now) == 0 { return false }
        // Strict mode removes Unlock, but a daily opens limit still applies.
        return !(group.isStrict(at: now) && group.opensPerDay == nil)
    }

    /// A little longer than the delay itself, for the held answer to reach iOS.
    private static let waitGrace: TimeInterval = 10

    /// True while a confirmed Unlock is waiting out the open delay.
    static func isWaiting(_ group: BlockGroup, _ target: ShieldTarget, now: Date = .now) -> Bool {
        guard let requestedAt = requestedAt(group, target) else { return false }
        let elapsed = now.timeIntervalSince(requestedAt)
        return elapsed >= 0 && elapsed < TimeInterval(group.openDelay) + waitGrace
    }

    /// If iOS stopped the extension mid-wait, the request is left behind and the app never
    /// opened, so give its open back.
    static func dropStaleRequest(_ group: BlockGroup, _ target: ShieldTarget, now: Date = .now) {
        guard requestedAt(group, target) != nil, !isWaiting(group, target, now: now) else { return }
        cancelUnlock(group, target, now: now)
    }

    private static func requestedAt(_ group: BlockGroup, _ target: ShieldTarget) -> Date? {
        let seconds = AppGroup.defaults.double(forKey: requestedAtKey(group.id, target))
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    /// Confirming Unlock uses up one of the app's opens straight away, before any open delay.
    /// `cancelUnlock` (Close during the delay) gives it back.
    static func beginUnlock(_ group: BlockGroup, _ target: ShieldTarget, now: Date = .now) {
        AppGroup.defaults.set(now.timeIntervalSince1970, forKey: requestedAtKey(group.id, target))
        if group.opensPerDay != nil { useOpen(group.id, target, now: now) }
    }

    /// Drops the waiting request and gives its open back.
    static func cancelUnlock(_ group: BlockGroup, _ target: ShieldTarget, now: Date = .now) {
        guard requestedAt(group, target) != nil else { return }
        AppGroup.defaults.removeObject(forKey: requestedAtKey(group.id, target))
        if group.opensPerDay != nil { useOpen(group.id, target, count: -1, now: now) }
    }

    /// Lets this app through for the group's open duration. Call `beginUnlock` first;
    /// the open it used is given back if the unlock fails. With `onlyIfRequested`, does nothing
    /// once the request is gone (cancelled, or already opened). Returns true if it worked.
    static func unlock(_ group: BlockGroup, _ target: ShieldTarget, onlyIfRequested: Bool = false, now: Date = .now) -> Bool {
        if onlyIfRequested && requestedAt(group, target) == nil { return false }
        AppGroup.defaults.removeObject(forKey: requestedAtKey(group.id, target))
        // The open is already paid for, so only strict mode can stop it now.
        guard !(group.isStrict(at: now) && group.opensPerDay == nil) else { return false }

        var unlocks = activeUnlocks(group.id, now: now)
        unlocks[target.key] = now.addingTimeInterval(TimeInterval(group.unlockMinutes * 60))
        var tokens = AppGroup.defaults.dictionary(forKey: tokensKey(group.id)) as? [String: Data] ?? [:]
        tokens[target.key] = target.tokenData
        guard scheduleRelock(group, unlocks: unlocks, now: now) else {
            // Without a monitor nothing would re-block, so keep the shield up.
            if group.opensPerDay != nil { useOpen(group.id, target, count: -1, now: now) }
            return false
        }
        saveUnlocks(group.id, unlocks)
        AppGroup.defaults.set(tokens, forKey: tokensKey(group.id))
        GroupStore.refresh(group)
        return true
    }

    // MARK: - Unlocked apps

    /// Unlocks that haven't run out yet, by target key.
    static func activeUnlocks(_ groupID: UUID, now: Date = .now) -> [String: Date] {
        let saved = AppGroup.defaults.dictionary(forKey: unlocksKey(groupID)) as? [String: Double] ?? [:]
        return saved
            .mapValues { Date(timeIntervalSince1970: $0) }
            .filter { $0.value > now }
    }

    /// True when the whole group is unlocked (an unlock that couldn't name one app).
    static func isGroupUnlocked(_ groupID: UUID, at date: Date = .now) -> Bool {
        activeUnlocks(groupID, now: date)[ShieldTarget.group.key] != nil
    }

    /// Unlocked apps and websites, so the shield can leave them out.
    static func unlockedTokens(_ groupID: UUID, now: Date = .now) -> (apps: Set<ApplicationToken>, webDomains: Set<WebDomainToken>) {
        let keys = Set(activeUnlocks(groupID, now: now).keys)
        let tokens = AppGroup.defaults.dictionary(forKey: tokensKey(groupID)) as? [String: Data] ?? [:]
        var apps = Set<ApplicationToken>()
        var webDomains = Set<WebDomainToken>()
        for (key, data) in tokens where keys.contains(key) {
            if key.hasPrefix("app-"), let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) {
                apps.insert(token)
            } else if key.hasPrefix("web-"), let token = try? JSONDecoder().decode(WebDomainToken.self, from: data) {
                webDomains.insert(token)
            }
        }
        return (apps, webDomains)
    }

    /// Called by the monitor extension when the earliest unlock is up: blocks the expired
    /// apps again and schedules the next re-block, if any apps are still unlocked.
    static func expire(_ groupID: UUID, now: Date = .now) {
        let remaining = activeUnlocks(groupID, now: now.addingTimeInterval(expiryTolerance))
        saveUnlocks(groupID, remaining)
        guard let group = GroupStore.group(id: groupID) else { return }
        _ = scheduleRelock(group, unlocks: remaining, now: now)
        GroupStore.refresh(group)
    }

    /// Forgets a deleted group's opens and unlocks.
    static func reset(_ groupID: UUID) {
        let defaults = AppGroup.defaults
        for key in defaults.dictionaryRepresentation().keys where key.contains(groupID.uuidString) {
            defaults.removeObject(forKey: key)
        }
    }

    /// One DeviceActivity per group re-blocks at the earliest unlock's end.
    /// It runs at least 15 minutes, so the warning marks the actual re-block time.
    private static func scheduleRelock(_ group: BlockGroup, unlocks: [String: Date], now: Date) -> Bool {
        let center = DeviceActivityCenter()
        center.stopMonitoring([group.unlockActivity])
        guard let earliest = unlocks.values.min() else { return true }

        let minutesLeft = max(1, Int((earliest.timeIntervalSince(now) / 60).rounded(.up)))
        let intervalMinutes = max(minimumIntervalMinutes, minutesLeft)
        let warningMinutes = intervalMinutes - minutesLeft
        let calendar = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(parts, from: now),
            intervalEnd: calendar.dateComponents(parts, from: now.addingTimeInterval(TimeInterval(intervalMinutes * 60))),
            repeats: false,
            warningTime: warningMinutes > 0 ? DateComponents(minute: warningMinutes) : nil
        )
        do {
            try center.startMonitoring(group.unlockActivity, during: schedule)
            return true
        } catch {
            return false
        }
    }

    private static func saveUnlocks(_ groupID: UUID, _ unlocks: [String: Date]) {
        AppGroup.defaults.set(unlocks.mapValues(\.timeIntervalSince1970), forKey: unlocksKey(groupID))
    }

    private static func requestedAtKey(_ id: UUID, _ target: ShieldTarget) -> String { "unlockRequestedAt-\(id.uuidString)-\(target.key)" }
    private static func unlocksKey(_ id: UUID) -> String { "unlocks-\(id.uuidString)" }
    private static func tokensKey(_ id: UUID) -> String { "unlockTokens-\(id.uuidString)" }
    private static func opensDayKey(_ id: UUID) -> String { "opensDay-\(id.uuidString)" }
    private static func opensKey(_ id: UUID) -> String { "appOpens-\(id.uuidString)" }
}
