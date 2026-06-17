# slop shell wrapper — source this from .zshrc / .bashrc
# Provides the `slop` function: preserves unquoted globs, and evals cd/export
# in the current shell when the binary requests it via the __SLOP_EVAL__ sentinel.

slop() {
    local out rc
    # Disable globbing so unquoted patterns like *.m reach the binary intact.
    if [ -n "$ZSH_VERSION" ]; then
        out="$(noglob slop-bin "$@")"
        rc=$?
    else
        set -f
        out="$(slop-bin "$@")"
        rc=$?
        set +f
    fi

    case "$out" in
        __SLOP_EVAL__\ *)
            eval "${out#__SLOP_EVAL__ }"
            ;;
        "")
            : # nothing on stdout (command ran with its own output going to the tty)
            ;;
        *)
            printf '%s\n' "$out"
            ;;
    esac
    return $rc
}
