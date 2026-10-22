import Foundation
import ManagedSettings
import DeviceActivity

/// Values shared by the app and every extension.
/// The App Group ID must match the one you add under Signing & Capabilities on all four targets.
enum AppGroup {
    static let id = "group.com.kevinrazo.despiseyourphone"
    static let defaults = UserDefaults(suiteName: id)!
}

extension ManagedSettingsStore.Name {
    /// One named store so the app and the monitor extension edit the same shield.
    static let blocks = Self("blocks")
}

extension DeviceActivityName {
    static let dailySchedule = Self("dailySchedule")
}
