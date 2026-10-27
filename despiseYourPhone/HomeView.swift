import SwiftUI

/// Main screen: overall blocking status and the list of block groups.
struct HomeView: View {
    @State private var groups: [BlockGroup]
    @State private var authorized = ScreenTimeAccess.isApproved
    @State private var newGroup: BlockGroup?
    @State private var errorMessage: String?

    /// Pass `groups` to show sample data (previews). Otherwise the saved groups are loaded.
    init(groups: [BlockGroup]? = nil) {
        if groups == nil && !DemoMode.isOn {
            GroupStore.migrateIfNeeded()
        }
        _groups = State(initialValue: groups ?? GroupStore.load())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatusCard(groups: groups)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if DemoMode.isOn {
                    Section {
                        Label("Demo mode: nothing is actually blocked", systemImage: "theatermasks")
                            .foregroundStyle(.secondary)
                    }
                }

                if !authorized {
                    Section {
                        Button("Allow Screen Time access") { requestAuthorization() }
                    } footer: {
                        Text("Needed before this app can block anything.")
                    }
                }

                Section {
                    ForEach(groups) { group in
                        NavigationLink {
                            GroupDetailView(groups: $groups, id: group.id)
                        } label: {
                            GroupRow(group: group)
                        }
                    }
                    if groups.count < BlockGroup.maxCount {
                        Button {
                            newGroup = BlockGroup(name: "")
                        } label: {
                            Label("New group", systemImage: "plus")
                        }
                    }
                } header: {
                    Text("Block groups")
                } footer: {
                    Text("Each group has its own apps and its own rules.")
                }
            }
            .navigationTitle("DespiseYourPhone")
            .sheet(item: $newGroup) { draft in
                GroupEditorView(group: draft, isNew: true) { saved in
                    groups.append(saved)
                }
            }
            .onChange(of: groups) { old, new in
                let removed = old.filter { group in !new.contains { $0.id == group.id } }
                sync(removed: removed)
            }
            .alert("Something went wrong", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func sync(removed: [BlockGroup]) {
        guard !DemoMode.isOn else {
            GroupStore.save(groups)
            return
        }
        do {
            try GroupStore.sync(groups, removed: removed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestAuthorization() {
        Task {
            do {
                try await ScreenTimeAccess.request()
                authorized = ScreenTimeAccess.isApproved
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    HomeView(groups: BlockGroup.samples)
}
