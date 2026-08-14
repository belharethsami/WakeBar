import Foundation
import WakeBarCore

private var failures = 0

@MainActor
private func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard condition() else {
        failures += 1
        FileHandle.standardError.write(Data("FAIL: \(message) [\(file):\(line)]\n".utf8))
        return
    }
}

private func makeDate(
    _ components: DateComponents,
    calendar: Calendar
) -> Date {
    guard let date = calendar.date(from: components) else {
        fatalError("Invalid test date: \(components)")
    }
    return date
}

let indefinite = CaffeinateCommand(
    duration: nil,
    keepsDisplayAwake: false,
    parentProcessIdentifier: 42
)
expect(
    indefinite.arguments == ["-i", "-w", "42"],
    "Indefinite sessions should prevent idle sleep and watch the parent"
)

let timedDisplay = CaffeinateCommand(
    duration: 90.2,
    keepsDisplayAwake: true,
    parentProcessIdentifier: 73
)
expect(
    timedDisplay.arguments == ["-i", "-d", "-t", "91", "-w", "73"],
    "Timed display sessions should add both the display assertion and rounded timeout"
)

let options = StartupOptions.parse([
    "--start-for", "12.5",
    "--keep-display-awake",
    "--quit-after-session"
])
expect(options.shouldStart, "--start-for should enable auto-start")
expect(options.duration == 12.5, "--start-for should parse fractional seconds")
expect(options.keepsDisplayAwake, "Display option should be parsed")
expect(options.quitsAfterSession, "Quit option should be parsed")

let invalidOptions = StartupOptions.parse(["--start-for", "not-a-number"])
expect(!invalidOptions.shouldStart, "Invalid durations should not start a session")
expect(invalidOptions.duration == nil, "Invalid durations should stay nil")

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!

let afternoon = makeDate(
    DateComponents(year: 2026, month: 8, day: 13, hour: 15, minute: 0),
    calendar: calendar
)
let laterTime = makeDate(
    DateComponents(year: 2026, month: 1, day: 1, hour: 17, minute: 30),
    calendar: calendar
)
let todayResult = SessionSchedule.nextOccurrence(
    of: laterTime,
    after: afternoon,
    calendar: calendar
)
expect(
    calendar.dateComponents([.year, .month, .day, .hour, .minute], from: todayResult)
        == DateComponents(year: 2026, month: 8, day: 13, hour: 17, minute: 30),
    "A future clock time should resolve to today"
)

let evening = makeDate(
    DateComponents(year: 2026, month: 8, day: 13, hour: 18, minute: 0),
    calendar: calendar
)
let tomorrowResult = SessionSchedule.nextOccurrence(
    of: laterTime,
    after: evening,
    calendar: calendar
)
expect(
    calendar.dateComponents([.year, .month, .day, .hour, .minute], from: tomorrowResult)
        == DateComponents(year: 2026, month: 8, day: 14, hour: 17, minute: 30),
    "A passed clock time should resolve to tomorrow"
)

if failures > 0 {
    FileHandle.standardError.write(Data("\(failures) logic test(s) failed.\n".utf8))
    exit(1)
}

print("All WakeBar logic tests passed.")
