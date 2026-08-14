import Foundation

public struct StartupOptions: Equatable {
    public var shouldStart = false
    public var duration: TimeInterval?
    public var keepsDisplayAwake = false
    public var quitsAfterSession = false

    public init(
        shouldStart: Bool = false,
        duration: TimeInterval? = nil,
        keepsDisplayAwake: Bool = false,
        quitsAfterSession: Bool = false
    ) {
        self.shouldStart = shouldStart
        self.duration = duration
        self.keepsDisplayAwake = keepsDisplayAwake
        self.quitsAfterSession = quitsAfterSession
    }

    public static var current: StartupOptions {
        parse(Array(CommandLine.arguments.dropFirst()))
    }

    public static func parse(_ arguments: [String]) -> StartupOptions {
        var options = StartupOptions()
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--start":
                options.shouldStart = true

            case "--start-for":
                if index + 1 < arguments.count,
                   let seconds = TimeInterval(arguments[index + 1]),
                   seconds > 0 {
                    options.shouldStart = true
                    options.duration = seconds
                    index += 1
                }

            case "--keep-display-awake":
                options.keepsDisplayAwake = true

            case "--quit-after-session":
                options.quitsAfterSession = true

            default:
                break
            }

            index += 1
        }

        return options
    }
}
