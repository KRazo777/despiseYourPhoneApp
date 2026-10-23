import Foundation
import FamilyControls
import ManagedSettings

/// Saves the user's chosen apps and turns the shield on or off.
/// Lives in Shared/ so the app and the monitor extension both compile it.
enum BlockStore {
    private static let selectionKey = "blockedSelection"

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        AppGroup.defaults.set(data, forKey: selectionKey)
    }

    static func loadSelection() -> FamilyActivitySelection {
        guard
            let data = AppGroup.defaults.data(forKey: selectionKey),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    static func applyShield() {
        let selection = loadSelection()
        let store = ManagedSettingsStore(named: .blocks)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    static func clearShield() {
        ManagedSettingsStore(named: .blocks).clearAllSettings()
    }

    // MARK: - Whether blocking should be on

    static var blockNow: Bool { AppGroup.defaults.bool(forKey: AppGroup.Key.blockNow) }

    /// True when Block now is on, or the daily schedule is on and `date` falls inside its window.
    static func shouldBlock(at date: Date = .now) -> Bool {
        let defaults = AppGroup.defaults
        return shouldBlock(
            blockNow: defaults.bool(forKey: AppGroup.Key.blockNow),
            scheduleOn: defaults.bool(forKey: AppGroup.Key.scheduleOn),
            startMinutes: defaults.integer(forKey: AppGroup.Key.scheduleStart),
            endMinutes: defaults.integer(forKey: AppGroup.Key.scheduleEnd),
            at: date
        )
    }

    static func shouldBlock(blockNow: Bool, scheduleOn: Bool, startMinutes: Int, endMinutes: Int, at date: Date) -> Bool {
        if blockNow { return true }
        guard scheduleOn, startMinutes != endMinutes else { return false }
        let time = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (time.hour ?? 0) * 60 + (time.minute ?? 0)
        // A window like 22:00-07:00 wraps past midnight.
        return startMinutes < endMinutes
            ? minutes >= startMinutes && minutes < endMinutes
            : minutes >= startMinutes || minutes < endMinutes
    }

    /// Turns the shield on or off to match `shouldBlock()`.
    static func refreshShield() {
        shouldBlock() ? applyShield() : clearShield()
    }
}
