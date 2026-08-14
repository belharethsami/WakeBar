import Foundation

public struct SessionDurationPreset: Identifiable, Equatable, Sendable {
    public let title: String
    public let seconds: TimeInterval

    public var id: TimeInterval { seconds }

    public init(title: String, seconds: TimeInterval) {
        self.title = title
        self.seconds = seconds
    }

    public static let standard: [SessionDurationPreset] = [
        SessionDurationPreset(title: "15 min", seconds: 15 * 60),
        SessionDurationPreset(title: "30 min", seconds: 30 * 60),
        SessionDurationPreset(title: "1 hr", seconds: 60 * 60),
        SessionDurationPreset(title: "2 hr", seconds: 2 * 60 * 60),
        SessionDurationPreset(title: "3 hr", seconds: 3 * 60 * 60),
        SessionDurationPreset(title: "4 hr", seconds: 4 * 60 * 60),
        SessionDurationPreset(title: "6 hr", seconds: 6 * 60 * 60),
        SessionDurationPreset(title: "10 hr", seconds: 10 * 60 * 60)
    ]
}
