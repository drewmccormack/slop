# slop shell wrapper — source this from .zshrc / .bashrc
# Provides `slop`. Real command output streams straight to your terminal.
# cd/export are written by the binary to a temp file (SLOP_EVAL_FILE) which we
# eval in the current shell, so they affect your live session.
#
# Unquoted globs: in zsh the `slop` alias applies `noglob` at the call site, so
# `slop cp *.m dir/` reaches the binary with `*.m` intact. bash has no call-site
# noglob, so in bash quote commands that contain globs/pipes/redirects.

_slop() {
    local evalfile rc
    evalfile="$(mktemp "${TMPDIR:-/tmp}/slop-eval.XXXXXX")"
    SLOP_EVAL_FILE="$evalfile" slop-bin "$@"
    rc=$?
    if [ -s "$evalfile" ]; then
        eval "$(cat "$evalfile")"
    fi
    rm -f "$evalfile"
    return $rc
}

# Define the `slop` entry point as an alias in both shells. Using an alias
# (rather than a `slop()` function in the else-branch) avoids a zsh parse error:
# zsh parses the whole file at source time, and a literal `slop() { ... }` would
# collide with the alias defined above it.
if [ -n "$ZSH_VERSION" ]; then
    # zsh: noglob at the call site preserves unquoted globs (e.g. slop cp *.m d/).
    alias slop='noglob _slop'
else
    # bash and other shells: no call-site noglob, so quote commands containing
    # globs/pipes/redirects (e.g. slop 'cp *.m d/').
    alias slop='_slop'
fi
