import Foundation

/// TEMPORARY: timestamped events from the extensions, saved where they can be copied off the phone.
enum DebugLog {
    private static let key = "debugLog"

    static func add(_ event: String) {
        let defaults = AppGroup.defaults
        var lines = defaults.stringArray(forKey: key) ?? []
        let stamp = String(format: "%.2f", Date().timeIntervalSince1970)
        lines.append("\(stamp) \(event)")
        defaults.set(Array(lines.suffix(300)), forKey: key)
    }
}
