#!/bin/bash
# Uninstalls Claude Code with Bedrock and optionally restores backed-up settings.
# See UNINSTALL.md for manual steps.
#
# Usage: ./uninstall.sh [backup-dir]
# If backup-dir is provided, you will be prompted per file to restore it.

set -e

BACKUP_DIR="${1:-}"

echo "======================================"
echo "  Claude Code - Uninstall"
echo "======================================"
echo

# ── Step 1: Remove installed binaries ─────────────────────────────────────────
if [ -d "$HOME/claude-code-with-bedrock" ]; then
    echo "Removing ~/claude-code-with-bedrock/ ..."
    rm -rf "$HOME/claude-code-with-bedrock"
    echo "  [REMOVED] ~/claude-code-with-bedrock/"
else
    echo "  [NOT FOUND] ~/claude-code-with-bedrock/  (skipped)"
fi
echo

# ── Step 2: Remove AWS profile entries ────────────────────────────────────────
AWS_CONFIG="$HOME/.aws/config"
if [ -f "$AWS_CONFIG" ]; then
    # Find all [profile ...] blocks whose credential_process points to claude-code-with-bedrock
    PROFILES=$(grep -B1 "claude-code-with-bedrock" "$AWS_CONFIG" 2>/dev/null \
        | grep "^\[profile " | sed 's/\[profile //;s/\]//' || true)

    if [ -n "$PROFILES" ]; then
        cp "$AWS_CONFIG" "${AWS_CONFIG}.bak"
        echo "  [BACKED UP] $AWS_CONFIG -> ${AWS_CONFIG}.bak"

        for PROFILE in $PROFILES; do
            # Remove the [profile NAME] block (up to the next blank line or EOF)
            sed -i.tmp "/^\[profile $PROFILE\]/,/^$/d" "$AWS_CONFIG"
            echo "  [REMOVED]   AWS profile '$PROFILE' from $AWS_CONFIG"
        done
        rm -f "${AWS_CONFIG}.tmp"
    else
        echo "  [NO MATCH]  No Claude Code profiles found in $AWS_CONFIG  (skipped)"
    fi
else
    echo "  [NOT FOUND] $AWS_CONFIG  (skipped)"
fi
echo

# ── Step 3: Remove Claude Code settings ───────────────────────────────────────
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ -f "$CLAUDE_SETTINGS" ]; then
    read -p "Remove $CLAUDE_SETTINGS? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$CLAUDE_SETTINGS"
        echo "  [REMOVED] $CLAUDE_SETTINGS"
    else
        echo "  [KEPT]    $CLAUDE_SETTINGS"
    fi
else
    echo "  [NOT FOUND] $CLAUDE_SETTINGS  (skipped)"
fi
echo

# ── Step 4: Restore from backup (if provided) ─────────────────────────────────
if [ -n "$BACKUP_DIR" ]; then
    echo "======================================"
    echo "  Restore from backup: $BACKUP_DIR"
    echo "======================================"
    echo

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "  ERROR: Backup directory not found: $BACKUP_DIR"
        exit 1
    fi

    # Walk every file in the backup and offer to restore it
    while IFS= read -r -d '' BACKUP_FILE; do
        # Reconstruct the original path
        REL="${BACKUP_FILE#$BACKUP_DIR/}"
        ORIGINAL="$HOME/$REL"

        echo "  Backup:   $BACKUP_FILE"
        echo "  Restores: $ORIGINAL"

        if [ -f "$ORIGINAL" ]; then
            echo "  WARNING:  Destination already exists and will be overwritten."
        fi

        read -p "  Restore this file? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$(dirname "$ORIGINAL")"
            cp "$BACKUP_FILE" "$ORIGINAL"
            echo "  [RESTORED] $ORIGINAL"
        else
            echo "  [SKIPPED]  $ORIGINAL"
        fi
        echo
    done < <(find "$BACKUP_DIR" -type f -print0 | sort -z)
fi

echo "======================================"
echo "  Uninstall complete."
echo "======================================"
echo
