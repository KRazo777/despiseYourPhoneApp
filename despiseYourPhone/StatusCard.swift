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
            // Dark text, since white is hard to read on the bright green.
            .foregroundStyle(blocking.isEmpty ? AnyShapeStyle(.primary) : AnyShapeStyle(.black))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                blocking.isEmpty ? AnyShapeStyle(.background) : AnyShapeStyle(Self.blockingGradient),
                in: RoundedRectangle(cornerRadius: 20)
            )
            // A faint highlight along the edge and a soft green glow make it feel glossy.
            .overlay {
                if !blocking.isEmpty {
                    RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.25), lineWidth: 1)
                }
            }
            .shadow(color: blocking.isEmpty ? .clear : Color.statusGreen.opacity(0.35), radius: 12, y: 6)
        }
    }

    /// Bright lime at the top left, deepening to emerald. Black text reads on every part of it.
    private static let blockingGradient = LinearGradient(
        colors: [Color(red: 0x7C / 255, green: 0xF2 / 255, blue: 0x7C / 255), .statusGreen, Color(red: 0x16 / 255, green: 0xA3 / 255, blue: 0x4A / 255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
