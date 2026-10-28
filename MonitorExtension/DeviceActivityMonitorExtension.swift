import DeviceActivity

/// iOS runs this in the background when a group's schedule window starts or ends,
/// and when an unlock runs out.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        GroupStore.updateAppRemovalLock()
        if let id = BlockGroup.id(from: activity, prefix: BlockGroup.schedulePrefix),
           let group = GroupStore.group(id: id),
           !TempUnlock.isGroupUnlocked(id) {
            GroupStore.applyShield(group)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        GroupStore.updateAppRemovalLock()
        if let id = BlockGroup.id(from: activity, prefix: BlockGroup.schedulePrefix),
           let group = GroupStore.group(id: id) {
            GroupStore.clearShield(group)
        } else if let id = BlockGroup.id(from: activity, prefix: BlockGroup.unlockPrefix) {
            TempUnlock.expire(id)
        }
    }

    /// For an unlock, the warning fires when the unlock minutes are up.
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        if let id = BlockGroup.id(from: activity, prefix: BlockGroup.unlockPrefix) {
            TempUnlock.expire(id)
        }
    }
}
