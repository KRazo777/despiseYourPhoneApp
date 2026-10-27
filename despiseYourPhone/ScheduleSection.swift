import SwiftUI

/// "When to block": all day, or a daily window with From / Until times.
struct ScheduleSection: View {
    @Binding var group: BlockGroup

    var body: some View {
        Section {
            Picker("When", selection: $group.usesSchedule) {
                Text("All day").tag(false)
                Text("On a schedule").tag(true)
            }
            .pickerStyle(.segmented)

            if group.usesSchedule {
                DatePicker("From", selection: ClockTime.binding($group.startMinutes), displayedComponents: .hourAndMinute)
                DatePicker("Until", selection: ClockTime.binding($group.endMinutes), displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("When to block")
        } footer: {
            Text(group.usesSchedule
                ? "Repeats every day, even when the app is closed. iOS needs the window to be at least 15 minutes."
                : "Blocks all day, every day, until you turn the group off.")
        }
    }
}

/// Converts between "minutes after midnight" (what we store) and the Date a DatePicker wants.
enum ClockTime {
    static func date(_ minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
    }

    static func minutes(_ date: Date) -> Int {
        let time = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (time.hour ?? 0) * 60 + (time.minute ?? 0)
    }

    static func text(_ minutes: Int) -> String {
        date(minutes).formatted(date: .omitted, time: .shortened)
    }

    static func binding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { date(minutes.wrappedValue) },
            set: { minutes.wrappedValue = self.minutes($0) }
        )
    }
}

#Preview {
    Form {
        ScheduleSection(group: .constant(BlockGroup.samples[1]))
    }
}
