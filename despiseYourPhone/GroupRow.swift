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
                    .foregroundStyle(blocking ? AnyShapeStyle(Color.indigo) : AnyShapeStyle(.secondary))
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
        if let until = TempUnlock.unlockedUntil(group.id), date < until {
            return "Unlocked until \(until.formatted(date: .omitted, time: .shortened))"
        }
        if !group.usesSchedule {
            return "Blocking all day"
        }
        return group.isScheduledToBlock(at: date)
            ? "Blocking until \(ClockTime.text(group.endMinutes))"
            : "Starts at \(ClockTime.text(group.startMinutes))"
    }
}

#Preview {
    List {
        ForEach(BlockGroup.samples) { group in
            GroupRow(group: group)
        }
    }
}
