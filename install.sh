#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.claude/theme-sync"
PLIST_NAME="com.claude.theme-sync.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "=== Claude Theme Sync Installer ==="
echo ""

# Create install directory
mkdir -p "$INSTALL_DIR"

# Copy source and build
echo "Step 1: Building..."
cp "$SCRIPT_DIR/ClaudeThemeSync.swift" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/build.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/tmux-theme-inject.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/build.sh" "$INSTALL_DIR/uninstall.sh" "$INSTALL_DIR/tmux-theme-inject.sh"
"$INSTALL_DIR/build.sh"
echo ""

# Create LaunchAgents directory if needed
mkdir -p "$LAUNCH_AGENTS_DIR"

# Unload existing agent if running
if launchctl list 2>/dev/null | grep -q "com.claude.theme-sync"; then
    echo "Step 2: Stopping existing agent..."
    launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
fi

# Generate plist with correct paths
echo "Step 3: Installing launch agent..."
cat > "$LAUNCH_AGENTS_DIR/$PLIST_NAME" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.theme-sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/claude-theme-sync</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/claude-theme-sync.log</string>
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/claude-theme-sync.log</string>
</dict>
</plist>
EOF

# Load agent
echo "Step 4: Starting agent..."
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Claude Theme Sync is now running and will start automatically on login."
echo "tmux injection is enabled automatically for running Claude Code panes."
echo ""
echo "Commands:"
echo "  Check status:  launchctl list | grep claude"
echo "  View logs:     tail -f $INSTALL_DIR/claude-theme-sync.log"
echo "  Uninstall:     $INSTALL_DIR/uninstall.sh"
