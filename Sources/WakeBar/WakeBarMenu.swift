import AppKit
import SwiftUI

private struct DurationPreset: Identifiable {
    let id = UUID()
    let title: String
    let seconds: TimeInterval
}

struct WakeBarMenu: View {
    @ObservedObject var session: SessionController
    @ObservedObject var launchAtLogin: LaunchAtLoginController

    @State private var selectedEndTime = Date().addingTimeInterval(60 * 60)

    private let presets = [
        DurationPreset(title: "15 min", seconds: 15 * 60),
        DurationPreset(title: "30 min", seconds: 30 * 60),
        DurationPreset(title: "1 hour", seconds: 60 * 60),
        DurationPreset(title: "2 hours", seconds: 2 * 60 * 60)
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusHeader

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("START A SESSION")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(presets) { preset in
                        Button(preset.title) {
                            session.start(for: preset.seconds)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Button("Indefinitely") {
                    session.start(for: nil)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 8) {
                    DatePicker(
                        "Until",
                        selection: $selectedEndTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()

                    Button("Start until this time") {
                        session.start(until: selectedEndTime)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)

            Toggle(
                "Keep the display awake too",
                isOn: Binding(
                    get: { session.keepsDisplayAwake },
                    set: { session.setKeepsDisplayAwake($0) }
                )
            )

            if session.isActive {
                Button("End Session", role: .destructive) {
                    session.stop()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .frame(maxWidth: .infinity)
            }

            Divider()

            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            )

            if launchAtLogin.requiresApproval {
                Label(
                    "Approve WakeBar in System Settings → General → Login Items.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            if let error = session.lastError ?? launchAtLogin.lastError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text("WakeBar uses macOS caffeinate. No network, no tracking.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button("Quit") {
                    session.stop()
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            launchAtLogin.refresh()
        }
    }

    private var statusHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(session.isActive ? Color.green.opacity(0.16) : Color.secondary.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: session.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(session.isActive ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("WakeBar")
                    .font(.headline)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(session.statusText(at: context.date))
                        .font(.subheadline)
                        .foregroundStyle(session.isActive ? .primary : .secondary)
                        .monospacedDigit()
                }
            }

            Spacer()

            Circle()
                .fill(session.isActive ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 8, height: 8)
                .accessibilityLabel(session.isActive ? "Active" : "Inactive")
        }
    }
}
