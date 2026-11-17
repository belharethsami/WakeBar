import SwiftUI

struct ClosedLidSection: View {
    @ObservedObject var controller: ClosedLidController
    let sessionIsActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Label("Closed-Lid Mode", systemImage: "laptopcomputer")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if controller.isActive {
                    Text("ACTIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
            }

            if controller.helperInstalled {
                Toggle(
                    "Keep running when the lid closes",
                    isOn: Binding(
                        get: { controller.isRequested },
                        set: { controller.setRequested($0) }
                    )
                )
                .disabled(sessionIsActive)

                Label(
                    controller.statusText,
                    systemImage: controller.isActive ? "checkmark.shield.fill" : "shield"
                )
                .font(.caption)
                .foregroundStyle(controller.isActive ? .green : .secondary)

                HStack(spacing: 8) {
                    if let percentage = controller.batteryStatus.percentage {
                        Label("\(percentage)%", systemImage: "battery.50percent")
                    }

                    Text(controller.batteryStatus.isOnACPower ? "Power adapter" : "Battery")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Text("Safety cutoff: \(ClosedLidController.batteryFloor)% battery when unplugged. Low Power Mode is supported. Never place an awake, closed Mac in a bag.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Remove Closed-Lid Support…", role: .destructive) {
                    controller.removeSupport()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .disabled(sessionIsActive)
            } else {
                Text("Requires one-time administrator approval. WakeBar receives permission only for the exact commands that enable and disable macOS's sleep override.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Install Closed-Lid Support…") {
                    controller.installSupport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(sessionIsActive)
            }

            if let error = controller.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
