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
            .foregroundStyle(blocking.isEmpty ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
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
            .shadow(color: blocking.isEmpty ? .clear : Self.blockingBlue.opacity(0.35), radius: 12, y: 6)
        }
    }

    /// The accent blue, fixed so it doesn't lighten in dark mode.
    private static let blockingBlue = Color(red: 0x00 / 255, green: 0x41 / 255, blue: 0xC2 / 255)

    /// Bright blue at the top left, deepening to navy. White text reads on every part of it.
    private static let blockingGradient = LinearGradient(
        colors: [Color(red: 0x2F / 255, green: 0x66 / 255, blue: 0xDB / 255), blockingBlue, Color(red: 0x00 / 255, green: 0x2B / 255, blue: 0x87 / 255)],
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
