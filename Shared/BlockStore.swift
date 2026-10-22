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
}
