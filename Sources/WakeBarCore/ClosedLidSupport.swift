import Foundation

public enum SleepDisabledState: Equatable, Sendable {
    case enabled
    case disabled
    case unknown
}

public enum ClosedLidSupport {
    public static let pmsetPath = "/usr/bin/pmset"
    public static let sudoPath = "/usr/bin/sudo"
    public static let sudoersPath = "/private/etc/sudoers.d/wakebar_closed_lid"

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
}
