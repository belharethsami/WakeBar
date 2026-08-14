import AppKit
import Foundation

enum AdministrativeAuthorizationError: LocalizedError {
    case scriptCouldNotBeCreated
    case authorizationFailed(String)

    var errorDescription: String? {
        switch self {
        case .scriptCouldNotBeCreated:
            "macOS could not create the administrator authorization request."
        case .authorizationFailed(let message):
            message
        }
    }
}

@MainActor
enum AdministrativeAuthorization {
    static func execute(command: String) throws {
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escapedCommand)\" with administrator privileges"

        guard let script = NSAppleScript(source: source) else {
            throw AdministrativeAuthorizationError.scriptCouldNotBeCreated
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
                ?? "Administrator authorization was not completed."
            throw AdministrativeAuthorizationError.authorizationFailed(message)
        }
    }
}
