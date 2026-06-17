# slop

Sloppy shell, on-device. Type a rough command or plain English; `slop` uses
Apple's on-device Foundation Models to produce the right shell command, then
runs it (when safe and confident) or shows it for confirmation.

100% on-device. No API keys, no network, private. Requires macOS 26+,
Apple Silicon, Apple Intelligence enabled.

## Install

    ./install.sh

Open a new shell. (Installs a `slop-bin` binary to `~/.local/bin` and a `slop`
shell function into your `.zshrc` and `.bashrc` when present.)

## Use

    slop list files here
    slop cp *.m dir/
    slop cd into the src folder

Safe + confident commands run immediately (echoed dim first, e.g. `$ ls`).
Destructive or uncertain ones are shown with a plain-English description and
wait for `[Y/n/e]`:

- **Y** / Enter — run it
- **n** — cancel
- **e** — edit the command, then run what you save

Anything that deletes, overwrites, moves, force-pushes, or needs `sudo` always
proposes — it is never auto-run.

### Quoting

Unquoted works for globs and plain English. Whenever your command contains a
pipe, redirect, or `&&`, quote it — that always works:

    slop 'wc -l *.swift | tail -1'

This is because the shell parses pipes and redirects as grammar before `slop`
ever sees them; quoting passes the whole line through verbatim.

### Glob behavior on this machine (verified)

Unquoted globs **survive** to `slop` in both **zsh** (via `noglob`) and **bash**
(via `set -f`) — verified: `slop cp *.m dir/` reaches the binary as the literal
`cp *.m dir/`, not pre-expanded filenames. Pipes and redirects still require
quoting (see above).

`cd` and `export` take effect in your live shell: the binary emits the command
back through a `__SLOP_EVAL__` sentinel and the shell wrapper `eval`s it in the
current session. Verified working in both zsh and bash. (Because model output
is non-deterministic, a borderline `cd` request is occasionally proposed rather
than auto-run; just press Enter to confirm.)

## How it works

1. The shell wrapper (`shell/slop.sh`) disables globbing for the call and runs
   `slop-bin`, capturing stdout.
2. `slop-bin` checks the on-device model is available, then asks it to either
   repair a sloppy command or translate English, returning a structured result:
   `{ command, explanation, confidence, isDestructive }`.
3. A pure decision rule picks the action: **run** iff `confidence == high && !isDestructive`,
   otherwise **propose**.
4. Non-`cd`/`export` commands run via `$SHELL -c` with output streamed straight
   to your terminal. `cd`/`export` are emitted via the `__SLOP_EVAL__` sentinel
   for the wrapper to `eval` in your live shell.

All prompts and echoes go to stderr; stdout carries only the sentinel (or
nothing), so the wrapper can parse it cleanly.

## Development

    swift build          # debug build
    swift test           # run the unit tests
    swift build -c release

Unit tests cover the decision logic, `cd`/`export` detection, prompt/context
assembly, the executor, and the wrapper file contents. The live model path is
verified by manual smoke tests (see `docs/superpowers/plans/`).
