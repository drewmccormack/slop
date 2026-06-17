# slop — the sloppy shell command interpreter

**Date:** 2026-06-17
**Status:** Design (pending review)

## 1. Concept

`slop <whatever you typed>` accepts either a *sloppy / partial real shell command* or *plain English*, uses Apple's on-device Foundation Models to produce the correct command, and then either runs it (when safe and confident) or proposes it for confirmation.

```
slop cp *.m dir/                      # repair a rough command
slop copy all the m files into dir    # plain English
slop cd to the lip reading project    # English, resolves a vague reference
```

It runs **100% on-device** via the `FoundationModels` framework (already present on this Mac, macOS 26.5). No API keys, no network, no per-token cost, private.

### Why build this (prior art)

The generic "natural language → shell command" category is crowded (`pls`, `aichat`, `llm-cmd`, GitHub Copilot CLI), but those are almost all cloud-LLM tools. On-device, `apfel` (Homebrew, Swift, Apple FoundationModels) ships a `cmd` demo that does English→command, propose-only.

The **differentiator for `slop`** is the *sloppy-repair angle*: the same command accepts a rough/partial *real* command and fixes/completes it (not just English), plus a **confidence-based auto-run** policy (run when safe+confident, otherwise propose). No existing on-device tool does this combination.

## 2. Flow

1. The shell wrapper collects the raw input (see §6 for how globs/pipes are handled) and calls the `slop` binary.
2. One call to the on-device Foundation Model. The prompt explains the input is *either* a rough shell command to repair *or* an English request to translate — the model decides which and produces the right command. Returns **structured output** (`@Generable`, see §3).
3. **Decision (pure Swift, no model):**
   - `confidence == .high && !isDestructive` → **run it** (echo the command first so the user sees what ran).
   - otherwise → **propose**: print the command *and* a plain-English description of what it does, then prompt `Run? [Y/n/e]`.
4. Execute via the user's shell (`$SHELL -c "<command>"`) so globs/pipes/quoting behave normally. Pass through exit code and stderr.

## 3. Structured output

```swift
@Generable
struct SloppyCommand {
    @Guide(description: "The corrected, runnable shell command")
    let command: String

    @Guide(description: "Plain-English description of what the command does")
    let explanation: String

    @Guide(description: "How confident you are that this matches the user's intent")
    let confidence: Confidence          // .high / .medium / .low

    @Guide(description: "True if the command deletes, overwrites, moves, force-pushes, or needs sudo")
    let isDestructive: Bool
}

@Generable
enum Confidence { case high, medium, low }
```

**Decision table:**

| confidence | isDestructive | action            |
|------------|---------------|-------------------|
| high       | false         | run (echo first)  |
| high       | true          | propose           |
| medium/low | any           | propose           |

When proposing, always show **both** the command and the `explanation`.

## 4. Context given to the model

**Current directory only** (deliberately small/predictable):
- `pwd`
- `$SHELL`
- `ls` of the current directory

So `cd to the lip reading project` resolves when the target is reachable from the cwd (e.g. a `LipReading` folder under the current dir). If it can't resolve confidently, the model returns lower confidence → slop proposes its best guess and the user confirms/edits. Broader project-root scanning is explicitly out of scope for v1 (can be added later).

## 5. Architecture

Single Swift Package Manager executable linking `FoundationModels` directly (no dependency on external CLIs like apfel/afm — the framework is already on the machine; in-process is lowest latency and gives full control of the structured-output schema).

```
slop/
  Package.swift
  Sources/slop/
    main.swift           — parse args, orchestrate, print/prompt
    Interpreter.swift     — build prompt, call the model, return SloppyCommand
    SloppyCommand.swift   — the @Generable struct + Confidence enum
    Executor.swift        — run via $SHELL -c; emit cd/export for the wrapper to eval
    Prompt.swift          — instruction prompt text + context assembly
```

### The `cd` / `export` problem

A child process cannot change its parent shell's working directory or environment. So when the resolved command is a bare `cd` (or `export`), the binary cannot move the user's live shell on its own.

**Solution:** the installed shell wrapper handles this. When the binary determines the command is a `cd`/`export`, it prints the command to stdout in a recognizable form and exits with a sentinel; the wrapper `eval`s that line *in the current shell*. For all other commands, the binary runs them itself via `$SHELL -c`. (Verified: `eval "cd <path>"` inside a shell function does change the live cwd.)

## 6. Raw input: globs, pipes, redirects

The shell expands globs and parses pipes/redirects **before** `slop` ever runs. Verified: typing `slop cp *.m dir/` gives the binary `argv = [cp, a.m, b.m, c.m, dir/]` — the `*.m` is already gone; and with **no** matching files, zsh aborts the line (`no matches found`) so slop is never invoked.

**Approach: a smart shell wrapper installed in `.zshrc` and `.bashrc`.**

- **Globs / `~` / plain text** are preserved by disabling globbing for the call:
  - zsh: `alias slop='noglob _slop'`
  - bash: a wrapper that sets `set -f` for the call (function form), then restores.
  - Result (target): `slop cp *.m dir/` and `slop cd to the lip reading project` work **unquoted**.
- **Pipes / redirects / `&&` / `;`** are shell *grammar*, parsed before any function/alias runs and therefore **cannot** be captured unquoted. This is a hard limit of shell parsing, not a fixable bug. For these, the user **quotes**:
  - `slop 'cat access.log | grep 404 | wc -l'` (literal repair), or
  - `slop count 404 responses in access.log` (English — no special chars, so no quotes needed).

  This split is convenient: the inputs that need quoting (pipes) are exactly the ones English describes well.

**Quoting is the universal escape hatch.** Verified: a quoted argument reaches the binary as a single literal string with pipes, globs, `&&`, and redirects fully intact (e.g. `slop 'cp *.m dir/ && echo done > log.txt'` → one arg `cp *.m dir/ && echo done > log.txt`). The rule to document for users: *unquoted is the convenience path for the common cases (globs, plain English); whenever the command contains a pipe / redirect / `&&` / `;`, quote it — and it always works.*

### Fragility note (must be tested, not assumed)

The `noglob`/`set -f` behavior differs between **interactive and non-interactive** shells and between **zsh and bash**. During implementation we will verify empirically, in the user's real interactive zsh *and* bash, that unquoted globs survive to the binary. **Quoting is the always-works fallback** and will be documented. We treat "globs survive unquoted" as a tested property, not an assumption.

The wrapper is POSIX-compatible function syntax so it works in both shells; it is installed into both `.zshrc` and `.bashrc` when present.

## 7. Error handling

- **Model unavailable** (Apple Intelligence off / not ready): check `SystemLanguageModel.availability` up front; print a clear "enable Apple Intelligence" message; exit non-zero.
- **Model returns empty/garbage command**: treat as low confidence → propose nothing to run, show the explanation, do not execute.
- **Command fails when run**: pass through the shell's exit code and stderr. slop does not second-guess real failures.
- **`[e]dit` at the prompt**: open the proposed command in `$EDITOR` (or inline edit), then run what is saved.

## 8. Testing

- **Unit:** the decision table (`confidence × isDestructive → run/propose`) — pure function, no model.
- **Unit:** `cd`/`export` detection (which commands get the eval-in-current-shell path).
- **Manual smoke tests** (model output is non-deterministic, so verify behavior not exact strings):
  - `slop cp *.m dir/` → repairs and (if safe+confident) runs.
  - `slop list big swift files` → English → command.
  - `slop rm the build folder` → **must propose**, never auto-run (destructive).
  - `slop cd to <a real subdir>` → changes the live shell's cwd.
  - Glob survival check in real interactive zsh and bash (per §6).

## 9. Out of scope for v1

- Broader filesystem context / project-root scanning.
- Multi-step plans or chained commands beyond what a single `$SHELL -c` runs.
- Interactive REPL mode (slop is a one-shot command).
- A bundled HTTP server / OpenAI-compatible endpoint (that's apfel's territory).
