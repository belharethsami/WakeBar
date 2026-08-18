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

expect(
    DisplaySleepCommand.executableURL.path == "/usr/bin/pmset",
    "Display sleep should use Apple's fixed pmset executable"
)
expect(
    DisplaySleepCommand.arguments == ["displaysleepnow"],
    "Display sleep should use the non-persistent displaysleepnow action"
)

var clamshellTransitions = ClamshellTransitionDetector()
expect(
    !clamshellTransitions.consume(isClosed: false),
    "An initially open lid should not request display sleep"
)
expect(
    clamshellTransitions.consume(isClosed: true),
    "Closing the lid should request display sleep"
)
expect(
    !clamshellTransitions.consume(isClosed: true),
    "A closed lid should not repeatedly request display sleep"
)
expect(
    !clamshellTransitions.consume(isClosed: false),
    "Reopening the lid should rearm the transition detector"
)
expect(
    clamshellTransitions.consume(isClosed: true),
    "Closing the lid again should request display sleep again"
)

let options = StartupOptions.parse([
    "--start-for", "12.5",
    "--keep-display-awake",
    "--closed-lid",
    "--quit-after-session"
])
expect(options.shouldStart, "--start-for should enable auto-start")
expect(options.duration == 12.5, "--start-for should parse fractional seconds")
expect(options.keepsDisplayAwake, "Display option should be parsed")
expect(options.usesClosedLidMode, "Closed-lid option should be parsed")
expect(options.quitsAfterSession, "Quit option should be parsed")

expect(
    SessionDurationPreset.standard.map(\.seconds)
        == [900, 1_800, 3_600, 7_200, 10_800, 14_400, 21_600, 36_000, 43_200],
    "Standard presets should include 15 and 30 minutes plus 1, 2, 3, 4, 6, 10, and 12 hours"
)
expect(
    SessionDurationPreset.standard.map(\.title)
        == ["15 min", "30 min", "1 hr", "2 hr", "3 hr", "4 hr", "6 hr", "10 hr", "12 hr"],
    "Preset labels should remain compact and ordered by duration"
)

let invalidOptions = StartupOptions.parse(["--start-for", "not-a-number"])
expect(!invalidOptions.shouldStart, "Invalid durations should not start a session")
expect(invalidOptions.duration == nil, "Invalid durations should stay nil")

expect(
    ClosedLidSupport.isValidAccountName("samibelhareth"),
    "Normal macOS account names should be accepted"
)
expect(
    !ClosedLidSupport.isValidAccountName("unsafe user"),
    "Whitespace must not be accepted in privileged configuration input"
)
expect(
    !ClosedLidSupport.isValidAccountName("user;touch-pwned"),
    "Shell metacharacters must not be accepted in privileged configuration input"
)
expect(
    ClosedLidSupport.sudoersRule(for: "samibelhareth")
        == "samibelhareth ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1\n",
    "The sudoers grant must contain only the two exact pmset commands"
)
expect(
    ClosedLidSupport.sudoersRule(for: "unsafe user") == nil,
    "Invalid account names must not produce a sudoers rule"
)
let installCommand = ClosedLidSupport.authorizationInstallCommand(
    for: "samibelhareth",
    nonce: "1234-ABCD"
)
expect(installCommand != nil, "A valid account and nonce should produce an install command")
expect(
    installCommand?.contains("/usr/sbin/visudo -cf") == true,
    "The authorization installer must validate its sudoers file"
)
expect(
    installCommand?.contains("/bin/chmod 0440") == true,
    "The authorization installer must restrict sudoers file permissions"
)
expect(
    installCommand?.contains("samibelhareth ALL=") == false,
    "The account-specific rule should be encoded instead of interpolated into shell syntax"
)
expect(
    ClosedLidSupport.authorizationInstallCommand(
        for: "samibelhareth",
        nonce: "unsafe;command"
    ) == nil,
    "Unsafe installer nonces must be rejected"
)
expect(
    ClosedLidSupport.sudoArguments(enable: true)
        == ["-n", "/usr/bin/pmset", "-a", "disablesleep", "1"],
    "Closed-lid enable should use non-interactive sudo and the fixed pmset path"
)
expect(
    ClosedLidSupport.sudoArguments(enable: false)
        == ["-n", "/usr/bin/pmset", "-a", "disablesleep", "0"],
    "Closed-lid disable should use non-interactive sudo and the fixed pmset path"
)
expect(
    ClosedLidSupport.parseSleepDisabledState(from: #""SleepDisabled" = Yes"#) == .enabled,
    "IORegistry enabled state should be recognized"
)
expect(
    ClosedLidSupport.parseSleepDisabledState(from: #""SleepDisabled" = No"#) == .disabled,
    "IORegistry disabled state should be recognized"
)
expect(
    ClosedLidSupport.parseSleepDisabledState(from: "unrelated output") == .unknown,
    "Missing system state should not be guessed"
)
expect(
    ClosedLidSupport.parseBatteryStatus(
        from: "Now drawing from 'Battery Power'\n -InternalBattery-0 92%; discharging"
    ) == BatteryStatus(percentage: 92, isOnACPower: false),
    "Battery status should identify a discharging percentage"
)
expect(
    ClosedLidSupport.parseBatteryStatus(
        from: "Now drawing from 'AC Power'\n -InternalBattery-0 100%; charged"
    ) == BatteryStatus(percentage: 100, isOnACPower: true),
    "Battery status should identify external power"
)
let testHome = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
expect(
    ClosedLidSupport.ownershipMarkerURL(homeDirectory: testHome).path
        == "/Users/tester/Library/Application Support/WakeBar/closed-lid-owned",
    "The watchdog ownership marker should use the user's Application Support directory"
)
expect(
    ClosedLidSupport.heartbeatURL(homeDirectory: testHome).path
        == "/Users/tester/Library/Application Support/WakeBar/closed-lid-heartbeat",
    "The watchdog heartbeat should use the user's Application Support directory"
)

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
