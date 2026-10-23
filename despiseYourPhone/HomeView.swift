import SwiftUI
import FamilyControls

/// Main screen: blocking status, chosen apps, Block now, and the daily schedule.
struct HomeView: View {
    @State private var authorized = ScreenTimeAccess.isApproved
    @State private var selection = BlockStore.loadSelection()
    @State private var showingPicker = false

    @State private var demoSelection: Set<String>
    @State private var showingShieldPreview = false

    @AppStorage(AppGroup.Key.blockNow, store: AppGroup.defaults) private var blockNow = false
    @AppStorage(AppGroup.Key.scheduleOn, store: AppGroup.defaults) private var scheduleOn = false
    @AppStorage(AppGroup.Key.scheduleStart, store: AppGroup.defaults) private var startMinutes = 22 * 60
    @AppStorage(AppGroup.Key.scheduleEnd, store: AppGroup.defaults) private var endMinutes = 7 * 60

    @State private var errorMessage: String?

    init(demoSelection: Set<String> = []) {
        _demoSelection = State(initialValue: demoSelection)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    StatusCard(blockNow: blockNow, scheduleOn: scheduleOn, startMinutes: startMinutes, endMinutes: endMinutes)
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

                Section("Blocked apps") {
                    BlockedAppsList(selection: selection, demoSelection: demoSelection)
                    Button(hasSelection ? "Edit apps" : "Choose apps") { showingPicker = true }
                }

                Section {
                    Toggle("Block now", isOn: $blockNow)
                    if DemoMode.isOn {
                        Button("Preview block screen") { showingShieldPreview = true }
                    }
                } footer: {
                    Text("Blocks your apps until you turn it off.")
                }

                ScheduleSection(isOn: $scheduleOn, startMinutes: $startMinutes, endMinutes: $endMinutes)
            }
            .navigationTitle("DespiseYourPhone")
            .familyActivityPicker(isPresented: DemoMode.isOn ? .constant(false) : $showingPicker, selection: $selection)
            .sheet(isPresented: DemoMode.isOn ? $showingPicker : .constant(false)) {
                DemoAppPicker(selected: $demoSelection)
            }
            .fullScreenCover(isPresented: $showingShieldPreview) {
                ShieldPreview(appName: DemoMode.apps.map(\.name).first(where: demoSelection.contains) ?? "Instagram")
            }
            .onChange(of: selection) { _, newValue in
                BlockStore.saveSelection(newValue)
                refreshShield()
            }
            .onChange(of: blockNow) { refreshShield() }
            .onChange(of: scheduleOn) { _, on in updateSchedule(on) }
            .onChange(of: startMinutes) { if scheduleOn { updateSchedule(true) } }
            .onChange(of: endMinutes) { if scheduleOn { updateSchedule(true) } }
            .alert("Something went wrong", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var hasSelection: Bool {
        if DemoMode.isOn { return !demoSelection.isEmpty }
        return !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    private func refreshShield() {
        guard !DemoMode.isOn else { return }
        BlockStore.refreshShield()
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

    private func updateSchedule(_ on: Bool) {
        guard !DemoMode.isOn else { return }
        guard on else {
            ScheduleManager.stopDailySchedule()
            BlockStore.refreshShield()
            return
        }
        do {
            try ScheduleManager.startDailySchedule(
                from: ClockTime.components(startMinutes),
                to: ClockTime.components(endMinutes)
            )
            BlockStore.refreshShield()
        } catch {
            errorMessage = error.localizedDescription
            scheduleOn = false
        }
    }
}

#Preview {
    HomeView(demoSelection: ["Instagram", "TikTok"])
}
