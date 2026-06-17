// Sources/slop/Executor.swift
import Foundation

enum ExecOutcome: Equatable {
    case ran(exitCode: Int32)
    case emitForEval(String)
}

func execute(_ command: String, shell: String) -> ExecOutcome {
    if needsLiveShellEval(command) {
        return .emitForEval(command)
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: shell)
    process.arguments = ["-c", command]
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    do {
        try process.run()
        process.waitUntilExit()
        return .ran(exitCode: process.terminationStatus)
    } catch {
        FileHandle.standardError.write(Data("slop: failed to run command: \(error)\n".utf8))
        return .ran(exitCode: 127)
    }
}
