// Sources/slop/Options.swift
// Pure parsing of slop's command-line flags. Kept separate from main.swift so it
// can be unit-tested without touching the model or the shell.

enum LLMChoice: Equatable {
    case auto    // default: OpenAI if key + consent, else on-device Apple
    case apple   // force on-device
    case openai  // force OpenAI (implies consent)
}

struct Options: Equatable {
    var dryRun = false      // resolve + print the command and verdict; never execute
    var alwaysPrompt = false // force the [Y/n/e] confirmation even for safe commands
    var json = false        // emit the raw structured result as JSON; implies dry-run
    var llm: LLMChoice = .auto // which backend to use
    var input = ""          // the remaining words, joined — the user's request
}

/// Parse leading flags off the argument list. Flags are only recognised before
/// the first non-flag word; everything from the first non-flag word onward is the
/// input verbatim (so `slop --dry-run echo --help` treats `echo --help` as input).
/// A lone `--` ends flag parsing explicitly.
func parseOptions(_ args: [String]) -> Options {
    var opts = Options()
    var rest = args[...]

    loop: while let first = rest.first {
        switch first {
        case "--dry-run", "-n":
            opts.dryRun = true
            rest = rest.dropFirst()
        case "--prompt", "-i":
            opts.alwaysPrompt = true
            rest = rest.dropFirst()
        case "--json":
            opts.json = true
            opts.dryRun = true   // json never executes
            rest = rest.dropFirst()
        case "--llm=openai", "--openai":
            opts.llm = .openai
            rest = rest.dropFirst()
        case "--llm=apple", "--apple", "--local":
            opts.llm = .apple
            rest = rest.dropFirst()
        case "--":
            rest = rest.dropFirst()
            break loop
        default:
            break loop
        }
    }

    opts.input = rest.joined(separator: " ")
    return opts
}
