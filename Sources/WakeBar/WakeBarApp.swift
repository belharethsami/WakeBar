import SwiftUI

@MainActor
final class WakeBarApplicationDelegate: NSObject, NSApplicationDelegate {
    static weak var sessionController: SessionController?

    func applicationWillTerminate(_ notification: Notification) {
        Self.sessionController?.shutdownBeforeTermination()
    }
}

@main
struct WakeBarApp: App {
    @NSApplicationDelegateAdaptor(WakeBarApplicationDelegate.self) private var appDelegate
    @StateObject private var session: SessionController
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    init() {
        let sessionController = SessionController()
        _session = StateObject(wrappedValue: sessionController)
        WakeBarApplicationDelegate.sessionController = sessionController
    }

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
