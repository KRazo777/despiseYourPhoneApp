import DeviceActivity

/// iOS runs this in the background at the start and end of each scheduled window.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity == .dailySchedule {
            BlockStore.applyShield()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        switch activity {
        case .dailySchedule:
            // Leave the shield up if Block now is still on.
            if !BlockStore.blockNow { BlockStore.clearShield() }
        case .tempUnlock:
            TempUnlock.end()
        default:
            break
        }
    }

    /// For a "Let me in" unlock, the warning fires when the unlock minutes are up.
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        if activity == .tempUnlock {
            TempUnlock.end()
        }
    }
}
