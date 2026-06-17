# slop

> **Sloppy. Crappy unix commands that work.**

Type a rough command or plain English; `slop` uses Apple's on-device Foundation
Models to produce the right shell command, then runs it (when safe and
confident) or shows it for confirmation.

100% on-device. No API keys, no network, private. Requires macOS 26+,
Apple Silicon, Apple Intelligence enabled.

## Install

### Homebrew (recommended)

    brew install drewmccormack/slop/slop

Then add the wrapper to your shell (Homebrew prints this in its caveats too):

    echo 'source "$(brew --prefix)/share/slop/slop.sh"' >> ~/.zshrc   # or ~/.bashrc

Open a new shell. The formula builds from source, so you need the Xcode Command
Line Tools (`xcode-select --install`).

### From a clone

    ./install.sh

Builds the release binary, installs `slop-bin` to `~/.local/bin`, and adds a
`source` line to your `.zshrc` and `.bashrc` when present.

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

### Glob behavior

- **zsh**: unquoted globs survive — the `slop` alias applies `noglob` at the
  call site, so `slop cp *.m dir/` reaches the binary with `*.m` intact.
- **bash**: unquoted globs are expanded by bash before slop runs; **quote**
  commands containing globs in bash, e.g. `slop 'cp *.m dir/'`.
- **Both shells**: pipes and redirects always require quoting (see above).

`cd` and `export` take effect in your live shell: the binary writes the command
to a temp file (`SLOP_EVAL_FILE`) and the shell wrapper `eval`s it in the
current session. Verified working in both zsh and bash. (Because model output
is non-deterministic, a borderline `cd` request is occasionally proposed rather
than auto-run; just press Enter to confirm.)

## How it works

1. The shell wrapper (`shell/slop.sh`) runs `slop-bin` with stdin/stdout/stderr
   all going straight to the terminal — nothing is captured.
2. `slop-bin` checks the on-device model is available, then asks it to either
   repair a sloppy command or translate English, returning a structured result:
   `{ command, explanation, confidence, isDestructive }`.
3. A pure decision rule picks the action: **run** iff `confidence == high && !isDestructive`,
   otherwise **propose**.
4. Non-`cd`/`export` commands run via `$SHELL -c` with output streamed straight
   to your terminal. `cd`/`export` are written to a temp file (`SLOP_EVAL_FILE`)
   which the wrapper `eval`s in your live shell. When run standalone (no wrapper),
   the binary falls back to a `__SLOP_EVAL__` sentinel on stdout.

All prompts and echoes go to stderr.

## Development

    swift build          # debug build
    swift test           # run the unit tests
    swift build -c release

Unit tests cover the decision logic, `cd`/`export` detection, prompt/context
assembly, the executor, and the wrapper file contents. The live model path is
verified by manual smoke tests (see `docs/superpowers/plans/`).
