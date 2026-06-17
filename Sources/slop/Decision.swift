// Sources/slop/Decision.swift
import Foundation

enum Action: Equatable {
    case run
    case propose
}

/// Deterministic danger check — a HARD GATE that does not trust the model.
/// If the resolved command matches any of these patterns it can never auto-run,
/// regardless of how safe/confident the LLM claimed it was. The model's
/// `isDestructive` can only ADD caution on top of this; it can never remove it.
///
/// This catches the syntactically-recognisable hazards (the ones a regex CAN
/// see). The LLM still covers semantic danger a pattern can't express.
func isDangerousCommand(_ command: String) -> Bool {
    let c = command.lowercased()

    // Whole-word matcher so `removable` doesn't match `rm`, etc.
    func hasWord(_ word: String) -> Bool {
        c.range(of: "(^|[^a-z0-9_-])\(NSRegularExpression.escapedPattern(for: word))([^a-z0-9_-]|$)",
                options: .regularExpression) != nil
    }
    func hasPattern(_ pattern: String) -> Bool {
        c.range(of: pattern, options: .regularExpression) != nil
    }

    // Recursive/forced remove: rm -rf, rm -fr, rm -r ... -f, rm --recursive, etc.
    if hasWord("rm"), hasPattern("(^|[^a-z0-9_-])-[a-z]*r[a-z]*\\b") { return true }
    if hasWord("rm"), c.contains("--recursive") || c.contains("--force") { return true }

    // Privilege escalation.
    if hasWord("sudo") || hasWord("doas") { return true }

    // Raw disk / filesystem writers.
    if hasWord("dd") { return true }
    if hasPattern("\\bmkfs(\\.[a-z0-9]+)?\\b") { return true }
    if hasWord("fdisk") || hasWord("diskutil") { return true }

    // Force-push to a remote — destructive to shared history.
    if c.contains("push") && (c.contains("--force") || hasPattern("(^|[^a-z0-9_-])-[a-z]*f")) { return true }

    // Recursive permission/ownership changes.
    if (hasWord("chmod") || hasWord("chown")) && hasPattern("(^|[^a-z0-9_-])-[a-z]*r") { return true }

    // Output redirection that truncates a file (`>`), but not append (`>>`).
    if hasPattern("[^>]>[^>]") || hasPattern("[^>]>\\s*$") { return true }

    // Pipe a download straight into a shell.
    if hasPattern("(curl|wget)[^|]*\\|\\s*(sudo\\s+)?(ba|z|fi|da)?sh") { return true }

    // Classic fork bomb.
    if c.contains(":(){") || c.contains(":|:&") { return true }

    return false
}

/// Decide whether to run a resolved command outright or pause for confirmation.
///
/// Runs ONLY when all three hold:
///   - the model was highly confident it understood you,
///   - the model did not flag the command destructive, AND
///   - the deterministic danger gate sees nothing hazardous.
/// `alwaysPrompt` (the --prompt/-i flag) forces confirmation unconditionally.
func decide(_ c: SloppyCommand, alwaysPrompt: Bool = false) -> Action {
    if alwaysPrompt { return .propose }
    if isDangerousCommand(c.command) { return .propose }   // hard gate
    return (c.confidence == .high && !c.isDestructive) ? .run : .propose
}
