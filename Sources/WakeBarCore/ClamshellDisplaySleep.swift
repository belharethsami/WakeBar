import Foundation

public enum DisplaySleepCommand {
    public static let executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    public static let arguments = ["displaysleepnow"]
}

public struct ClamshellTransitionDetector: Sendable {
    private var wasClosed: Bool?

    public init() {}

    public mutating func consume(isClosed: Bool) -> Bool {
        defer { wasClosed = isClosed }
        return isClosed && wasClosed != true
    }

    public mutating func reset() {
        wasClosed = nil
    }
}
