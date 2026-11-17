import AppKit
import Combine
import Foundation
#if canImport(WakeBarCore)
import WakeBarCore
#endif

@MainActor
final class SessionController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var endDate: Date?
    @Published private(set) var keepsDisplayAwake: Bool
    @Published private(set) var lastError: String?

    let closedLid: ClosedLidController

    private var caffeinateProcess: Process?
    private var deadlineTask: Task<Void, Never>?
    private var currentSessionID: UUID?
    private let quitsAfterSession: Bool

    init(startupOptions: StartupOptions = .current) {
        keepsDisplayAwake = startupOptions.keepsDisplayAwake
        quitsAfterSession = startupOptions.quitsAfterSession
        closedLid = ClosedLidController()
        closedLid.onSafetyStop = { [weak self] reason in
            self?.handleClosedLidSafetyStop(reason)
        }
        closedLid.onLidClosed = { [weak self] in
            self?.handleLidClosed()
        }

        if startupOptions.usesClosedLidMode {
            closedLid.setRequestedForCurrentLaunch(true)
        }

        if startupOptions.shouldStart {
            let duration = startupOptions.duration
            DispatchQueue.main.async { [weak self] in
                self?.start(for: duration)
            }
        }
    }

    func start(for duration: TimeInterval?) {
        stopCurrentProcess()
        closedLid.endSession()
        lastError = nil

        do {
            try closedLid.activateForSession()
        } catch {
            lastError = error.localizedDescription
            resetSessionState()
            return
        }

        let safeDuration = duration.map { max(1, $0) }
        let sessionID = UUID()

        do {
            try replaceCaffeinateProcess(duration: safeDuration)
            currentSessionID = sessionID
            isActive = true

            if let safeDuration {
                endDate = Date().addingTimeInterval(safeDuration)
                scheduleDeadline(after: safeDuration, sessionID: sessionID)
            } else {
                endDate = nil
            }
        } catch {
            closedLid.endSession()
            lastError = "Could not start caffeinate: \(error.localizedDescription)"
            resetSessionState()
        }
    }

    func start(until selectedTime: Date, now: Date = Date()) {
        let target = SessionSchedule.nextOccurrence(of: selectedTime, after: now)
        start(for: target.timeIntervalSince(now))
    }

    func stop() {
        stopCurrentProcess()
        closedLid.endSession()
        resetSessionState()
    }

    func setKeepsDisplayAwake(_ enabled: Bool) {
        guard enabled != keepsDisplayAwake else { return }

        let remainingDuration = endDate.map { max(1, $0.timeIntervalSinceNow) }
        let wasActive = isActive
        keepsDisplayAwake = enabled
        lastError = nil

        if wasActive {
            do {
                // Replace only the assertion process. Cycling the entire
                // session can leave an old display assertion alive while
                // closed-lid support is disabled and re-enabled.
                try replaceCaffeinateProcess(duration: remainingDuration)

                if !enabled, closedLid.isLidClosed {
                    turnDisplayOffNow()
                }
            } catch {
                closedLid.endSession()
                resetSessionState()
                lastError = "Could not update display sleep behavior: \(error.localizedDescription)"
            }
        }
    }

    func turnDisplayOffNow() {
        guard isActive, !keepsDisplayAwake else { return }

        let result = FixedCommandRunner.run(
            executablePath: DisplaySleepCommand.executableURL.path,
            arguments: DisplaySleepCommand.arguments
        )

        if result.terminationStatus != 0 {
            let detail = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            lastError = detail.isEmpty
                ? "macOS could not turn the display off."
                : "macOS could not turn the display off: \(detail)"
        }
    }

    func statusText(at date: Date = Date()) -> String {
        guard isActive else { return "Inactive" }
        guard let endDate else { return "Active indefinitely" }

        let totalSeconds = max(0, Int(endDate.timeIntervalSince(date).rounded(.up)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "Active · \(hours)h \(minutes)m remaining"
        }

        if minutes > 0 {
            return "Active · \(minutes)m \(seconds)s remaining"
        }

        return "Active · \(seconds)s remaining"
    }

    private func scheduleDeadline(after duration: TimeInterval, sessionID: UUID) {
        deadlineTask?.cancel()
        deadlineTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self?.finishTimedSession(sessionID: sessionID)
        }
    }

    private func finishTimedSession(sessionID: UUID) {
        guard currentSessionID == sessionID else { return }
        stopCurrentProcess()
        closedLid.endSession()
        resetSessionState()

        if quitsAfterSession {
            NSApplication.shared.terminate(nil)
        }
    }

    private func processDidExit(processIdentifier: Int32, terminationStatus: Int32) {
        guard caffeinateProcess?.processIdentifier == processIdentifier else { return }

        caffeinateProcess = nil
        deadlineTask?.cancel()
        deadlineTask = nil
        currentSessionID = nil
        isActive = false
        endDate = nil
        closedLid.endSession()

        if terminationStatus != 0 {
            lastError = "caffeinate stopped unexpectedly (status \(terminationStatus))."
        } else if quitsAfterSession {
            // caffeinate's timeout can finish before the UI deadline task.
            NSApplication.shared.terminate(nil)
        }
    }

    private func stopCurrentProcess() {
        deadlineTask?.cancel()
        deadlineTask = nil
        currentSessionID = nil

        terminateCaffeinateProcess()
    }

    private func replaceCaffeinateProcess(duration: TimeInterval?) throws {
        terminateCaffeinateProcess()

        let command = CaffeinateCommand(
            duration: duration,
            keepsDisplayAwake: keepsDisplayAwake,
            parentProcessIdentifier: ProcessInfo.processInfo.processIdentifier
        )
        let process = Process()

        process.executableURL = CaffeinateCommand.executableURL
        process.arguments = command.arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] process in
            let processIdentifier = process.processIdentifier
            let terminationStatus = process.terminationStatus
            Task { @MainActor [weak self] in
                self?.processDidExit(
                    processIdentifier: processIdentifier,
                    terminationStatus: terminationStatus
                )
            }
        }

        try process.run()
        caffeinateProcess = process
    }

    private func terminateCaffeinateProcess() {
        let process = caffeinateProcess
        caffeinateProcess = nil

        if process?.isRunning == true {
            process?.terminate()
            // Release the old display assertion before starting its
            // replacement so an unchecked toggle takes effect immediately.
            process?.waitUntilExit()
        }
    }

    private func resetSessionState() {
        deadlineTask?.cancel()
        deadlineTask = nil
        currentSessionID = nil
        isActive = false
        endDate = nil
    }

    func shutdownBeforeTermination() {
        stopCurrentProcess()
        closedLid.endSession()
        resetSessionState()
    }

    private func handleClosedLidSafetyStop(_ reason: String) {
        stopCurrentProcess()
        closedLid.endSession()
        resetSessionState()
        lastError = reason
    }

    private func handleLidClosed() {
        guard closedLid.isActive, !keepsDisplayAwake else { return }
        turnDisplayOffNow()
    }
}
