# Slop

> **AI slop comes to a command line near you.** 
>
> Let AI help with your crappy grasp of UNIX.

Can't remember the arguments to that damned command again? Git got your tongue? Just get sloppy, and let AI sort it out.

Don't get down — get even. Pass your human-generated slop in and let AI sort it out. With this one tool, you'll be a command-line legend!

`slop` is a language model wedged between you and your shell. You hand
it a half-assed command you sorta/kinda remember, or you give up completely and just go with prose. It mulls it over, and offers to run what it thinks you meant.

    slop cp *.m My Documents/          # almost right
    slop copy the m files into dir     # I give up
    slop cd to the lip reading project # I can't even be bothered finding the damn dir
	slop rm -rf ~/*				       # Sure about that?

Most stuff just runs immediately. Anything that could ruin your afternoon — `rm`, an
overwrite, `sudo` — stops, shows you the command and a sentence
of plain English, and waits for you to agree to it. The slop has standards. They're low
standards, but it has them.

It really wants OpenAI for a brain. Set `OPENAI_API_KEY` and it uses that; the
results go from "amusing" to "actually correct." There's an on-device fallback
(Apple's model, no key, nothing leaves your Mac) for when you have no key or no
signal, but it's a 3B model that struggles with anything beyond the obvious — fine
in a pinch, not the main event. See [Picking a brain](#picking-a-brain).

## Get slop into your machine

### Homebrew (the civilised way)

    brew install drewmccormack/slop/slop

Then bless your shell with the wrapper (Homebrew nags you about this too):

    echo 'source "$(brew --prefix)/share/slop/slop.sh"' >> ~/.zshrc   # or ~/.bashrc

Open a new shell. It builds from source, so you'll
need the Xcode Command Line Tools (`xcode-select --install`).

### From a clone (for the brave / the offline)

    ./install.sh

Builds the release binary, drops `slop-bin` into `~/.local/bin`, and slips a
`source` line into your `.zshrc` and `.bashrc` while you're not looking.

## Sloppin' around

When `slop` is feeling sure of itself, it just runs the thing, echoing the
command dim first (e.g. `$ ls`) so you can nod sagely as if you were about to type
that. When it's unsure, or the command could draw blood, it stops, shows you the
command and a plain-English description, and waits at `[Y/n/e]`:

- **Y** / Enter — do it, you magnificent coward
- **n** — abort, pretend this never happened
- **e** — edit the command first, then run what you save

Anything that deletes, overwrites, moves, force-pushes, or needs `sudo` *always*
asks first. That promise doesn't depend on the model spotting the danger — a
deterministic gate catches the usual suspects (`rm -rf`, `sudo`, `dd`, `mkfs`,
`git push --force`, `chmod -R`, truncating `>`, piping `curl` into a shell, the
fork bomb) and stops them no matter how breezily confident the model was.

Two flags for the nervous:

- `--dry-run` / `-n` — work out the command and show it, plus whether it would
  run or pause, then stop without touching anything.
- `--prompt` / `-i` — make it ask `[Y/n/e]` for *everything*, even the commands
  it would otherwise be sure about.

## Picking a brain

There are two backends, and they are not equals.

**OpenAI (the one you want).** Set `OPENAI_API_KEY` in your environment and slop
will offer to use it. The first time, it tells you what that means — your command
and the current directory's file listing get sent to OpenAI — and asks whether to
make it the default. Your answer is remembered in `~/.config/slop/consent`. This
is the version that actually produces correct, idiomatic commands. Override the
model with `SLOP_OPENAI_MODEL` (defaults to `gpt-5.5`).

**On-device (the fallback).** With no key — or no internet — slop uses Apple's
on-device model. Nothing leaves your Mac, which is lovely, but it's a small model
and it shows: it handles the obvious cases and flails at anything that needs real
composition. Treat it as the offline spare tyre. Requires macOS 26+, Apple
Silicon, and Apple Intelligence turned on.

Force one for a single command, without changing your default:

- `--llm=openai` — use OpenAI this once.
- `--llm=apple` — use the on-device model this once.

### When to use quotes (a brief, grudging dose of reality)

The slop is powerful but it is not a wizard, and your shell gets first crack at
your commands. Bare globs and plain English are fine. But the moment you reach for
a pipe, a redirect, or `&&`, wrap the whole thing in quotes so `slop` gets a good wiff:

    slop 'wc -l *.swift | tail -1'

Why: your shell parses `|` and `>` as grammar first. Quotes hand
the line over untouched. (Blame Ken Thompson.)

### Globs, specifically

- **zsh**: bare globs survive. The `slop` alias slaps `noglob` on at the call
  site, so `slop cp *.m dir/` reaches the binary with `*.m` gloriously intact.
- **bash**: bash expands globs before slop awakens, so **quote** them:
  `slop 'cp *.m dir/'`. (bash has no call-site `noglob`.)
- **Both**: pipes and redirects always want quotes. See above. We warned you.

`cd` and `export` actually move your real shell — the binary writes the command
to a temp file (`SLOP_EVAL_FILE`) and the wrapper `eval`s it in your live
session, because a child process changing its parent's directory is otherwise
one of those things unix simply refuses to let you have. Works in zsh and bash.
(The model is non-deterministic, so a borderline `cd` is occasionally proposed
instead of auto-run. Just hit Enter and move on with your life.)

## How the sausage is made

For the morbidly curious who want to know what's running their `rm`:

1. The shell wrapper (`shell/slop.sh`) runs `slop-bin` with stdin/stdout/stderr
   going straight to your terminal. Nothing is captured, nothing is hidden.
2. `slop-bin` picks a model (OpenAI if you have a key and said yes, otherwise the
   on-device one), then hands it your input and asks it to either repair a sloppy
   command or translate your English, returning a tidy little verdict:
   `{ command, explanation, confidence, isDestructive }`.
3. A dumb, honest rule decides what happens: **run** only if `confidence == high && !isDestructive`
   *and* a deterministic danger gate finds nothing alarming in the command;
   otherwise **propose** and let you be the adult. The gate is the part that
   doesn't trust the model.
4. Ordinary commands run via `$SHELL -c` with output streamed straight to you.
   `cd`/`export` go through the temp-file (`SLOP_EVAL_FILE`) ritual described
   above. Run it standalone with no wrapper and it falls back to a `__SLOP_EVAL__`
   sentinel on stdout, for the three people who will ever do that.

All prompts and echoes go to stderr, so piping still behaves.

## Development (yes, there are actually tests)

    swift build          
    swift test        
    swift build -c release

Tests cover the decision logic, `cd`/`export` detection, prompt/context
assembly, the executor, and the wrapper file contents. The live-model path is
verified by manual smoke tests, because mocking a neural network to assert it
returns `ls` is a special kind of madness. 
