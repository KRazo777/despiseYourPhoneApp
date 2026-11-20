import SwiftUI

/// Big card at the top of the home screen: is anything blocking right now, and which groups.
struct StatusCard: View {
    let groups: [BlockGroup]

    var body: some View {
        TimelineView(.everyMinute) { context in
            let blocking: [BlockGroup] = groups.filter { GroupStore.isBlocking($0, at: context.date) }

            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: blocking.isEmpty ? "lock.open" : "lock.fill")
                    .font(.system(size: 32, weight: .semibold))
                Text(blocking.isEmpty ? "Blocking is off" : "Blocking is on")
                    .font(.title.bold())
                Text(detail(blocking: blocking))
                    .font(.subheadline)
                    .opacity(0.85)
            }
            // Dark text, since white is hard to read on the light green.
            .foregroundStyle(blocking.isEmpty ? AnyShapeStyle(.primary) : AnyShapeStyle(.black))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                blocking.isEmpty ? AnyShapeStyle(.background) : AnyShapeStyle(Color.appAccent),
                in: RoundedRectangle(cornerRadius: 20)
            )
        }
    }

    private func detail(blocking: [BlockGroup]) -> String {
        if !blocking.isEmpty {
            return blocking.map(\.name).formatted(.list(type: .and))
        }
        return groups.isEmpty ? "Make a group of apps to get started" : "No groups are blocking right now"
    }
}

#Preview("On") {
    StatusCard(groups: BlockGroup.samples)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Off") {
    StatusCard(groups: [])
        .padding()
        .background(Color(.systemGroupedBackground))
}
