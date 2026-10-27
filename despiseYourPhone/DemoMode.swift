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
        BlockGroup(name: "Social", demoApps: ["Instagram", "TikTok", "Snapchat"], opensPerDay: 3),
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
    /// Stand in for what the real shield saves when its second button is tapped.
    @State private var requestedAt: Date?
    @State private var opensUsed = 0

    private var opensLeft: Int? {
        group.opensPerDay.map { max(0, $0 - opensUsed) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "hourglass")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                Text(ShieldCopy.title(for: appName))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(ShieldCopy.subtitle(for: group, opensLeft: opensLeft))
                    .foregroundStyle(Color(uiColor: .lightGray))
                    .multilineTextAlignment(.center)
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
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let stage = TempUnlock.stage(requestedAt: requestedAt, now: context.date)
                    if let title = ShieldCopy.secondaryButton(for: group, stage: stage, opensLeft: opensLeft) {
                        Button(title) { letMeIn(stage) }
                            .foregroundStyle(Color(uiColor: .lightGray))
                    }
                }
            }
            .padding(24)
        }
    }

    private func letMeIn(_ stage: TempUnlock.Stage) {
        switch stage {
        case .idle: requestedAt = .now
        case .waiting: break
        case .ready:
            if group.opensPerDay != nil { opensUsed += 1 }
            requestedAt = nil
            dismiss()
        }
    }
}

#Preview("App picker") {
    DemoAppPicker(selected: .constant(["Instagram", "TikTok"]))
}

#Preview("Block screen") {
    ShieldPreview(appName: "Instagram", group: BlockGroup.samples[0])
}
