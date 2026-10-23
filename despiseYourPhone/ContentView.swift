import SwiftUI
import FamilyControls

/// Shows the one-time onboarding screen, then the home screen.
struct ContentView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var errorMessage: String?

    var body: some View {
        // People who granted access before onboarding existed skip straight to home.
        if hasOnboarded || (!DemoMode.isOn && AuthorizationCenter.shared.authorizationStatus == .approved) {
            HomeView()
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
