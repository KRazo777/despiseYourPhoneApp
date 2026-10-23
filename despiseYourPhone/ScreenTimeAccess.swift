import FamilyControls

/// Wraps Screen Time authorization. In demo mode access is always treated as granted.
enum ScreenTimeAccess {
    static var isApproved: Bool {
        DemoMode.isOn || AuthorizationCenter.shared.authorizationStatus == .approved
    }

    static func request() async throws {
        guard !DemoMode.isOn else { return }
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }
}
