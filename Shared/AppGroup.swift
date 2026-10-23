import Foundation
import ManagedSettings
import DeviceActivity

/// Values shared by the app and every extension.
/// The App Group ID must match the one you add under Signing & Capabilities on all four targets.
enum AppGroup {
    static let id = "group.com.kevinrazo.despiseyourphone"

    static let defaults: UserDefaults = {
        let defaults = UserDefaults(suiteName: id)!
        defaults.register(defaults: [
            Key.scheduleStart: 22 * 60,
            Key.scheduleEnd: 7 * 60,
        ])
        return defaults
    }()

    /// Keys for `defaults`, so the app and extensions read the same values.
    enum Key {
        static let blockNow = "blockNow"
        static let scheduleOn = "scheduleOn"
        /// Minutes after midnight.
        static let scheduleStart = "scheduleStartMinutes"
        static let scheduleEnd = "scheduleEndMinutes"
    }
}

extension ManagedSettingsStore.Name {
    /// One named store so the app and the monitor extension edit the same shield.
    static let blocks = Self("blocks")
}

extension DeviceActivityName {
    static let dailySchedule = Self("dailySchedule")
}
