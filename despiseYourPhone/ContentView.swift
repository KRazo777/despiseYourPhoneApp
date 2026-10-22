import SwiftUI
import FamilyControls

struct ContentView: View {
    @State private var authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    @State private var selection = BlockStore.loadSelection()
    @State private var showingPicker = false
    @State private var blockingNow = false

    @AppStorage("scheduleOn", store: AppGroup.defaults) private var scheduleOn = false
    @State private var startTime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: .now)!
    @State private var endTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now)!

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
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
                                on ? BlockStore.applyShield() : BlockStore.clearShield()
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
            .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
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
