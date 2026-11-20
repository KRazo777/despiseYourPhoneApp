import SwiftUI

/// Demo mode fakes the Screen Time pieces that don't work in the Simulator
/// (authorization, the app picker, the shield) so every screen can be clicked through.
/// Nothing is actually blocked while it's on.
enum DemoMode {
    #if targetEnvironment(simulator)
    static let isOn = true
    #else
    static let isOn = false
    #endif

    /// Fake apps for the demo picker: name and SF Symbol.
    static let apps: [(name: String, icon: String)] = [
        ("Instagram", "camera"),
        ("TikTok", "music.note"),
        ("YouTube", "play.rectangle"),
        ("X", "bubble.left"),
        ("Reddit", "text.bubble"),
        ("Snapchat", "camera.viewfinder"),
        ("Safari", "safari"),
        ("Messages", "message"),
    ]
}

extension BlockGroup {
    /// Sample groups for previews.
    static let samples: [BlockGroup] = [
        BlockGroup(name: "Social", demoApps: ["Instagram", "TikTok", "Snapchat"], openDelaySeconds: 5, opensPerDay: 10),
        BlockGroup(name: "Bedtime", demoApps: ["YouTube", "Reddit"], usesSchedule: true),
    ]
}

/// Stand-in for the system FamilyActivityPicker.
struct DemoAppPicker: View {
    @Binding var selected: Set<String>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(DemoMode.apps, id: \.name) { app in
                Button {
                    if selected.contains(app.name) { selected.remove(app.name) } else { selected.insert(app.name) }
                } label: {
                    HStack {
                        Label(app.name, systemImage: app.icon).foregroundStyle(.primary)
                        Spacer()
                        if selected.contains(app.name) {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
            }
            .navigationTitle("Choose apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Mirrors ShieldConfigurationExtension's block screen. Keep the two in sync.
struct ShieldPreview: View {
    let appName: String
    let group: BlockGroup
    @Environment(\.dismiss) private var dismiss
    /// Stand in for what the real shield saves when Unlock is confirmed.
    @State private var request: TempUnlock.Request = .none
    /// Each app has its own count; the preview starts this app at none used.
    @State private var opensUsed = 0

    private var opensLeft: Int? {
        group.opensPerDay.map { max(0, $0 - opensUsed) }
    }

    var body: some View {
        ZStack {
            Color(white: ShieldCopy.backgroundWhite).ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: ShieldCopy.iconName)
                    .font(.system(size: ShieldCopy.iconPointSize, weight: .bold))
                    .foregroundStyle(.white)
                Text(ShieldCopy.title(for: appName))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                if let subtitle = ShieldCopy.subtitle(for: group, opensLeft: opensLeft, request: request) {
                    Text(subtitle)
                        .foregroundStyle(Color(uiColor: .lightGray))
                        .multilineTextAlignment(.center)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text(ShieldCopy.closeButton)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
                if let title = ShieldCopy.unlockButton(for: group, opensLeft: opensLeft, request: request) {
                    if request == .none {
                        Menu(title) {
                            Button(ShieldCopy.confirmUnlock) { unlockTapped() }
                            Button(ShieldCopy.cancelUnlock) { dismiss() }
                        }
                        .foregroundStyle(Color(white: ShieldCopy.unlockWhite))
                    } else {
                        Button(title) { cancelTapped() }
                            .foregroundStyle(Color(white: ShieldCopy.unlockWhite))
                    }
                }
            }
            .padding(24)
        }
    }

    /// Like the real shield: the open is used on the tap, then the app opens once the open delay
    /// is over unless "Cancel open" was tapped first.
    private func unlockTapped() {
        guard request == .none else { return }
        if group.opensPerDay != nil { opensUsed += 1 }
        let until = Date.now.addingTimeInterval(TimeInterval(group.openDelay))
        request = .waiting(until: until)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(group.openDelay)) {
            if request == .waiting(until: until) { dismiss() }
        }
    }

    private func cancelTapped() {
        guard request != .none else { return }
        request = .none
        if group.opensPerDay != nil { opensUsed -= 1 }
        dismiss()
    }
}

#Preview("App picker") {
    DemoAppPicker(selected: .constant(["Instagram", "TikTok"]))
}

#Preview("Block screen") {
    ShieldPreview(appName: "Instagram", group: BlockGroup.samples[0])
}
