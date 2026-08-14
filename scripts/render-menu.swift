import AppKit
import SwiftUI

@main
struct WakeBarMenuRenderer {
    @MainActor
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write(Data("Usage: render-menu OUTPUT.png\n".utf8))
            exit(2)
        }

        let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let session = SessionController(startupOptions: StartupOptions())
        let launchAtLogin = LaunchAtLoginController()
        let rootView = WakeBarMenu(
            session: session,
            launchAtLogin: launchAtLogin
        )
        .preferredColorScheme(.light)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 560)
        hostingView.layoutSubtreeIfNeeded()

        let fittingHeight = max(500, ceil(hostingView.fittingSize.height))
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: fittingHeight)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .windowBackgroundColor
        window.contentView = hostingView
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw RenderError.couldNotCreateBitmap
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.couldNotEncodePNG
        }
        try png.write(to: outputURL, options: .atomic)
    }
}

private enum RenderError: Error {
    case couldNotCreateBitmap
    case couldNotEncodePNG
}
