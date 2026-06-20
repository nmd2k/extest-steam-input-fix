#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="$DIR/target/i686-unknown-linux-gnu/release/libextest.so"
INSTALL_LIB="$HOME/.local/lib/libextest.so"
WRAPPER="$HOME/.local/bin/steam-extest"
DESKTOP="$HOME/.local/share/applications/steam.desktop"

# Check for pre-built library
if [ ! -f "$LIB" ]; then
    echo "No pre-built library found at $LIB"
    echo "Checking $INSTALL_LIB..."
    if [ -f "$INSTALL_LIB" ]; then
        LIB="$INSTALL_LIB"
        echo "Using already installed library: $LIB"
    else
        echo "Building extest..."
        if ! command -v cargo &>/dev/null; then
            echo "ERROR: Rust/cargo not found. Install Rust: https://rustup.rs"
            exit 1
        fi
        rustup target add i686-unknown-linux-gnu 2>/dev/null || true
        cargo build --release
        if [ ! -f "$LIB" ]; then
            echo "ERROR: Build failed"
            exit 1
        fi
    fi
fi

# Install library
mkdir -p "$HOME/.local/lib"
cp "$LIB" "$INSTALL_LIB"
echo "Installed $INSTALL_LIB"

# Create wrapper script
mkdir -p "$HOME/.local/bin"
cat > "$WRAPPER" << WRAPPEREOF
#!/bin/bash
export LD_PRELOAD="$INSTALL_LIB"
exec /usr/bin/steam "\$@"
WRAPPEREOF
chmod +x "$WRAPPER"
echo "Created wrapper: $WRAPPER"

# Create desktop file override
mkdir -p "$HOME/.local/share/applications"
if [ -f /usr/share/applications/steam.desktop ]; then
    cp /usr/share/applications/steam.desktop "$DESKTOP"
    sed -i 's|^Exec=/usr/bin/steam %U|Exec='"$WRAPPER"' %U|' "$DESKTOP"
    update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
    echo "Desktop override created: $DESKTOP"
    echo ""
    echo "Setup complete!"
    echo "  Terminal:  LD_PRELOAD=$INSTALL_LIB steam"
    echo "  App menu:  restart GNOME Shell (Alt+F2) or log out/in to refresh"
    echo ""
    echo "Verify it's working: no 'XTest extension doesn't exist' in ~/.local/share/Steam/logs/console-linux.txt"
else
    echo "WARNING: /usr/share/applications/steam.desktop not found"
    echo "Launch Steam manually with: LD_PRELOAD=$INSTALL_LIB steam"
fi
