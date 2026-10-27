import SwiftUI
import FamilyControls

/// Rows for a group's apps, categories, and websites, with their real icons.
/// In demo mode it shows the sample apps instead.
struct BlockedAppsList: View {
    let group: BlockGroup

    var body: some View {
        if !group.hasApps {
            Text("No apps chosen yet")
                .foregroundStyle(.secondary)
        }
        if DemoMode.isOn {
            ForEach(DemoMode.apps.filter { group.demoApps.contains($0.name) }, id: \.name) { app in
                Label(app.name, systemImage: app.icon)
            }
        } else {
            ForEach(Array(group.selection.applicationTokens), id: \.self) { token in
                Label(token)
            }
            ForEach(Array(group.selection.categoryTokens), id: \.self) { token in
                Label(token)
            }
            ForEach(Array(group.selection.webDomainTokens), id: \.self) { token in
                Label(token)
            }
        }
    }
}

#Preview {
    Form {
        Section("Apps") {
            BlockedAppsList(group: BlockGroup.samples[0])
        }
    }
}
