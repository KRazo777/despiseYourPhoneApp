import SwiftUI

/// One group on the home screen: name, lock icon, and what it's doing right now.
struct GroupRow: View {
    let group: BlockGroup

    var body: some View {
        TimelineView(.everyMinute) { context in
            let blocking = GroupStore.isBlocking(group, at: context.date)
            HStack(spacing: 14) {
                Image(systemName: blocking ? "lock.fill" : "lock.open")
                    .font(.title3)
                    .foregroundStyle(blocking ? AnyShapeStyle(Color.appAccent) : AnyShapeStyle(.secondary))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.headline)
                    Text(GroupStatus.text(for: group, at: context.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// A short line describing what a group is doing at a given time.
enum GroupStatus {
    static func text(for group: BlockGroup, at date: Date) -> String {
        guard group.isOn else { return "Off" }
        if let until = TempUnlock.activeUnlocks(group.id, now: date)[ShieldTarget.group.key] {
            return "Unlocked until \(until.formatted(date: .omitted, time: .shortened))"
        }
        guard group.isScheduledToBlock(at: date) else {
            return "Starts at \(ClockTime.text(group.startMinutes))"
        }
        var parts = [group.usesSchedule ? "Blocking until \(ClockTime.text(group.endMinutes))" : "Blocking all day"]
        let unlockedApps = TempUnlock.activeUnlocks(group.id, now: date).count
        if unlockedApps > 0 {
            parts.append("\(unlockedApps) unlocked")
        }
        if group.isStrict(at: date) {
            parts.append("Strict")
        }
        return parts.joined(separator: " · ")
    }

    /// A time, with the day added when it isn't today.
    static func timeText(_ date: Date) -> String {
        date.formatted(date: Calendar.current.isDateInToday(date) ? .omitted : .abbreviated, time: .shortened)
    }
}

#Preview {
    List {
        ForEach(BlockGroup.samples) { group in
            GroupRow(group: group)
        }
    }
}
