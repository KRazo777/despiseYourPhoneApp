import SwiftUI

/// The daily schedule toggle and its From / Until times.
struct ScheduleSection: View {
    @Binding var isOn: Bool
    @Binding var startMinutes: Int
    @Binding var endMinutes: Int

    var body: some View {
        Section {
            Toggle("Block on a schedule", isOn: $isOn)
            DatePicker("From", selection: ClockTime.binding($startMinutes), displayedComponents: .hourAndMinute)
            DatePicker("Until", selection: ClockTime.binding($endMinutes), displayedComponents: .hourAndMinute)
        } header: {
            Text("Daily schedule")
        } footer: {
            Text("Repeats every day, even when the app is closed. iOS needs the window to be at least 15 minutes.")
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

    static func components(_ minutes: Int) -> DateComponents {
        DateComponents(hour: minutes / 60, minute: minutes % 60)
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
        ScheduleSection(isOn: .constant(true), startMinutes: .constant(22 * 60), endMinutes: .constant(7 * 60))
    }
}
