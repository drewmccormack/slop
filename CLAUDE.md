# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`slop` is a macOS CLI: you type a sloppy/half-remembered shell command or plain English, an LLM turns it into a real shell command, and slop runs it (when safe and confident) or proposes it with `[Y/n/e]`. The tagline is the joke — "AI slop comes to the command line" — but the tool is real and the safety model is taken seriously.

## Commands

```bash
swift build                 # debug build
swift build -c release      # release (the binary users install)
swift test                  # run the whole suite
swift test --filter DecisionTests          # one test class
swift test --filter DecisionTests/testHighConfidenceSafeRuns   # one test
./install.sh                # build release, install to ~/.local/bin/slop-bin, source wrapper into rc files
```

Tests are XCTest (`Tests/slopTests/`). The suite is fast and deterministic because the model is never called in tests — see "Testing" below.

## Big picture

The pipeline is one pass: `main.swift` parses flags → selects a backend → calls `interpret(input:backend:)` which returns a `SloppyCommand` → `decide()` turns that into `.run`/`.propose` → `execute()` runs it (or hands `cd`/`export` back to the shell wrapper). Each stage is its own small file with a narrow job.

**`SloppyCommand` (`SloppyCommand.swift`) is the spine.** Both backends produce this same struct — `{ command, explanation, confidence, isDestructive }` — so everything downstream (decision, executor, `--json`/`--dry-run` output) is backend-agnostic. The on-device path gets it via FoundationModels `@Generable`/`@Guide` macros; the OpenAI path gets it via a JSON-schema Structured Output that mirrors the same fields.

**Two backends, picked at runtime (`Backend.swift`, `Interpreter.swift`, `OpenAIInterpreter.swift`).** `selectBackend()` is pure (no I/O) and unit-tested. Precedence: `--llm=apple`/`--llm=openai` are *one-shot* overrides that never touch stored state; with no flag, if `OPENAI_API_KEY` is set it consults stored consent (`~/.config/slop/consent`), asking once and persisting the answer. OpenAI (`gpt-5.5`, override via `SLOP_OPENAI_MODEL`) is the backend that actually produces good commands; the Apple on-device ~3B model is a private/offline fallback that struggles with anything compositional. Only the interactive first-time prompt writes consent — keep that invariant if you touch backend selection.

**Safety is two independent layers (`Decision.swift`).** `decide()` runs a command only if `confidence == .high && !isDestructive` (the LLM's own judgment) AND `isDangerousCommand()` finds nothing (a deterministic regex gate: `rm -rf`, `sudo`, `dd`, `mkfs`, `git push --force`, `chmod -R`, truncating `>`, `curl|sh`, fork bomb). The gate exists because the LLM is not trustworthy about danger — a live test once had it mislabel a force-push as safe. **The gate can only add caution, never remove it. Never make `decide()` trust the model alone.** `DangerGateTests` pins that dangerous commands stay `.propose` even when the model claims high-confidence + not-destructive.

**The shell wrapper is load-bearing (`shell/slop.sh`).** The binary is installed as `slop-bin`; the user-facing `slop` is a shell *alias* defined by the wrapper. Two things only the wrapper can do:
- **Unquoted globs:** in zsh, `alias slop='noglob _slop'` puts `noglob` at the call site (the only place it works — a function-internal `noglob` is too late). bash has no call-site `noglob`, so bash users must quote globs. This is why it's an alias, not a function.
- **Live `cd`/`export`:** a child process can't change the parent shell's directory. So when `execute()` sees a `cd`/`export` (`ShellEval.swift` detects it), the binary writes the command to the temp file named by `SLOP_EVAL_FILE` (set by the wrapper) instead of running it; the wrapper `eval`s that file in the live shell. Standalone (no wrapper, `SLOP_EVAL_FILE` unset) it falls back to printing a `__SLOP_EVAL__ <cmd>` sentinel on stdout (`emitEval()` in `main.swift`).

**stdout/stderr discipline:** all prompts and echoes go to **stderr**; real command output streams straight to the terminal (the executor wires the child to the real FileHandles, and the wrapper does not capture stdout). Breaking this re-breaks the sentinel/streaming contract.

## Testing

The live-model path is never exercised in unit tests (it's non-deterministic and needs Apple Intelligence / a network). Tests cover the pure logic only — `decide()`, the danger gate, `cd`/`export` detection, prompt assembly, the executor, arg parsing, backend selection, and the wrapper file's contents. The model path is verified by manual smoke tests via `--json` (machine-readable verdict, never executes) and `--dry-run`. When changing model-facing behavior, verify with `slop --json '<input>'` rather than adding a flaky model assertion.

## Gotchas

- **Hand-rolled arg parsing (`Options.swift`), deliberately.** swift-argument-parser fights the core requirement of grabbing the rest of the line verbatim as free-form input. Flags are only recognized before the first non-flag word; `--` ends flag parsing.
- **Homebrew build env can break FoundationModels macros.** Under Homebrew's compiler shim, and when the active toolchain and SDK disagree (e.g. a beta Xcode alongside an older Command Line Tools SDK), `brew install` can fail to load the `@Generable`/`@Guide` macro plugin or hit Darwin-module clashes. The formula (`Formula/slop.rb`, mirrored in the `homebrew-slop` tap repo) works around it by invoking the released Xcode toolchain's `swift` directly with `DEVELOPER_DIR` pinned, bypassing the shim; it falls back to plain `swift build` when that toolchain isn't present. Running `swift build` directly is always fine.
- **macOS 26+ / Apple Silicon only** (FoundationModels). `Package.swift` pins `.macOS("26.0")`.
- The design spec and implementation plan live in `docs/superpowers/`.
