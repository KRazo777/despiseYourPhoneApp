import SwiftUI
import FamilyControls

/// Create or edit a group: name, apps, and when it blocks.
struct GroupEditorView: View {
    @State private var group: BlockGroup
    let isNew: Bool
    let onSave: (BlockGroup) -> Void

    @State private var showingPicker = false
    @Environment(\.dismiss) private var dismiss

    init(group: BlockGroup, isNew: Bool, onSave: @escaping (BlockGroup) -> Void) {
        _group = State(initialValue: group)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Social media", text: $group.name)
                }

                Section("Apps") {
                    BlockedAppsList(group: group)
                    Button(group.hasApps ? "Edit apps" : "Choose apps") { showingPicker = true }
                }

                ScheduleSection(group: $group)

                Section {
                    Stepper("Let me in: \(group.unlockMinutes) min", value: $group.unlockMinutes, in: 1...60)
                } footer: {
                    Text("How long the block screen's Let me in button unlocks this group for.")
                }
            }
            .navigationTitle(isNew ? "New group" : "Edit group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        group.name = group.name.trimmingCharacters(in: .whitespaces)
                        onSave(group)
                        dismiss()
                    }
                    .disabled(group.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .familyActivityPicker(isPresented: DemoMode.isOn ? .constant(false) : $showingPicker, selection: $group.selection)
            .sheet(isPresented: DemoMode.isOn ? $showingPicker : .constant(false)) {
                DemoAppPicker(selected: demoApps)
            }
        }
    }

    /// The demo picker works with a set; the group keeps the apps in picker order.
    private var demoApps: Binding<Set<String>> {
        Binding(
            get: { Set(group.demoApps) },
            set: { picked in group.demoApps = DemoMode.apps.map(\.name).filter(picked.contains) }
        )
    }
}

#Preview {
    GroupEditorView(group: BlockGroup.samples[1], isNew: false) { _ in }
}
