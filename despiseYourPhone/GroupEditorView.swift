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
                    Toggle("Limit opens per day", isOn: limitsOpens)
                    if let opens = group.opensPerDay {
                        Stepper("\(opens) \(opens == 1 ? "open" : "opens") a day", value: opensPerDay, in: 0...20)
                    }
                    Picker("Open duration", selection: $group.unlockMinutes) {
                        ForEach(durationChoices, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    Picker("Open delay", selection: openDelay) {
                        ForEach(Self.delayChoices, id: \.self) { seconds in
                            Text(seconds == 0 ? "None" : "\(seconds) sec").tag(seconds)
                        }
                    }
                } header: {
                    Text("Opens")
                } footer: {
                    Text("Unlock on the block screen opens this group's apps for the open duration. With an open delay, you tap Unlock, wait, then tap again. Opens reset at midnight.")
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

    static let delayChoices = [0, 5, 10, 15, 30]
    private static let durationOptions = [1, 2, 5, 10, 15, 20, 30, 45, 60]

    /// The standard durations, plus the group's own if it was set to something else before.
    private var durationChoices: [Int] {
        Set(Self.durationOptions + [group.unlockMinutes]).sorted()
    }

    private var openDelay: Binding<Int> {
        Binding(
            get: { group.openDelay },
            set: { group.openDelaySeconds = $0 }
        )
    }

    private var limitsOpens: Binding<Bool> {
        Binding(
            get: { group.opensPerDay != nil },
            set: { group.opensPerDay = $0 ? 3 : nil }
        )
    }

    private var opensPerDay: Binding<Int> {
        Binding(
            get: { group.opensPerDay ?? 0 },
            set: { group.opensPerDay = $0 }
        )
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
    GroupEditorView(group: BlockGroup.samples[0], isNew: false) { _ in }
}
