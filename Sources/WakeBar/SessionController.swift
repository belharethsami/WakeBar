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

    private var caffeinateProcess: Process?
    private var deadlineTask: Task<Void, Never>?
    private var currentSessionID: UUID?
    private let quitsAfterSession: Bool

    init(startupOptions: StartupOptions = .current) {
        keepsDisplayAwake = startupOptions.keepsDisplayAwake
        quitsAfterSession = startupOptions.quitsAfterSession

        if startupOptions.shouldStart {
            let duration = startupOptions.duration
            DispatchQueue.main.async { [weak self] in
                self?.start(for: duration)
            }
        }
    }

    func start(for duration: TimeInterval?) {
        stopCurrentProcess()
        lastError = nil

        let safeDuration = duration.map { max(1, $0) }
        let command = CaffeinateCommand(
            duration: safeDuration,
            keepsDisplayAwake: keepsDisplayAwake,
            parentProcessIdentifier: ProcessInfo.processInfo.processIdentifier
        )
        let process = Process()
        let sessionID = UUID()

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

        do {
            try process.run()
            caffeinateProcess = process
            currentSessionID = sessionID
            isActive = true

            if let safeDuration {
                endDate = Date().addingTimeInterval(safeDuration)
                scheduleDeadline(after: safeDuration, sessionID: sessionID)
            } else {
                endDate = nil
            }
        } catch {
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
        resetSessionState()
    }

    func setKeepsDisplayAwake(_ enabled: Bool) {
        guard enabled != keepsDisplayAwake else { return }

        let remainingDuration = endDate.map { max(1, $0.timeIntervalSinceNow) }
        let wasActive = isActive
        keepsDisplayAwake = enabled

        if wasActive {
            start(for: remainingDuration)
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

        if terminationStatus != 0 {
            lastError = "caffeinate stopped unexpectedly (status \(terminationStatus))."
        }
    }

    private func stopCurrentProcess() {
        deadlineTask?.cancel()
        deadlineTask = nil
        currentSessionID = nil

        let process = caffeinateProcess
        caffeinateProcess = nil

        if process?.isRunning == true {
            process?.terminate()
        }
    }

    private func resetSessionState() {
        deadlineTask?.cancel()
        deadlineTask = nil
        currentSessionID = nil
        isActive = false
        endDate = nil
    }
}
