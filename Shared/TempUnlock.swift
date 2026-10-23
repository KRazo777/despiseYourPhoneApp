import Foundation
import DeviceActivity

/// "Let me in": the block screen's second button.
/// The first tap starts a short wait. A tap after the wait lifts the shield for a few minutes,
/// then the monitor extension puts it back.
enum TempUnlock {
    static let waitSeconds = 10
    static let unlockMinutes = 5

    /// A first tap older than this no longer counts, so the button doesn't stay armed forever.
    private static let requestExpirySeconds: TimeInterval = 120
    /// DeviceActivity won't monitor an interval shorter than 15 minutes, so we monitor 15
    /// and re-block at the warning `unlockMinutes` in.
    private static let monitorMinutes = 15
    private static let requestedAtKey = "unlockRequestedAt"

    enum Stage {
        case idle, waiting, ready

        var buttonTitle: String {
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

    /// The stage of the real shield, from the time saved by the last tap.
    static func currentStage(now: Date = .now) -> Stage {
        stage(requestedAt: savedRequestTime, now: now)
    }

    /// Handles a tap on "Let me in". Returns true if the shield was lifted.
    static func letMeIn(now: Date = .now) -> Bool {
        switch currentStage(now: now) {
        case .idle:
            AppGroup.defaults.set(now.timeIntervalSince1970, forKey: requestedAtKey)
            return false
        case .waiting:
            return false
        case .ready:
            AppGroup.defaults.removeObject(forKey: requestedAtKey)
            return start(now: now)
        }
    }

    /// Called by the monitor extension when the unlock time is up.
    static func end() {
        DeviceActivityCenter().stopMonitoring([.tempUnlock])
        BlockStore.refreshShield()
    }

    private static var savedRequestTime: Date? {
        let seconds = AppGroup.defaults.double(forKey: requestedAtKey)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    private static func start(now: Date) -> Bool {
        let calendar = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(parts, from: now),
            intervalEnd: calendar.dateComponents(parts, from: now.addingTimeInterval(TimeInterval(monitorMinutes * 60))),
            repeats: false,
            warningTime: DateComponents(minute: monitorMinutes - unlockMinutes)
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([.tempUnlock])
        do {
            try center.startMonitoring(.tempUnlock, during: schedule)
        } catch {
            // Without a monitor nothing would re-block, so keep the shield up.
            return false
        }
        BlockStore.clearShield()
        return true
    }
}

extension DeviceActivityName {
    static let tempUnlock = Self("tempUnlock")
}
