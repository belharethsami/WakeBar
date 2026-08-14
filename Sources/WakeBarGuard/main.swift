import Foundation
import WakeBarCore

private func run(_ executableURL: URL, arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    } catch {
        return -1
    }
}

let fileManager = FileManager.default
let homeDirectory = fileManager.homeDirectoryForCurrentUser
let ownershipMarker = ClosedLidSupport.ownershipMarkerURL(homeDirectory: homeDirectory)
let heartbeat = ClosedLidSupport.heartbeatURL(homeDirectory: homeDirectory)

guard fileManager.fileExists(atPath: ownershipMarker.path) else {
    exit(0)
}

let heartbeatDate = try? heartbeat.resourceValues(forKeys: [.contentModificationDateKey])
    .contentModificationDate
let heartbeatAge = heartbeatDate.map { Date().timeIntervalSince($0) } ?? .infinity

guard heartbeatAge >= ClosedLidSupport.watchdogStaleInterval else {
    exit(0)
}

let status = run(
    URL(fileURLWithPath: ClosedLidSupport.sudoPath),
    arguments: ClosedLidSupport.sudoArguments(enable: false)
)

guard status == 0 else {
    exit(status)
}

try? fileManager.removeItem(at: ownershipMarker)
try? fileManager.removeItem(at: heartbeat)
