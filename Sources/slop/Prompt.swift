import Foundation

let systemInstructions = """
You translate a single line of user input into one correct macOS shell command.
The input is EITHER a rough or partial shell command to repair, OR a plain-English \
request to translate. Decide which it is and produce the corrected, directly runnable \
command. Prefer commands appropriate for the user's shell and current directory. \
Set confidence to high only when you are sure the command matches the user's intent. \
Set isDestructive to true for anything that deletes, overwrites, moves files, \
force-pushes, or needs sudo. Return only the structured result.
"""

func currentContext() -> String {
    let fm = FileManager.default
    let pwd = fm.currentDirectoryPath
    let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/sh"
    let entries = (try? fm.contentsOfDirectory(atPath: pwd)) ?? []
    let listing = entries.sorted().prefix(200).joined(separator: "\n")
    return """
    PWD: \(pwd)
    SHELL: \(shell)
    Directory listing:
    \(listing)
    """
}

func buildPrompt(input: String, context: String) -> String {
    """
    Context:
    \(context)

    User input:
    \(input)
    """
}
