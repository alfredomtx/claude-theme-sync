#!/bin/bash
# tmux-theme-inject.sh — Inject /theme <dark|light> into all Claude Code tmux panes
# Called by the ClaudeThemeSync daemon after updating ~/.claude.json
#
# Usage: tmux-theme-inject.sh <dark|light> [skip-file]
#   skip-file: optional path to file of pane IDs to skip; new injections are appended

THEME="$1"
SKIP_FILE="$2"

# Validate argument
if [[ "$THEME" != "dark" && "$THEME" != "light" ]]; then
    echo "tmux inject: Error: invalid theme '$THEME' (expected 'dark' or 'light')"
    exit 1
fi

# Find tmux binary (launchd PATH may not include Homebrew)
TMUX=$(command -v tmux 2>/dev/null)
if [[ -z "$TMUX" ]]; then
    for p in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux; do
        if [[ -x "$p" ]]; then
            TMUX="$p"
            break
        fi
    done
fi

if [[ -z "$TMUX" ]]; then
    echo "tmux inject: tmux not found, skipping injection"
    exit 0
fi

# Check if tmux is running
if ! "$TMUX" info &>/dev/null; then
    echo "tmux inject: tmux is not running, skipping injection"
    exit 0
fi

# Find all panes where the foreground process is exactly "claude"
PANES=$("$TMUX" list-panes -a -F "#{pane_id} #{pane_current_command}" | awk '$2 == "claude" { print $1 }')

# Count matched panes
PANE_COUNT=$(echo "$PANES" | grep -c '%' || true)

if [[ "$PANE_COUNT" -eq 0 ]]; then
    echo "tmux inject: No Claude Code panes found"
    exit 0
fi

INJECTED=0
SKIPPED=0

for PANE_ID in $PANES; do
    # Skip if already injected in a previous run (checked via skip file)
    if [[ -n "$SKIP_FILE" && -f "$SKIP_FILE" ]] && grep -qxF "$PANE_ID" "$SKIP_FILE"; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Verify pane still exists (race condition guard)
    if "$TMUX" display-message -t "$PANE_ID" -p "#{pane_id}" &>/dev/null; then
        "$TMUX" send-keys -t "$PANE_ID" "/theme $THEME" Enter
        echo "tmux inject: -> Injected into pane $PANE_ID"
        INJECTED=$((INJECTED + 1))
        # Record as injected
        [[ -n "$SKIP_FILE" ]] && echo "$PANE_ID" >> "$SKIP_FILE"
    else
        echo "tmux inject: -> Pane $PANE_ID no longer exists, skipped"
    fi
done

if [[ "$INJECTED" -gt 0 ]]; then
    echo "tmux inject: Injected into $INJECTED new pane(s)"
elif [[ "$SKIPPED" -gt 0 ]]; then
    echo "tmux inject: All $SKIPPED pane(s) already injected"
fi

echo "tmux inject: Done"
