import SwiftUI
import FamilyControls

/// Shows the one-time onboarding screen, then the home screen.
struct ContentView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    /// Observed because iOS reports the status as not determined for a moment at launch,
    /// then updates it.
    @ObservedObject private var authorization = AuthorizationCenter.shared
    @State private var errorMessage: String?
    /// False for the first moment after launch, while the status may not have loaded yet.
    @State private var statusSettled = false

    var body: some View {
        // People who granted access before onboarding existed skip straight to home.
        if hasOnboarded || (!DemoMode.isOn && authorization.authorizationStatus == .approved) {
            HomeView()
                .onAppear { hasOnboarded = true }
        } else if !DemoMode.isOn && !statusSettled && authorization.authorizationStatus == .notDetermined {
            // Wait briefly instead of flashing the onboarding screen at someone already approved.
            Color.clear
                .task {
                    try? await Task.sleep(for: .seconds(1))
                    statusSettled = true
                }
        } else {
            OnboardingView { requestAccess() }
                .alert("Something went wrong", isPresented: .constant(errorMessage != nil)) {
                    Button("OK") { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "")
                }
        }
    }

    private func requestAccess() {
        Task {
            do {
                try await ScreenTimeAccess.request()
                hasOnboarded = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView()
}
