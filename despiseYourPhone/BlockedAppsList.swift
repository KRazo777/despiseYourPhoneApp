import SwiftUI
import FamilyControls

/// Rows for the chosen apps, categories, and websites, with their real icons.
/// In demo mode it shows the sample apps instead.
struct BlockedAppsList: View {
    let selection: FamilyActivitySelection
    let demoSelection: Set<String>

    var body: some View {
        if DemoMode.isOn {
            let picked = DemoMode.apps.filter { demoSelection.contains($0.name) }
            if picked.isEmpty {
                emptyRow
            }
            ForEach(picked, id: \.name) { app in
                Label(app.name, systemImage: app.icon)
            }
        } else {
            if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty {
                emptyRow
            }
            ForEach(Array(selection.applicationTokens), id: \.self) { token in
                Label(token)
            }
            ForEach(Array(selection.categoryTokens), id: \.self) { token in
                Label(token)
            }
            ForEach(Array(selection.webDomainTokens), id: \.self) { token in
                Label(token)
            }
        }
    }

    private var emptyRow: some View {
        Text("No apps chosen yet")
            .foregroundStyle(.secondary)
    }
}

#Preview {
    Form {
        Section("Blocked apps") {
            BlockedAppsList(selection: FamilyActivitySelection(), demoSelection: ["Instagram", "TikTok", "Reddit"])
        }
    }
}
