#!/bin/bash
# Octave Update Script
# Checks for updates from GitHub on startup, but doesn't block if offline

OCTAVE_DIR="/home/rob/Roxy/octave"
TIMEOUT_SECONDS=10
LOG_FILE="/home/rob/Roxy/update.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Update check started"

# Quick connectivity check (2 second timeout)
if ! timeout 2 ping -c 1 github.com &>/dev/null; then
    log "No internet connection, skipping update"
    exit 0
fi

cd "$OCTAVE_DIR" || { log "Failed to cd to $OCTAVE_DIR"; exit 0; }

# Fetch with timeout
if ! timeout "$TIMEOUT_SECONDS" git fetch origin main &>/dev/null; then
    log "Git fetch timed out or failed, skipping update"
    exit 0
fi

# Check if we're behind
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
    log "Already up to date"
    exit 0
fi

# We're behind, reset to remote (handles force pushes)
log "Update available, resetting to remote..."
if timeout "$TIMEOUT_SECONDS" git reset --hard origin/main; then
    log "Update successful: $(git log -1 --oneline)"
else
    log "Git reset failed"
fi

exit 0
