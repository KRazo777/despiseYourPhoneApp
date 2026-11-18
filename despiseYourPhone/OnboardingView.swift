import SwiftUI

/// First-launch screen that explains why the app needs Screen Time access.
struct OnboardingView: View {
    let onAllow: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "hourglass")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.tint)

            Text("Take your time back")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 20) {
                point("hand.raised", "Block the apps that pull you in, right now or on a daily schedule.")
                point("lock.shield", "Uses Apple's Screen Time, so iOS does the blocking.")
                point("eye.slash", "Your privacy matters: This app never learns which apps you pick or what you do in them.")
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onAllow) {
                    Text("Allow Screen Time access")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("iOS will ask you to confirm with Face ID or your passcode.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
    }

    private func point(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 28)
        }
        .font(.body)
    }
}

#Preview {
    OnboardingView {}
}
