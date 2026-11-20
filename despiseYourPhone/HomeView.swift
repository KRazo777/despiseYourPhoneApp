import SwiftUI
import FamilyControls

/// Main screen: overall blocking status and the list of block groups.
struct HomeView: View {
    @State private var groups: [BlockGroup]
    /// Observed because iOS reports the status as not determined for a moment at launch,
    /// then updates it.
    @ObservedObject private var authorization = AuthorizationCenter.shared
    /// False for the first moment after launch, while the status may not have loaded yet.
    @State private var statusSettled = false
    @State private var newGroup: BlockGroup?
    @State private var errorMessage: String?

    /// Pass `groups` to show sample data (previews). Otherwise the saved groups are loaded.
    init(groups: [BlockGroup]? = nil) {
        if groups == nil && !DemoMode.isOn {
            GroupStore.migrateIfNeeded()
            GroupStore.removeSharedApps()
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

                if needsAccess {
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
                GroupEditorView(group: draft, isNew: true, otherGroups: groups) { saved in
                    // Apps moved here leave their old groups.
                    groups = groups.map { $0.removingItems(of: saved) } + [saved]
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(1))
                statusSettled = true
            }
            .task {
                // Strict mode may have ended while the app was closed.
                if !DemoMode.isOn { GroupStore.updateAppRemovalLock(groups) }
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

    /// Hides the access button during the launch moment instead of flashing it.
    private var needsAccess: Bool {
        guard !ScreenTimeAccess.isApproved else { return false }
        return statusSettled || authorization.authorizationStatus != .notDetermined
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
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    HomeView(groups: BlockGroup.samples)
}
