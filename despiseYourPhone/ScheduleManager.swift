import Foundation
import DeviceActivity

/// Starts and stops the daily block window. iOS calls the monitor extension
/// at the start and end of each window, even when this app isn't running.
enum ScheduleManager {
    private static let center = DeviceActivityCenter()

    static func startDailySchedule(from start: DateComponents, to end: DateComponents) throws {
        let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
        center.stopMonitoring([.dailySchedule])
        try center.startMonitoring(.dailySchedule, during: schedule)
    }

    static func stopDailySchedule() {
        center.stopMonitoring([.dailySchedule])
    }
}
