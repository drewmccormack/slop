// Sources/slop/main.swift
import Foundation

let args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else {
    FileHandle.standardError.write(Data("usage: slop <sloppy command or plain English>\n".utf8))
    exit(64)
}
let input = args.joined(separator: " ")
let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/sh"

func prompt(_ s: String) {
    FileHandle.standardError.write(Data(s.utf8))
}

do {
    let result = try await interpret(input: input)

    func runIt() {
        switch execute(result.command, shell: shell) {
        case .ran(let code):
            exit(code)
        case .emitForEval(let cmd):
            // Wrapper detects this sentinel line on stdout and evals the command.
            print("__SLOP_EVAL__ \(cmd)")
            exit(0)
        }
    }

    switch decide(result) {
    case .run:
        prompt("\u{001B}[2m$ \(result.command)\u{001B}[0m\n")  // dim echo
        runIt()
    case .propose:
        prompt("  \(result.command)\n")
        prompt("  → \(result.explanation)\n")
        prompt("Run? [Y/n/e] ")
        let answer = readLine(strippingNewline: true)?.lowercased() ?? ""
        switch answer {
        case "", "y", "yes":
            runIt()
        case "e", "edit":
            prompt("edit, then press enter:\n  \(result.command)\n> ")
            let edited = readLine(strippingNewline: true) ?? result.command
            let final = edited.isEmpty ? result.command : edited
            switch execute(final, shell: shell) {
            case .ran(let code): exit(code)
            case .emitForEval(let cmd): print("__SLOP_EVAL__ \(cmd)"); exit(0)
            }
        default:
            prompt("cancelled\n")
            exit(1)
        }
    }
} catch let e as SlopError {
    prompt("slop: \(e.description)\n")
    exit(69)
} catch {
    prompt("slop: \(error)\n")
    exit(70)
}
