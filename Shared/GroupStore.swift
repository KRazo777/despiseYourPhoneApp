import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Saves the block groups and turns each group's shield and schedule on or off.
/// Lives in Shared/ so the app and every extension use the same rules.
enum GroupStore {
    private static let groupsKey = "blockGroups"

    static func load() -> [BlockGroup] {
        guard
            let data = AppGroup.defaults.data(forKey: groupsKey),
            let groups = try? JSONDecoder().decode([BlockGroup].self, from: data)
        else { return [] }
        return groups
    }

    static func save(_ groups: [BlockGroup]) {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        AppGroup.defaults.set(data, forKey: groupsKey)
    }

    static func group(id: UUID) -> BlockGroup? {
        load().first { $0.id == id }
    }

    /// The group that blocks this app, website, or category.
    /// An app can be in several groups, so groups that are blocking right now come first,
    /// longest open delay first, then the rest in list order.
    static func group(application: ApplicationToken? = nil, webDomain: WebDomainToken? = nil, category: ActivityCategoryToken? = nil) -> BlockGroup? {
        let all = load()
        let blocking = all.filter { isBlocking($0) }.sorted { $0.openDelay > $1.openDelay }
        let groups = blocking + all.filter { !isBlocking($0) }
        if let application, let match = groups.first(where: { $0.selection.applicationTokens.contains(application) }) {
            return match
        }
        if let webDomain, let match = groups.first(where: { $0.selection.webDomainTokens.contains(webDomain) }) {
            return match
        }
        if let category, let match = groups.first(where: { $0.selection.categoryTokens.contains(category) }) {
            return match
        }
        // An app blocked through its category arrives with only its own token,
        // so fall back to a blocking group that uses categories.
        return groups.first { isBlocking($0) && !$0.selection.categoryTokens.isEmpty }
    }

    // MARK: - Shields

    /// True when the group's rules say block and it isn't temporarily unlocked.
    static func isBlocking(_ group: BlockGroup, at date: Date = .now) -> Bool {
        group.isScheduledToBlock(at: date) && !TempUnlock.isGroupUnlocked(group.id, at: date)
    }

    /// Turns the group's shield on or off to match `isBlocking`.
    static func refresh(_ group: BlockGroup) {
        isBlocking(group) ? applyShield(group) : clearShield(group)
    }

    /// Shields the group's apps and sites, leaving out any that are unlocked right now.
    static func applyShield(_ group: BlockGroup) {
        let selection = group.selection
        let unlocked = TempUnlock.unlockedTokens(group.id)
        let apps = selection.applicationTokens.subtracting(unlocked.apps)
        let webDomains = selection.webDomainTokens.subtracting(unlocked.webDomains)
        let store = ManagedSettingsStore(named: group.storeName)
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens, except: unlocked.apps)
        store.shield.webDomains = webDomains.isEmpty ? nil : webDomains
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens, except: unlocked.webDomains)
    }

    static func clearShield(_ group: BlockGroup) {
        ManagedSettingsStore(named: group.storeName).clearAllSettings()
    }

    // MARK: - Syncing from the app

    /// Saves the groups and brings every shield and schedule in line with them.
    /// `removed` are groups the user deleted, so their shields and schedules get cleaned up.
    static func sync(_ groups: [BlockGroup], removed: [BlockGroup] = []) throws {
        save(groups)
        for group in removed {
            clearShield(group)
            DeviceActivityCenter().stopMonitoring([group.scheduleActivity, group.unlockActivity])
            TempUnlock.reset(group.id)
        }
        for group in groups {
            try updateSchedule(group)
            refresh(group)
        }
        updateAppRemovalLock(groups)
    }

    /// While any group is in strict mode, ask iOS not to let this app be deleted,
    /// since deleting it would remove every block.
    static func updateAppRemovalLock(_ groups: [BlockGroup] = load(), now: Date = .now) {
        let anyStrict = groups.contains { $0.isStrict(at: now) }
        ManagedSettingsStore(named: .init("strict")).application.denyAppRemoval = anyStrict ? true : nil
    }

    /// iOS calls the monitor extension at the start and end of each scheduled window,
    /// even when the app isn't running.
    private static func updateSchedule(_ group: BlockGroup) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([group.scheduleActivity])
        guard group.isOn, group.usesSchedule else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: group.startMinutes / 60, minute: group.startMinutes % 60),
            intervalEnd: DateComponents(hour: group.endMinutes / 60, minute: group.endMinutes % 60),
            repeats: true
        )
        try center.startMonitoring(group.scheduleActivity, during: schedule)
    }

    // MARK: - One group per app

    /// An app can only be in one group, but groups saved before that rule may share apps.
    /// A group that's on keeps them (strict first, then the longest open delay), or the
    /// newest group if none is on, and the others lose them.
    static func removeSharedApps(now: Date = .now) {
        let groups = load()
        let byPriority = groups.indices.sorted { a, b in
            let (x, y) = (groups[a], groups[b])
            if x.isOn != y.isOn { return x.isOn }
            if x.isStrict(at: now) != y.isStrict(at: now) { return x.isStrict(at: now) }
            if x.openDelay != y.openDelay { return x.openDelay > y.openDelay }
            return a > b
        }
        var result = groups
        var claimed: [BlockGroup] = []
        for index in byPriority {
            for keeper in claimed { result[index] = result[index].removingItems(of: keeper) }
            claimed.append(result[index])
        }
        guard result != groups else { return }
        try? sync(result)
    }

    // MARK: - Moving from the single-list version

    private static let migratedKey = "migratedToGroups"

    /// Earlier versions had one app list, a Block now switch, and one schedule.
    /// Turns that into a first group and removes the old shield and schedules.
    static func migrateIfNeeded() {
        let defaults = AppGroup.defaults
        guard !defaults.bool(forKey: migratedKey) else { return }
        defer { defaults.set(true, forKey: migratedKey) }

        guard
            let data = defaults.data(forKey: "blockedSelection"),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

        let blockNow = defaults.bool(forKey: "blockNow")
        let scheduleOn = defaults.bool(forKey: "scheduleOn")
        var group = BlockGroup(name: "My apps", selection: selection)
        group.isOn = blockNow || scheduleOn
        group.usesSchedule = scheduleOn && !blockNow
        if defaults.object(forKey: "scheduleStartMinutes") != nil {
            group.startMinutes = defaults.integer(forKey: "scheduleStartMinutes")
            group.endMinutes = defaults.integer(forKey: "scheduleEndMinutes")
        }

        ManagedSettingsStore(named: .init("blocks")).clearAllSettings()
        DeviceActivityCenter().stopMonitoring([.init("dailySchedule"), .init("tempUnlock")])
        try? sync(load() + [group])
    }
}
