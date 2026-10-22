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
        if activity == .dailySchedule {
            BlockStore.clearShield()
        }
    }
}
