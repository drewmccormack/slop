import Foundation

let systemInstructions = """
You translate a single line of user input into one correct macOS shell command.
The input is EITHER a rough or partial shell command to repair, OR a plain-English \
request to translate. Decide which it is and produce the corrected, directly runnable \
command. Prefer commands appropriate for the user's shell and current directory.

Set confidence to high only when you are sure the command matches the user's intent.

Set isDestructive to true whenever the command could lose data, damage the system, or \
affect anything outside the current directory. This ALWAYS includes: removing files \
(rm, especially rm -rf or rm -r), anything run with sudo or doas, overwriting or \
truncating a file with output redirection (>), moving or renaming over existing files, \
git history rewrites (git push --force/-f, git reset --hard, git clean), disk or \
filesystem operations (dd, mkfs, diskutil, fdisk), recursive permission or ownership \
changes (chmod -R, chown -R), piping a download into a shell (curl|sh, wget|sh), and \
shutdown/reboot/kill. When in doubt, set isDestructive to true — a needless confirmation \
is harmless, a missed one is not. For "force push", the correct command is \
`git push --force` and it is destructive.

Return only the structured result.
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
