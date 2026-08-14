import Foundation

public struct CaffeinateCommand: Equatable {
    public static let executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")

    public let arguments: [String]

    public init(
        duration: TimeInterval?,
        keepsDisplayAwake: Bool,
        parentProcessIdentifier: Int32
    ) {
        var arguments = ["-i"]

        if keepsDisplayAwake {
            arguments.append("-d")
        }

        // The timeout is a second line of defense if the UI becomes
        // unresponsive. Watching the parent prevents orphaned assertions.
        if let duration {
            arguments.append(contentsOf: ["-t", String(max(1, Int(ceil(duration))))])
        }

        arguments.append(contentsOf: ["-w", String(parentProcessIdentifier)])
        self.arguments = arguments
    }
}
