#!/bin/bash
# Backs up settings files that install.sh may overwrite.
# Run this BEFORE install.sh to preserve your existing configuration.
#
# Usage: ./backup-settings.sh [backup-dir]
# Default backup directory: ~/claude-code-bedrock-backup/<timestamp>

set -e

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${1:-$HOME/claude-code-bedrock-backup/$TIMESTAMP}"

FILES=(
    "$HOME/.claude/settings.json"
    "$HOME/.aws/config"
    "$HOME/claude-code-with-bedrock/config.json"
)

echo "======================================"
echo "  Claude Code - Settings Backup"
echo "======================================"
echo
echo "Backup destination: $BACKUP_DIR"
echo

mkdir -p "$BACKUP_DIR"

backed_up=0
skipped=0

for FILE in "${FILES[@]}"; do
    if [ -f "$FILE" ]; then
        REL="${FILE#$HOME/}"
        DEST="$BACKUP_DIR/$REL"
        mkdir -p "$(dirname "$DEST")"
        cp "$FILE" "$DEST"
        echo "  [BACKED UP] $FILE"
        echo "           -> $DEST"
        ((backed_up++))
    else
        echo "  [NOT FOUND] $FILE  (skipped)"
        ((skipped++))
    fi
    echo
done

echo "======================================"
if [ $backed_up -gt 0 ]; then
    echo "  $backed_up file(s) backed up to:"
    echo "  $BACKUP_DIR"
fi
if [ $skipped -gt 0 ]; then
    echo "  $skipped file(s) not found (nothing to back up)"
fi
echo "======================================"
echo
echo "To restore, run: ./uninstall.sh $BACKUP_DIR"
echo
