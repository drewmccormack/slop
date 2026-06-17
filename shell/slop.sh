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

if [ -n "$ZSH_VERSION" ]; then
    alias slop='noglob _slop'
else
    # bash (and other shells): no call-site noglob available; quote globbed
    # commands. _slop is the entry point.
    slop() { _slop "$@"; }
fi
