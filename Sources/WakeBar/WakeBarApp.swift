import SwiftUI

@main
struct WakeBarApp: App {
    @StateObject private var session = SessionController()
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    var body: some Scene {
        MenuBarExtra {
            WakeBarMenu(
                session: session,
                launchAtLogin: launchAtLogin
            )
        } label: {
            Image(systemName: session.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .accessibilityLabel(session.isActive ? "WakeBar active" : "WakeBar inactive")
        }
        .menuBarExtraStyle(.window)
    }
}
