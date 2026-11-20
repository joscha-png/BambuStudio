#!/bin/bash
# Install a locally built BambuStudio (./BuildLinux.sh -s) for the current user, without root.
#
# Layout:
#   ~/.local/opt/BambuStudio/{bin/bambu-studio, bin/*.so*, resources/, bambu-studio}
#   ~/.local/bin/bambu-studio                        -> launcher symlink
#   ~/.local/share/applications/BambuStudio.desktop
#   ~/.local/share/icons/hicolor/{128x128,scalable}/apps/BambuStudio.*
#
# Usage: ./InstallLinux.sh [-u]   (-u: uninstall)

set -e

ROOT=$(dirname "$(readlink -f "$0")")
DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
DEST=$HOME/.local/opt/BambuStudio
BIN_LINK=$HOME/.local/bin/bambu-studio
DESKTOP=$DATA_HOME/applications/BambuStudio.desktop
ICON_DIR=$DATA_HOME/icons/hicolor

refresh_caches() {
    command -v update-desktop-database >/dev/null && update-desktop-database "$DATA_HOME/applications" 2>/dev/null || true
    command -v gtk-update-icon-cache  >/dev/null && gtk-update-icon-cache -q "$ICON_DIR" 2>/dev/null || true
}

if [[ "$1" == "-u" ]]; then
    rm -rf "$DEST"
    rm -f "$BIN_LINK" "$DESKTOP" "$ICON_DIR/128x128/apps/BambuStudio.png" "$ICON_DIR/scalable/apps/BambuStudio.svg"
    refresh_caches
    echo "BambuStudio uninstalled (user config in ~/.config/BambuStudio was kept)."
    exit 0
fi

if [[ -n "$1" ]]; then
    echo "Usage: $0 [-u]"
    exit 1
fi

BINARY=$ROOT/build/src/bambu-studio
if [[ ! -x "$BINARY" ]]; then
    echo "ERROR: $BINARY not found. Build it first with ./BuildLinux.sh -sr"
    exit 1
fi

echo "Installing BambuStudio to $DEST ..."
rm -rf "$DEST"
mkdir -p "$DEST/bin" "$(dirname "$BIN_LINK")" "$DATA_HOME/applications" \
         "$ICON_DIR/128x128/apps" "$ICON_DIR/scalable/apps"

cp -a "$ROOT/resources" "$DEST/resources"
cp -a "$BINARY" "$DEST/bin/"
cp -a "$ROOT"/build/src/*.so* "$DEST/bin/" 2>/dev/null || true

cat > "$DEST/bambu-studio" <<'EOF'
#!/bin/bash
DIR=$(readlink -f "$0" | xargs dirname)
export LD_LIBRARY_PATH="$DIR/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# Upstream workaround: BambuStudio can segfault on Arch-based distros with non-C locales
export LC_ALL=C
exec "$DIR/bin/bambu-studio" "$@"
EOF
chmod +x "$DEST/bambu-studio"
ln -sf "$DEST/bambu-studio" "$BIN_LINK"

cp "$ROOT/resources/images/BambuStudio_128px.png" "$ICON_DIR/128x128/apps/BambuStudio.png"
cp "$ROOT/resources/images/BambuStudio.svg"       "$ICON_DIR/scalable/apps/BambuStudio.svg"
sed "s|^Exec=.*|Exec=$BIN_LINK %U|" "$ROOT/src/platform/unix/BambuStudio.desktop" > "$DESKTOP"
refresh_caches

MISSING=$(LD_LIBRARY_PATH="$DEST/bin" ldd "$DEST/bin/bambu-studio" | grep "not found" || true)
if [[ -n "$MISSING" ]]; then
    echo "WARNING: missing shared libraries:"
    echo "$MISSING"
fi

echo "done. Start with 'bambu-studio' or from the application menu."
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "NOTE: $HOME/.local/bin is not in your PATH." ;;
esac
