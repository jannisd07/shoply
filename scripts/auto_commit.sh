#!/bin/bash
# Auto-commit script for Shoply
# Prevents losing uncommitted Copilot/Windsurf session work
# Runs via cron every 30 minutes
# 
# Install: crontab -e → */30 * * * * /Users/jannisdietrich/Documents/shoply-neu/scripts/auto_commit.sh

REPO_DIR="/Users/jannisdietrich/Documents/shoply-neu"
LOG_FILE="$REPO_DIR/scripts/auto_commit.log"

cd "$REPO_DIR" || exit 1

# Only run if there are uncommitted changes to tracked .dart or .swift files
CHANGES=$(git diff --name-only -- '*.dart' '*.swift' '*.pbxproj' | wc -l | tr -d ' ')
STAGED=$(git diff --cached --name-only -- '*.dart' '*.swift' '*.pbxproj' | wc -l | tr -d ' ')

TOTAL=$((CHANGES + STAGED))

if [ "$TOTAL" -gt 0 ]; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Stage all modified tracked files (not untracked)
    git add -u -- '*.dart' '*.swift' '*.pbxproj'
    
    # Commit with auto-save message
    git commit -m "auto-save: $TIMESTAMP ($TOTAL files changed)" --no-verify
    
    # Push silently
    git push origin main --quiet 2>/dev/null
    
    echo "[$TIMESTAMP] Auto-committed $TOTAL changed files" >> "$LOG_FILE"
else
    # No changes, do nothing
    :
fi
