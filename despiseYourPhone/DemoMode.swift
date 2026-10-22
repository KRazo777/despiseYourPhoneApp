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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "hourglass")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                Text("\(appName) is blocked")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Take a breath. Is this what you meant to do?")
                    .foregroundStyle(Color(uiColor: .lightGray))
                    .multilineTextAlignment(.center)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(24)
        }
    }
}
