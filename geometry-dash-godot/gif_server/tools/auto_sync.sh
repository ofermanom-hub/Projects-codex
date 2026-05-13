#!/usr/bin/env bash
# Auto-sync GIF curator data to GitHub. Run by launchd every 60s.
# Stages pool.json, candidates.json, gphotos_candidates.json, pending_subjects.json,
# and the frames/ tree. Commits + pushes only if something actually changed.
#
# Logs to /tmp/gif-curator-sync.log

set -uo pipefail
exec >> /tmp/gif-curator-sync.log 2>&1

REPO="/Users/ofer/Projects codex"
LOCK="/tmp/gif-curator-sync.pid"

# Single-instance: bail if a previous run is still alive (macOS has no flock).
if [[ -f "$LOCK" ]] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
    echo "[$(date '+%F %T')] previous run still active; skipping"
    exit 0
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

cd "$REPO" || { echo "[$(date '+%F %T')] repo path missing"; exit 1; }

# Stage curator outputs. Errors swallowed so missing paths don't abort.
git add \
    "geometry-dash-godot/gif_server/data/pool.json" \
    "geometry-dash-godot/gif_server/data/candidates.json" \
    "geometry-dash-godot/gif_server/data/gphotos_candidates.json" \
    "geometry-dash-godot/gif_server/data/pending_subjects.json" \
    "geometry-dash-godot/gif_server/data/frames/" \
    2>/dev/null || true

# Nothing staged → nothing to do.
if git diff --cached --quiet; then
    exit 0
fi

# Count change scope for the commit message.
STATS=$(git diff --cached --shortstat)
TS=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TS] sync triggered: $STATS"

git -c user.name="gif-curator-autosync" \
    -c user.email="autosync@local" \
    commit -m "auto-sync $TS — $STATS" >/dev/null

if git push origin main; then
    echo "[$TS] push ok"
else
    echo "[$TS] push FAILED — will retry next run"
    # Don't reset the commit — next push retries it.
    exit 1
fi
