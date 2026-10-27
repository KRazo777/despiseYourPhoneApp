import SwiftUI

/// One group's status, apps, and rules, with buttons to turn it off, edit, or delete it.
struct GroupDetailView: View {
    @Binding var groups: [BlockGroup]
    let id: UUID

    @State private var editing: BlockGroup?
    @State private var showingShieldPreview = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let index = groups.firstIndex(where: { $0.id == id }) {
            content(group: groups[index], index: index)
        } else {
            ContentUnavailableView("Group deleted", systemImage: "trash")
        }
    }

    private func content(group: BlockGroup, index: Int) -> some View {
        List {
            Section {
                TimelineView(.everyMinute) { context in
                    let blocking = GroupStore.isBlocking(group, at: context.date)
                    Label(GroupStatus.text(for: group, at: context.date), systemImage: blocking ? "lock.fill" : "lock.open")
                        .font(.headline)
                        .foregroundStyle(blocking ? AnyShapeStyle(Color.indigo) : AnyShapeStyle(.primary))
                }
            }

            Section("Apps") {
                BlockedAppsList(group: group)
            }

            Section("Rules") {
                LabeledContent("When", value: group.usesSchedule
                    ? "\(ClockTime.text(group.startMinutes)) – \(ClockTime.text(group.endMinutes))"
                    : "All day")
                LabeledContent("Opens", value: group.opensPerDay.map { "\($0) a day, \(group.unlockMinutes) min each" }
                    ?? "No limit, \(group.unlockMinutes) min each")
                if let left = TempUnlock.opensLeft(group) {
                    LabeledContent("Opens left today", value: "\(left)")
                }
            }

            if DemoMode.isOn {
                Section {
                    Button("Preview block screen") { showingShieldPreview = true }
                }
            }

            Section {
                Button(group.isOn ? "Turn off" : "Turn on") { groups[index].isOn.toggle() }
                Button("Edit group") { editing = group }
                Button("Delete group", role: .destructive) { delete() }
            }
        }
        .navigationTitle(group.name)
        .sheet(item: $editing) { draft in
            GroupEditorView(group: draft, isNew: false) { saved in
                if let index = groups.firstIndex(where: { $0.id == saved.id }) {
                    groups[index] = saved
                }
            }
        }
        .fullScreenCover(isPresented: $showingShieldPreview) {
            ShieldPreview(appName: group.demoApps.first ?? "Instagram", group: group)
        }
    }

    private func delete() {
        dismiss()
        groups.removeAll { $0.id == id }
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(groups: .constant(BlockGroup.samples), id: BlockGroup.samples[0].id)
    }
}
