#!/bin/bash
# tmux-theme-inject.sh — Inject /theme <dark|light> into all Claude Code tmux panes
# Called by the ClaudeThemeSync daemon after updating ~/.claude.json

THEME="$1"

# Validate argument
if [[ "$THEME" != "dark" && "$THEME" != "light" ]]; then
    echo "tmux inject: Error: invalid theme '$THEME' (expected 'dark' or 'light')"
    exit 1
fi

# Check if tmux is running
if ! tmux info &>/dev/null; then
    echo "tmux inject: tmux is not running, skipping injection"
    exit 0
fi

# Find all panes where the foreground process is exactly "claude"
PANES=$(tmux list-panes -a -F "#{pane_id} #{pane_current_command}" | awk '$2 == "claude" { print $1 }')

# Count matched panes
PANE_COUNT=$(echo "$PANES" | grep -c '%' || true)

if [[ "$PANE_COUNT" -eq 0 ]]; then
    echo "tmux inject: No Claude Code panes found, nothing to inject"
    exit 0
fi

echo "tmux inject: Found $PANE_COUNT Claude Code pane(s), injecting /theme $THEME..."

# Inject into each pane
for PANE_ID in $PANES; do
    # Verify pane still exists (race condition guard)
    if tmux display-message -t "$PANE_ID" -p "#{pane_id}" &>/dev/null; then
        tmux send-keys -t "$PANE_ID" "/theme $THEME" Enter
        echo "tmux inject: -> Injected into pane $PANE_ID"
    else
        echo "tmux inject: -> Pane $PANE_ID no longer exists, skipped"
    fi
done

echo "tmux inject: Done"
