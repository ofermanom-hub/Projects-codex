#!/usr/bin/env bash
set -euo pipefail

PROJ="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VENV="$PROJ/.venv"
PYTHON="$VENV/bin/python"
ZSHRC="$HOME/.zshrc"
PLIST="$HOME/Library/LaunchAgents/com.ofer.token-tracker.plist"
LOGDIR="$HOME/Library/Logs/token-tracker"

echo "==> Creating Python venv..."
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet -r "$PROJ/requirements.txt"
echo "    done."

# ── Shell wrapper ─────────────────────────────────────────────────────────────
MARKER="# claude-token-tracker"
if ! grep -q "$MARKER" "$ZSHRC" 2>/dev/null; then
    echo "" >> "$ZSHRC"
    cat >> "$ZSHRC" <<ZSHBLOCK
$MARKER
_TRACKER_PY="$PYTHON"
_TRACKER_SCRIPT="$PROJ/tracker.py"
function claude() {
    if [[ -n "\$TMUX" ]]; then
        local _tracker_pane
        _tracker_pane=\$(tmux split-window -v -l 6 -P -F "#{pane_id}" \
            "\$_TRACKER_PY \$_TRACKER_SCRIPT watch" 2>/dev/null)
        tmux select-pane -l 2>/dev/null
        command claude "\$@"
        tmux kill-pane -t "\$_tracker_pane" 2>/dev/null || true
    else
        "\$_TRACKER_PY" "\$_TRACKER_SCRIPT" 2>/dev/null || true
        command claude "\$@"
    fi
}
ZSHBLOCK
    echo "==> Added 'claude' shell wrapper to $ZSHRC"
else
    echo "==> Shell wrapper already present in $ZSHRC (skipping)"
fi

# ── .env setup ────────────────────────────────────────────────────────────────
if [[ ! -f "$PROJ/.env" ]]; then
    cp "$PROJ/.env.example" "$PROJ/.env"
    echo "==> Created $PROJ/.env — edit it and add your ANTHROPIC_ADMIN_API_KEY"
fi

# ── launchd plist (HTTP server for iOS Shortcut) ──────────────────────────────
mkdir -p "$LOGDIR"
mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>             <string>com.ofer.token-tracker</string>
  <key>ProgramArguments</key>
  <array>
    <string>$PYTHON</string>
    <string>$PROJ/tracker.py</string>
    <string>serve</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key> <string>/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>RunAtLoad</key>          <true/>
  <key>KeepAlive</key>          <true/>
  <key>StandardOutPath</key>    <string>$LOGDIR/out.log</string>
  <key>StandardErrorPath</key>  <string>$LOGDIR/err.log</string>
</dict>
</plist>
PLIST

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load  "$PLIST"
echo "==> HTTP server registered as launchd agent (port 8765, starts at login)"

# ── iOS Shortcut instructions ─────────────────────────────────────────────────
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "YOUR_MAC_IP")
PORT=$(grep -A2 '^\[server\]' "$PROJ/config.toml" | grep port | awk -F= '{print $2}' | tr -d ' ')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  iOS Shortcut setup (home-screen push button)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. Open Shortcuts app on iPhone"
echo "  2. Tap + → Add Action → search 'URL'"
echo "     URL:  http://$LOCAL_IP:$PORT/push"
echo "  3. Add action: 'Get Contents of URL' (method: GET)"
echo "  4. Long-press shortcut → Add to Home Screen"
echo ""
echo "  Tapping the icon will push a Claude usage notification"
echo "  to ntfy topic: ofer-claude-gd"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "==> Next: add your Admin API key to $PROJ/.env"
echo "    Get one at: https://console.anthropic.com/settings/admin-keys"
echo ""
echo "==> Test: python $PROJ/tracker.py"
echo "          python $PROJ/tracker.py --notify"
