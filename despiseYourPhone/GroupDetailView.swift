import SwiftUI

/// One group's status, apps, and rules, with buttons to edit, turn off, or delete it.
/// While the group is on, turning it off or deleting it goes through TurnOffGate.
/// In strict mode all three are disabled.
struct GroupDetailView: View {
    @Binding var groups: [BlockGroup]
    let id: UUID

    @State private var editing: BlockGroup?
    @State private var showingShieldPreview = false
    /// The action waiting behind the gate, and the one the gate let through.
    @State private var gatedAction: ProtectedAction?
    @State private var confirmedAction: ProtectedAction?
    @State private var strictChoice: Date?
    @Environment(\.dismiss) private var dismiss

    enum ProtectedAction: String, Identifiable {
        case turnOff, delete
        var id: String { rawValue }

        func gateTitle(for name: String) -> String {
            switch self {
            case .turnOff: "Turn off \(name)?"
            case .delete: "Delete \(name)?"
            }
        }
    }

    var body: some View {
        if let index = groups.firstIndex(where: { $0.id == id }) {
            content(group: groups[index], index: index)
        } else {
            ContentUnavailableView("Group deleted", systemImage: "trash")
        }
    }

    private func content(group: BlockGroup, index: Int) -> some View {
        let strict = group.isStrict(at: .now)
        return List {
            Section {
                TimelineView(.everyMinute) { context in
                    let blocking = GroupStore.isBlocking(group, at: context.date)
                    Label(GroupStatus.text(for: group, at: context.date), systemImage: blocking ? "lock.fill" : "lock.open")
                        .font(.headline)
                        .foregroundStyle(blocking ? AnyShapeStyle(Color.indigo) : AnyShapeStyle(.primary))
                }
            }

            Section("Blocked Apps") {
                BlockedAppsList(group: group)
            }

            Section("Rules") {
                LabeledContent("When", value: group.usesSchedule
                    ? "\(ClockTime.text(group.startMinutes)) – \(ClockTime.text(group.endMinutes))"
                    : "All day")
                LabeledContent("Opens", value: group.opensPerDay.map { "\($0) / Day" } ?? "No limit")
                LabeledContent("Open duration", value: "\(group.unlockMinutes) min")
                LabeledContent("Open delay", value: group.openDelay == 0 ? "None" : "\(group.openDelay) sec")
            }

            Section {
                Button("Edit group") { editing = group }
                    .disabled(strict)
            }

            Section {
                if strict, let until = group.strictUntil {
                    Label("On until \(GroupStatus.timeText(until))", systemImage: "lock.shield.fill")
                        .foregroundStyle(.indigo)
                } else {
                    Menu {
                        Button("For 1 hour") { strictChoice = .now.addingTimeInterval(3600) }
                        Button("For 4 hours") { strictChoice = .now.addingTimeInterval(4 * 3600) }
                        Button("Until 8 AM") {
                            strictChoice = Calendar.current.nextDate(after: .now, matching: DateComponents(hour: 8), matchingPolicy: .nextTime)
                        }
                        Button("For 24 hours") { strictChoice = .now.addingTimeInterval(24 * 3600) }
                    } label: {
                        Label("Turn on strict mode", systemImage: "lock.shield")
                    }
                    .disabled(!group.isOn)
                }
            } header: {
                Text("Strict mode")
            } footer: {
                Text("No turning off, editing, or deleting this group, until time runs out. Daily opens still work.")
            }

            if DemoMode.isOn {
                Section {
                    Button("Preview block screen") { showingShieldPreview = true }
                }
            }

            Section {
                if group.isOn {
                    Button("Turn off blocking") { protect(.turnOff, group: group) }
                } else {
                    Button("Turn on blocking") { groups[index].isOn = true }
                }
                Button("Delete group", role: .destructive) { protect(.delete, group: group) }
            } footer: {
                if strict {
                    Text("Strict mode is on, so this group can't be changed right now.")
                } else if group.isOn {
                    Text("Turning off or deleting this group takes a \(TurnOffGate.waitSeconds)-second wait and a typed promise.")
                }
            }
            .disabled(strict)
        }
        .navigationTitle(group.name)
        .sheet(item: $gatedAction, onDismiss: runConfirmedAction) { action in
            TurnOffGate(title: action.gateTitle(for: group.name)) {
                confirmedAction = action
            }
        }
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
        .alert("Turn on strict mode?", isPresented: Binding(get: { strictChoice != nil }, set: { if !$0 { strictChoice = nil } })) {
            Button("Turn on", role: .destructive) {
                groups[index].strictUntil = strictChoice
                strictChoice = nil
            }
            Button("Cancel", role: .cancel) { strictChoice = nil }
        } message: {
            Text("You won't be able to turn off, edit, or delete \(group.name) until \(strictChoice.map(GroupStatus.timeText) ?? "then").")
        }
    }

    /// Off groups aren't protecting anything, so they skip the gate.
    private func protect(_ action: ProtectedAction, group: BlockGroup) {
        if group.isOn {
            gatedAction = action
        } else {
            perform(action)
        }
    }

    /// Runs after the gate sheet closes, so the screen can dismiss cleanly.
    private func runConfirmedAction() {
        guard let action = confirmedAction else { return }
        confirmedAction = nil
        perform(action)
    }

    private func perform(_ action: ProtectedAction) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        switch action {
        case .turnOff:
            groups[index].isOn = false
        case .delete:
            dismiss()
            groups.remove(at: index)
        }
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(groups: .constant(BlockGroup.samples), id: BlockGroup.samples[0].id)
    }
}
