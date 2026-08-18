import AppKit
import Combine
import Darwin
import Foundation
import IOKit
#if canImport(WakeBarCore)
import WakeBarCore
#endif

enum ClosedLidControllerError: LocalizedError {
    case authorizationNotInstalled
    case watchdogUnavailable(String)
    case stateUnavailable
    case externallyManaged
    case lowPowerMode
    case batteryTooLow(Int)
    case commandFailed(String)
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .authorizationNotInstalled:
            "Install Closed-Lid Support before starting this type of session."
        case .watchdogUnavailable(let detail):
            "The closed-lid safety watchdog could not start: \(detail)"
        case .stateUnavailable:
            "WakeBar could not verify the current macOS sleep-disabled state."
        case .externallyManaged:
            "System sleep is already disabled by another tool. WakeBar will not take ownership of it."
        case .lowPowerMode:
            "Closed-lid mode is unavailable while Low Power Mode is enabled."
        case .batteryTooLow(let percentage):
            "Closed-lid mode requires more than \(percentage)% battery when unplugged."
        case .commandFailed(let detail):
            detail.isEmpty
                ? "macOS rejected the closed-lid power command."
                : "macOS rejected the closed-lid power command: \(detail)"
        case .verificationFailed:
            "The command completed, but macOS did not report that sleep was disabled."
        }
    }
}

@MainActor
final class ClosedLidController: ObservableObject {
    static let batteryFloor = 20

    @Published private(set) var helperInstalled = false
    @Published private(set) var watchdogInstalled = false
    @Published private(set) var systemState: SleepDisabledState = .unknown
    @Published private(set) var isActive = false
    @Published private(set) var batteryStatus = BatteryStatus(
        percentage: nil,
        isOnACPower: false
    )
    @Published private(set) var isLidClosed = false
    @Published private(set) var lastError: String?
    @Published private(set) var isRequested: Bool

    var onSafetyStop: ((String) -> Void)?
    var onLidClosed: (() -> Void)?

    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let homeDirectory: URL
    private let powerRootDomain: io_service_t
    private var heartbeatTask: Task<Void, Never>?
    private var safetyTask: Task<Void, Never>?
    private var clamshellTask: Task<Void, Never>?
    private var clamshellTransitions = ClamshellTransitionDetector()

    private static let requestedKey = "wakebar.closedLid.requested"

    init(
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard
    ) {
        self.fileManager = fileManager
        self.defaults = defaults
        homeDirectory = fileManager.homeDirectoryForCurrentUser
        powerRootDomain = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPMrootDomain")
        )
        isRequested = defaults.bool(forKey: Self.requestedKey)

        refresh()

        if ownsSystemOverride {
            endSession()
        }
    }

    deinit {
        if powerRootDomain != 0 {
            IOObjectRelease(powerRootDomain)
        }
    }

    var statusText: String {
        if isActive {
            return "Closed-lid protection active"
        }

        if !helperInstalled {
            return "One-time support installation required"
        }

        if systemState == .enabled {
            return "System sleep is disabled by another tool"
        }

        return isRequested ? "Ready for the next session" : "Closed-lid mode off"
    }

    func refresh() {
        helperInstalled = fileManager.fileExists(atPath: ClosedLidSupport.sudoersPath)
        refreshSystemState()
        refreshBatteryStatus()
    }

    func setRequested(_ requested: Bool) {
        lastError = nil

        guard !isActive else {
            lastError = "End the current session before changing closed-lid mode."
            return
        }

        guard !requested || helperInstalled else {
            lastError = ClosedLidControllerError.authorizationNotInstalled.localizedDescription
            return
        }

        isRequested = requested
        defaults.set(requested, forKey: Self.requestedKey)
    }

    func setRequestedForCurrentLaunch(_ requested: Bool) {
        lastError = nil
        isRequested = requested
    }

    func installSupport() {
        lastError = nil

        let accountName = NSUserName()
        let nonce = UUID().uuidString.uppercased()

        guard let command = ClosedLidSupport.authorizationInstallCommand(
            for: accountName,
            nonce: nonce
        ) else {
            lastError = "The current macOS account name is not safe to use in a sudoers rule."
            return
        }

        do {
            try AdministrativeAuthorization.execute(command: command)
            helperInstalled = fileManager.fileExists(atPath: ClosedLidSupport.sudoersPath)

            guard helperInstalled else {
                throw ClosedLidControllerError.authorizationNotInstalled
            }

            try installWatchdog()
            refresh()
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }

    func removeSupport() {
        lastError = nil

        guard !isActive else {
            lastError = "End the current session before removing closed-lid support."
            return
        }

        if ownsSystemOverride {
            endSession()
            guard !ownsSystemOverride else { return }
        }

        do {
            try AdministrativeAuthorization.execute(
                command: ClosedLidSupport.authorizationRemoveCommand
            )
            removeWatchdog()
            helperInstalled = false
            watchdogInstalled = false
            isRequested = false
            defaults.set(false, forKey: Self.requestedKey)
            refresh()
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }

    func activateForSession() throws {
        lastError = nil
        refresh()

        guard isRequested else { return }
        guard helperInstalled else {
            throw ClosedLidControllerError.authorizationNotInstalled
        }
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else {
            throw ClosedLidControllerError.lowPowerMode
        }
        if !batteryStatus.isOnACPower,
           let percentage = batteryStatus.percentage,
           percentage <= Self.batteryFloor {
            throw ClosedLidControllerError.batteryTooLow(Self.batteryFloor)
        }
        guard systemState != .unknown else {
            throw ClosedLidControllerError.stateUnavailable
        }
        guard systemState != .enabled else {
            throw ClosedLidControllerError.externallyManaged
        }

        do {
            try installWatchdog()
            try createOwnershipFiles()
        } catch {
            removeOwnershipFiles()
            throw ClosedLidControllerError.watchdogUnavailable(error.localizedDescription)
        }

        let result = FixedCommandRunner.run(
            executablePath: ClosedLidSupport.sudoPath,
            arguments: ClosedLidSupport.sudoArguments(enable: true)
        )

        guard result.terminationStatus == 0 else {
            removeOwnershipFiles()
            throw ClosedLidControllerError.commandFailed(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        refreshSystemState()
        guard systemState == .enabled else {
            _ = runDisableCommand()
            removeOwnershipFiles()
            throw ClosedLidControllerError.verificationFailed
        }

        isActive = true
        beginHeartbeat()
        beginSafetyMonitor()
        beginClamshellMonitor()
    }

    func endSession() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        safetyTask?.cancel()
        safetyTask = nil
        clamshellTask?.cancel()
        clamshellTask = nil
        clamshellTransitions.reset()
        isLidClosed = false

        guard ownsSystemOverride else {
            isActive = false
            refreshSystemState()
            return
        }

        let result = runDisableCommand()
        refreshSystemState()

        guard result.terminationStatus == 0, systemState != .enabled else {
            lastError = ClosedLidControllerError.commandFailed(
                result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            ).localizedDescription
            isActive = systemState == .enabled
            return
        }

        removeOwnershipFiles()
        isActive = false
    }

    private var supportDirectory: URL {
        ClosedLidSupport.supportDirectory(homeDirectory: homeDirectory)
    }

    private var ownershipMarker: URL {
        ClosedLidSupport.ownershipMarkerURL(homeDirectory: homeDirectory)
    }

    private var heartbeat: URL {
        ClosedLidSupport.heartbeatURL(homeDirectory: homeDirectory)
    }

    private var installedWatchdog: URL {
        supportDirectory.appendingPathComponent("WakeBarGuard")
    }

    private var launchAgentURL: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(ClosedLidSupport.launchAgentLabel).plist")
    }

    private var ownsSystemOverride: Bool {
        fileManager.fileExists(atPath: ownershipMarker.path)
    }

    private func refreshSystemState() {
        let result = FixedCommandRunner.run(
            executablePath: "/usr/sbin/ioreg",
            arguments: ["-r", "-c", "IOPMrootDomain", "-d", "1"]
        )

        guard result.terminationStatus == 0 else {
            systemState = .unknown
            return
        }

        systemState = ClosedLidSupport.parseSleepDisabledState(from: result.output)
    }

    private func refreshBatteryStatus() {
        let result = FixedCommandRunner.run(
            executablePath: ClosedLidSupport.pmsetPath,
            arguments: ["-g", "batt"]
        )

        guard result.terminationStatus == 0 else { return }
        batteryStatus = ClosedLidSupport.parseBatteryStatus(from: result.output)
    }

    private func runDisableCommand() -> FixedCommandResult {
        FixedCommandRunner.run(
            executablePath: ClosedLidSupport.sudoPath,
            arguments: ClosedLidSupport.sudoArguments(enable: false)
        )
    }

    private func createOwnershipFiles() throws {
        try fileManager.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: supportDirectory.path
        )

        let owner = "pid=\(ProcessInfo.processInfo.processIdentifier)\n"
        try Data(owner.utf8).write(to: ownershipMarker, options: .atomic)
        try writeHeartbeat()
    }

    private func writeHeartbeat() throws {
        try Data("\(Date().timeIntervalSince1970)\n".utf8).write(
            to: heartbeat,
            options: .atomic
        )
    }

    private func removeOwnershipFiles() {
        try? fileManager.removeItem(at: ownershipMarker)
        try? fileManager.removeItem(at: heartbeat)
    }

    private func beginHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { @MainActor [weak self] in
            while let self, self.isActive, !Task.isCancelled {
                try? self.writeHeartbeat()

                do {
                    try await Task.sleep(for: .seconds(15))
                } catch {
                    return
                }
            }
        }
    }

    private func beginSafetyMonitor() {
        safetyTask?.cancel()
        safetyTask = Task { @MainActor [weak self] in
            while let self, self.isActive, !Task.isCancelled {
                self.refreshBatteryStatus()

                if ProcessInfo.processInfo.isLowPowerModeEnabled {
                    self.triggerSafetyStop("WakeBar ended closed-lid mode because Low Power Mode was enabled.")
                    return
                }

                if !self.batteryStatus.isOnACPower,
                   let percentage = self.batteryStatus.percentage,
                   percentage <= Self.batteryFloor {
                    self.triggerSafetyStop(
                        "WakeBar ended closed-lid mode at \(percentage)% battery."
                    )
                    return
                }

                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    return
                }
            }
        }
    }

    private func beginClamshellMonitor() {
        clamshellTask?.cancel()
        clamshellTransitions.reset()

        clamshellTask = Task { @MainActor [weak self] in
            while let self, self.isActive, !Task.isCancelled {
                if let isClosed = self.readClamshellState() {
                    self.isLidClosed = isClosed

                    if self.clamshellTransitions.consume(isClosed: isClosed) {
                        self.onLidClosed?()
                    }
                }

                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return
                }
            }
        }
    }

    private func readClamshellState() -> Bool? {
        guard powerRootDomain != 0,
              let property = IORegistryEntryCreateCFProperty(
                  powerRootDomain,
                  "AppleClamshellState" as CFString,
                  kCFAllocatorDefault,
                  0
              )
        else {
            return nil
        }

        return property.takeRetainedValue() as? Bool
    }

    private func triggerSafetyStop(_ reason: String) {
        lastError = reason

        if let onSafetyStop {
            onSafetyStop(reason)
        } else {
            endSession()
        }
    }

    private func bundledWatchdogURL() -> URL? {
        let packagedURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("WakeBarGuard")

        if fileManager.isExecutableFile(atPath: packagedURL.path) {
            return packagedURL
        }

        let developmentURL = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("WakeBarGuard")

        if let developmentURL,
           fileManager.isExecutableFile(atPath: developmentURL.path) {
            return developmentURL
        }

        return nil
    }

    private func installWatchdog() throws {
        guard let sourceURL = bundledWatchdogURL() else {
            throw ClosedLidControllerError.watchdogUnavailable(
                "WakeBarGuard is missing from the application bundle."
            )
        }

        try fileManager.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let temporaryWatchdog = supportDirectory.appendingPathComponent(
            ".WakeBarGuard.\(UUID().uuidString)"
        )
        try fileManager.copyItem(at: sourceURL, to: temporaryWatchdog)
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: temporaryWatchdog.path
        )

        if fileManager.fileExists(atPath: installedWatchdog.path) {
            try fileManager.removeItem(at: installedWatchdog)
        }
        try fileManager.moveItem(at: temporaryWatchdog, to: installedWatchdog)

        let launchAgent: [String: Any] = [
            "Label": ClosedLidSupport.launchAgentLabel,
            "ProgramArguments": [installedWatchdog.path],
            "RunAtLoad": true,
            "StartInterval": 30,
            "ProcessType": "Background"
        ]
        let launchAgentData = try PropertyListSerialization.data(
            fromPropertyList: launchAgent,
            format: .xml,
            options: 0
        )
        try launchAgentData.write(to: launchAgentURL, options: .atomic)

        let serviceTarget = "gui/\(getuid())/\(ClosedLidSupport.launchAgentLabel)"
        _ = FixedCommandRunner.run(
            executablePath: "/bin/launchctl",
            arguments: ["bootout", serviceTarget]
        )
        let bootstrap = FixedCommandRunner.run(
            executablePath: "/bin/launchctl",
            arguments: ["bootstrap", "gui/\(getuid())", launchAgentURL.path]
        )

        guard bootstrap.terminationStatus == 0 else {
            throw ClosedLidControllerError.watchdogUnavailable(
                bootstrap.output.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        watchdogInstalled = true
    }

    private func removeWatchdog() {
        let serviceTarget = "gui/\(getuid())/\(ClosedLidSupport.launchAgentLabel)"
        _ = FixedCommandRunner.run(
            executablePath: "/bin/launchctl",
            arguments: ["bootout", serviceTarget]
        )

        try? fileManager.removeItem(at: launchAgentURL)
        try? fileManager.removeItem(at: installedWatchdog)
        removeOwnershipFiles()
    }
}
