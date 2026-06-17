# slop

> **AI slop comes to the command line.**
>
> An AI command that fixes your human-generated slop.

It was always going to end up in the terminal. AI slop took the art, then the
prose, then the corporate apology for the last batch of AI slop, and the shell
prompt was the obvious next thing to colonise. The twist is that this particular
slop is pointed the other way: it cleans up after you.

`slop` is an on-device language model wedged between you and your shell. You hand
it a command you half-remember, or a sentence, or the general direction of a
command, and it quietly works out what you meant and runs it:

    slop cp *.m dir/                  # the command you almost remember
    slop copy the m files into dir    # the sentence you'd rather type
    slop cd to the lip reading project

It runs entirely on Apple's on-device model, which means none of this reaches the
network, your employer, or the permanent record. Whatever you cannot remember
about `tar` stays between you and a neural network that has, mercifully, no
opinions and no memory.

Most things just run. Anything that could ruin your afternoon — `rm`, an
overwrite, `sudo`, that whole family — stops, shows you the command and a sentence
of plain English, and waits for you to agree to it. The slop has standards. Low
ones, but standards.

Entirely on-device. No API keys, no network, no telemetry, no modal explaining
how much it values your privacy. Nothing leaves your Mac that wasn't going to
leave anyway. Requires macOS 26+, Apple Silicon, and Apple Intelligence turned on.

## Get the slop into your machine

### Homebrew (the civilised way)

    brew install drewmccormack/slop/slop

Then bless your shell with the wrapper (Homebrew nags you about this too):

    echo 'source "$(brew --prefix)/share/slop/slop.sh"' >> ~/.zshrc   # or ~/.bashrc

Open a new shell. It builds from source like a real artisanal slop, so you'll
need the Xcode Command Line Tools (`xcode-select --install`).

### From a clone (for the brave / the offline)

    ./install.sh

Builds the release binary, drops `slop-bin` into `~/.local/bin`, and slips a
`source` line into your `.zshrc` and `.bashrc` while you're not looking.

## Sloppin' around

When `slop` is feeling sure of itself, it just runs the thing, echoing the
command dim first (e.g. `$ ls`) so you can nod sagely as if you'd have typed
that. When it's unsure, or the command could draw blood, it stops, shows you the
command and a plain-English description, and waits at `[Y/n/e]`:

- **Y** / Enter — do it, you magnificent coward
- **n** — abort, pretend this never happened
- **e** — edit the command first, then run what you save

Anything that deletes, overwrites, moves, force-pushes, or needs `sudo` *always*
asks first, no matter how confident the slop feels. The slop is sloppy, not
homicidal.

### When to use quotes (a brief, grudging dose of reality)

The slop is powerful but it is not a wizard, and your shell gets first crack at
your typing. Bare globs and plain English are fine. But the moment you reach for
a pipe, a redirect, or `&&`, wrap the whole thing in quotes or the shell will eat
it before `slop` smells it:

    slop 'wc -l *.swift | tail -1'

Why: your shell parses `|` and `>` as grammar before `slop` exists. Quotes hand
the line over untouched. Blame Ken Thompson, not us.

### Globs, specifically

- **zsh**: bare globs survive. The `slop` alias slaps `noglob` on at the call
  site, so `slop cp *.m dir/` reaches the binary with `*.m` gloriously intact.
- **bash**: bash expands globs before slop wakes up, so **quote** them:
  `slop 'cp *.m dir/'`. (bash has no call-site `noglob`. Take it up with bash.)
- **Both**: pipes and redirects always want quotes. See above. We warned you.

`cd` and `export` actually move your real shell — the binary writes the command
to a temp file (`SLOP_EVAL_FILE`) and the wrapper `eval`s it in your live
session, because a child process changing its parent's directory is otherwise
one of those things unix simply refuses to let you have. Works in zsh and bash.
(The model is non-deterministic, so a borderline `cd` is occasionally proposed
instead of auto-run. Just hit Enter and move on with your life.)

## How the sausage is slopped

For the morbidly curious who want to know what's running their `rm`:

1. The shell wrapper (`shell/slop.sh`) runs `slop-bin` with stdin/stdout/stderr
   going straight to your terminal. Nothing is captured, nothing is hidden.
2. `slop-bin` confirms the on-device model is awake, then hands it your input and
   asks it to either repair a sloppy command or translate your English, returning
   a tidy little verdict: `{ command, explanation, confidence, isDestructive }`.
3. A dumb, honest rule decides what happens: **run** if `confidence == high && !isDestructive`,
   otherwise **propose** and let you be the adult.
4. Ordinary commands run via `$SHELL -c` with output streamed straight to you.
   `cd`/`export` go through the temp-file (`SLOP_EVAL_FILE`) ritual described
   above. Run it standalone with no wrapper and it falls back to a `__SLOP_EVAL__`
   sentinel on stdout, for the three people who will ever do that.

All prompts and echoes go to stderr, so piping still behaves.

## Development (yes, there are actually tests)

    swift build          # debug build
    swift test           # 21 of them, and they pass, thank you very much
    swift build -c release

Tests cover the decision logic, `cd`/`export` detection, prompt/context
assembly, the executor, and the wrapper file contents. The live-model path is
verified by manual smoke tests, because mocking a neural network to assert it
returns `ls` is a special kind of madness. See `docs/superpowers/plans/`.
