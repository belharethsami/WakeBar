import Foundation

public enum SleepDisabledState: Equatable, Sendable {
    case enabled
    case disabled
    case unknown
}

public struct BatteryStatus: Equatable, Sendable {
    public let percentage: Int?
    public let isOnACPower: Bool

    public init(percentage: Int?, isOnACPower: Bool) {
        self.percentage = percentage
        self.isOnACPower = isOnACPower
    }
}

public enum ClosedLidSupport {
    public static let pmsetPath = "/usr/bin/pmset"
    public static let sudoPath = "/usr/bin/sudo"
    public static let sudoersPath = "/private/etc/sudoers.d/wakebar_closed_lid"
    public static let launchAgentLabel = "app.wakebar.closed-lid-guard"
    public static let watchdogStaleInterval: TimeInterval = 90

    public static func isValidAccountName(_ accountName: String) -> Bool {
        guard let first = accountName.first,
              first.isASCII,
              first.isLetter || first == "_"
        else {
            return false
        }

        return accountName.dropFirst().allSatisfy { character in
            character.isASCII
                && (character.isLetter || character.isNumber || character == "_" || character == "-")
        }
    }

    public static func sudoersRule(for accountName: String) -> String? {
        guard isValidAccountName(accountName) else { return nil }

        return "\(accountName) ALL=(root) NOPASSWD: \(pmsetPath) -a disablesleep 0, \(pmsetPath) -a disablesleep 1\n"
    }

    public static func sudoArguments(enable: Bool) -> [String] {
        ["-n", pmsetPath, "-a", "disablesleep", enable ? "1" : "0"]
    }

    public static func authorizationInstallCommand(
        for accountName: String,
        nonce: String
    ) -> String? {
        guard let rule = sudoersRule(for: accountName),
              nonce.range(of: #"^[A-F0-9-]+$"#, options: .regularExpression) != nil
        else {
            return nil
        }

        let encodedRule = Data(rule.utf8).base64EncodedString()
        let temporaryPath = "/private/etc/sudoers.d/.wakebar_closed_lid.\(nonce)"

        return [
            "/bin/rm -f '\(temporaryPath)'",
            "/bin/echo '\(encodedRule)' | /usr/bin/base64 -D > '\(temporaryPath)'",
            "/usr/sbin/visudo -cf '\(temporaryPath)'",
            "/usr/sbin/chown root:wheel '\(temporaryPath)'",
            "/bin/chmod 0440 '\(temporaryPath)'",
            "/bin/mv -f '\(temporaryPath)' '\(sudoersPath)'"
        ].joined(separator: " && ")
    }

    public static let authorizationRemoveCommand = "/bin/rm -f '\(sudoersPath)'"

    public static func parseSleepDisabledState(from output: String) -> SleepDisabledState {
        let normalized = output.lowercased()

        if normalized.range(
            of: #"sleepdisabled[" ]*=[" ]*(yes|1|true)"#,
            options: .regularExpression
        ) != nil {
            return .enabled
        }

        if normalized.range(
            of: #"sleepdisabled[" ]*=[" ]*(no|0|false)"#,
            options: .regularExpression
        ) != nil {
            return .disabled
        }

        return .unknown
    }

    public static func parseBatteryStatus(from output: String) -> BatteryStatus {
        let isOnACPower = output.localizedCaseInsensitiveContains("AC Power")
        let percentage: Int?

        if let match = output.range(of: #"\b([0-9]{1,3})%"#, options: .regularExpression) {
            percentage = Int(output[match].dropLast())
        } else {
            percentage = nil
        }

        return BatteryStatus(percentage: percentage, isOnACPower: isOnACPower)
    }

    public static func supportDirectory(homeDirectory: URL) -> URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("WakeBar", isDirectory: true)
    }

    public static func ownershipMarkerURL(homeDirectory: URL) -> URL {
        supportDirectory(homeDirectory: homeDirectory)
            .appendingPathComponent("closed-lid-owned")
    }

    public static func heartbeatURL(homeDirectory: URL) -> URL {
        supportDirectory(homeDirectory: homeDirectory)
            .appendingPathComponent("closed-lid-heartbeat")
    }
}
