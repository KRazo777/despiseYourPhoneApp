import SwiftUI

/// Stands between you and turning off, editing, or deleting a group:
/// a countdown, then a sentence you have to type exactly.
struct TurnOffGate: View {
    static let waitSeconds = 30
    static let phrase = "I despise my phone"

    let title: String
    let onConfirm: () -> Void

    @State private var startedAt = Date.now
    @State private var typed = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "hourglass")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("This group is protecting your time. Wait, then type the sentence below to continue.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    let secondsLeft = max(0, Self.waitSeconds - Int(context.date.timeIntervalSince(startedAt)))
                    if secondsLeft > 0 {
                        VStack(spacing: 4) {
                            Text("\(secondsLeft)")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("seconds")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type \u{201C}\(Self.phrase)\u{201D}")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField(Self.phrase, text: $typed)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                    }
                }
                .padding(.top, 8)

                Spacer()

                Button {
                    onConfirm()
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(typed.trimmingCharacters(in: .whitespaces) != Self.phrase)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    TurnOffGate(title: "Turn off Social?") {}
}
