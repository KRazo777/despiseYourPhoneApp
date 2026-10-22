import SwiftUI
import FamilyControls

struct ContentView: View {
    @State private var authorized = DemoMode.isOn || AuthorizationCenter.shared.authorizationStatus == .approved
    @State private var selection = BlockStore.loadSelection()
    @State private var showingPicker = false
    @State private var blockingNow = false

    @State private var demoSelection: Set<String> = []
    @State private var showingShieldPreview = false

    @AppStorage("scheduleOn", store: AppGroup.defaults) private var scheduleOn = false
    @State private var startTime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: .now)!
    @State private var endTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now)!

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
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
                } else {
                    Section("Apps to block") {
                        Button("Choose apps") { showingPicker = true }
                        Text(summary)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Toggle("Block now", isOn: $blockingNow)
                            .onChange(of: blockingNow) { _, on in
                                guard !DemoMode.isOn else { return }
                                on ? BlockStore.applyShield() : BlockStore.clearShield()
                            }
                        if DemoMode.isOn {
                            Button("Preview block screen") { showingShieldPreview = true }
                        }
                    }

                    Section("Daily schedule") {
                        DatePicker("From", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("Until", selection: $endTime, displayedComponents: .hourAndMinute)
                        Toggle("Block on this schedule", isOn: $scheduleOn)
                            .onChange(of: scheduleOn) { _, on in updateSchedule(on) }
                    }
                }
            }
            .navigationTitle("despiseYourPhone")
            .familyActivityPicker(isPresented: DemoMode.isOn ? .constant(false) : $showingPicker, selection: $selection)
            .sheet(isPresented: DemoMode.isOn ? $showingPicker : .constant(false)) {
                DemoAppPicker(selected: $demoSelection)
            }
            .fullScreenCover(isPresented: $showingShieldPreview) {
                ShieldPreview(appName: DemoMode.apps.map(\.name).first(where: demoSelection.contains) ?? "Instagram")
            }
            .onChange(of: selection) { _, newValue in
                BlockStore.saveSelection(newValue)
                if blockingNow { BlockStore.applyShield() }
            }
            .alert("Something went wrong", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var summary: String {
        if DemoMode.isOn {
            let picked = DemoMode.apps.map(\.name).filter(demoSelection.contains)
            return picked.isEmpty ? "No apps chosen" : picked.joined(separator: ", ")
        }
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count
        let sites = selection.webDomainTokens.count
        return "\(apps) apps, \(categories) categories, \(sites) websites"
    }

    private func requestAuthorization() {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                authorized = AuthorizationCenter.shared.authorizationStatus == .approved
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func updateSchedule(_ on: Bool) {
        guard !DemoMode.isOn else { return }
        guard on else {
            ScheduleManager.stopDailySchedule()
            BlockStore.clearShield()
            return
        }
        let calendar = Calendar.current
        do {
            try ScheduleManager.startDailySchedule(
                from: calendar.dateComponents([.hour, .minute], from: startTime),
                to: calendar.dateComponents([.hour, .minute], from: endTime)
            )
        } catch {
            errorMessage = error.localizedDescription
            scheduleOn = false
        }
    }
}
