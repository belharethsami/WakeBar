import Foundation

struct FixedCommandResult {
    let terminationStatus: Int32
    let output: String
}

enum FixedCommandRunner {
    static func run(executablePath: String, arguments: [String]) -> FixedCommandResult {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return FixedCommandResult(
                terminationStatus: process.terminationStatus,
                output: String(decoding: data, as: UTF8.self)
            )
        } catch {
            return FixedCommandResult(
                terminationStatus: -1,
                output: error.localizedDescription
            )
        }
    }
}
