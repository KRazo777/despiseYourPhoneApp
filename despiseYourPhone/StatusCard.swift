import SwiftUI

/// Big card at the top of the home screen: is blocking on right now, and until when.
struct StatusCard: View {
    let blockNow: Bool
    let scheduleOn: Bool
    let startMinutes: Int
    let endMinutes: Int

    var body: some View {
        TimelineView(.everyMinute) { context in
            let blocking = BlockStore.shouldBlock(
                blockNow: blockNow,
                scheduleOn: scheduleOn,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                at: context.date
            )

            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: blocking ? "lock.fill" : "lock.open")
                    .font(.system(size: 32, weight: .semibold))
                Text(blocking ? "Blocking is on" : "Blocking is off")
                    .font(.title.bold())
                Text(detail(blocking: blocking))
                    .font(.subheadline)
                    .opacity(0.85)
            }
            .foregroundStyle(blocking ? .white : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                blocking ? AnyShapeStyle(Color.indigo) : AnyShapeStyle(.background),
                in: RoundedRectangle(cornerRadius: 20)
            )
        }
    }

    private func detail(blocking: Bool) -> String {
        if blockNow {
            return "Until you turn off Block now"
        }
        if scheduleOn {
            return blocking
                ? "Until \(ClockTime.text(endMinutes))"
                : "Next block at \(ClockTime.text(startMinutes))"
        }
        return "Turn on Block now or set a schedule"
    }
}

#Preview("On") {
    StatusCard(blockNow: true, scheduleOn: false, startMinutes: 22 * 60, endMinutes: 7 * 60)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Off") {
    StatusCard(blockNow: false, scheduleOn: false, startMinutes: 22 * 60, endMinutes: 7 * 60)
        .padding()
        .background(Color(.systemGroupedBackground))
}
