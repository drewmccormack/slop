// Sources/slop/main.swift
import Foundation

let options = parseOptions(Array(CommandLine.arguments.dropFirst()))
guard !options.input.isEmpty else {
    FileHandle.standardError.write(Data("usage: slop [--dry-run|-n] [--prompt|-i] <sloppy command or plain English>\n".utf8))
    exit(64)
}
let input = options.input
let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/sh"

func prompt(_ s: String) {
    FileHandle.standardError.write(Data(s.utf8))
}

// When run under the shell wrapper, SLOP_EVAL_FILE points at a temp file the
// wrapper will source/eval in the live shell. Writing the cd/export command
// there (instead of stdout) keeps real command output uncaptured and streaming
// straight to the terminal. Falls back to a stdout sentinel when run standalone.
func emitEval(_ command: String) {
    if let path = ProcessInfo.processInfo.environment["SLOP_EVAL_FILE"], !path.isEmpty {
        try? Data(command.utf8).write(to: URL(fileURLWithPath: path))
    } else {
        print("__SLOP_EVAL__ \(command)")
    }
}

do {
    let result = try await interpret(input: input)

    func runIt() {
        switch execute(result.command, shell: shell) {
        case .ran(let code):
            exit(code)
        case .emitForEval(let cmd):
            emitEval(cmd)
            exit(0)
        }
    }

    // --json: emit the raw structured result for scripting/testing. Never runs.
    if options.json {
        let wouldRun = decide(result, alwaysPrompt: options.alwaysPrompt) == .run
        let conf: String
        switch result.confidence {
        case .high: conf = "high"
        case .medium: conf = "medium"
        case .low: conf = "low"
        }
        func esc(_ s: String) -> String {
            var out = ""
            for ch in s {
                switch ch {
                case "\\": out += "\\\\"
                case "\"": out += "\\\""
                case "\n": out += "\\n"
                case "\t": out += "\\t"
                default: out.append(ch)
                }
            }
            return out
        }
        print("{\"command\":\"\(esc(result.command))\",\"explanation\":\"\(esc(result.explanation))\",\"confidence\":\"\(conf)\",\"isDestructive\":\(result.isDestructive),\"dangerous\":\(isDangerousCommand(result.command)),\"wouldRun\":\(wouldRun)}")
        exit(0)
    }

    // --dry-run: show what slop resolved (command, explanation, and why it would
    // run or pause) and exit without touching anything.
    if options.dryRun {
        prompt("  \(result.command)\n")
        prompt("  → \(result.explanation)\n")
        let verdict = decide(result, alwaysPrompt: options.alwaysPrompt) == .run
            ? "would run automatically"
            : "would pause for confirmation (destructive or uncertain)"
        prompt("  [dry run] \(verdict)\n")
        exit(0)
    }

    switch decide(result, alwaysPrompt: options.alwaysPrompt) {
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
            case .emitForEval(let cmd): emitEval(cmd); exit(0)
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
