#!/bin/sh
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

echo "Building slop (release)..."
swift build -c release --package-path "$ROOT"
cp "$ROOT/.build/release/slop" "$BIN_DIR/slop-bin"
echo "Installed binary to $BIN_DIR/slop-bin"

WRAPPER="$ROOT/shell/slop.sh"
MARKER="# >>> slop wrapper >>>"
LINE="source \"$WRAPPER\""

add_to_rc() {
    rc="$1"
    [ -f "$rc" ] || return 0
    if grep -qF "$MARKER" "$rc"; then
        echo "Already configured in $rc"
    else
        {
            echo ""
            echo "$MARKER"
            echo "export PATH=\"$BIN_DIR:\$PATH\""
            echo "$LINE"
            echo "# <<< slop wrapper <<<"
        } >> "$rc"
        echo "Configured $rc"
    fi
}

add_to_rc "$HOME/.zshrc"
add_to_rc "$HOME/.bashrc"

echo "Done. Open a new shell (or 'source' your rc) and try: slop list files here"
