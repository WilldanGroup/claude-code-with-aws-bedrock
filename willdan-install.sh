#!/usr/bin/env bash
# Willdan claude-code-with-aws-bedrock fetcher.
#
# Downloads the platform-specific package from a GitHub release and runs the
# embedded install.sh. Replaces the per-user presigned-S3 URL flow.
#
# Usage:
#   ./willdan-install.sh                              # fetch the latest release, prompt for install mode
#   ./willdan-install.sh --tag willdan-v2.2.0-1       # pin to a specific release
#   ./willdan-install.sh --side-by-side               # passed through to the inner install.sh
#   ./willdan-install.sh --default-longcontext        # passed through to the inner install.sh
#
# Or as a one-liner:
#   curl -L https://raw.githubusercontent.com/WilldanGroup/claude-code-with-aws-bedrock/main/willdan-install.sh | bash -s -- --side-by-side
#
# Auth: this script uses `gh release download` against a private repo. Run
# `gh auth login` once before invoking. Falls back to curl + GITHUB_TOKEN if
# `gh` is not installed.

set -euo pipefail

REPO="WilldanGroup/claude-code-with-aws-bedrock"
TAG=""
INSTALL_ARGS=()
KEEP_TEMP=false

while [ $# -gt 0 ]; do
  case "$1" in
    --tag)
      TAG="$2"; shift 2 ;;
    --tag=*)
      TAG="${1#*=}"; shift ;;
    --keep-temp)
      KEEP_TEMP=true; shift ;;
    --help|-h)
      sed -n '2,18p' "$0"
      exit 0 ;;
    *)
      # Pass-through to inner install.sh (--side-by-side, --default-longcontext, etc.)
      INSTALL_ARGS+=("$1"); shift ;;
  esac
done

# Detect platform
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)        PLATFORM="darwin-arm64" ;;
  Darwin-x86_64)       PLATFORM="darwin-x86_64" ;;
  Linux-x86_64)        PLATFORM="linux-x86_64" ;;
  Linux-aarch64|Linux-arm64) PLATFORM="linux-aarch64" ;;
  *)
    echo "❌ Unsupported platform: $(uname -s)-$(uname -m)" >&2
    echo "   Windows users: download claude-code-package-windows-x86_64.zip from the release manually." >&2
    exit 1 ;;
esac

ASSET="claude-code-package-${PLATFORM}.zip"
echo "Detected platform: $PLATFORM"
echo "Asset to fetch:    $ASSET"

# Resolve the tag
if [ -z "$TAG" ]; then
  if command -v gh >/dev/null 2>&1; then
    TAG=$(gh release list --repo "$REPO" --limit 1 --json tagName --jq '.[0].tagName')
  else
    # Use GitHub API directly
    TAG=$(curl -fsSL \
      ${GITHUB_TOKEN:+-H "Authorization: token $GITHUB_TOKEN"} \
      "https://api.github.com/repos/$REPO/releases/latest" \
      | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name"[^"]*"([^"]+)".*/\1/')
  fi
  if [ -z "$TAG" ]; then
    echo "❌ Could not resolve latest release tag. Pass --tag explicitly." >&2
    exit 1
  fi
fi
echo "Release tag:       $TAG"

# Stage in a temp dir
TMPDIR_ROOT="$(mktemp -d -t willdan-claude-code-XXXXXX)"
if [ "$KEEP_TEMP" = false ]; then
  trap 'rm -rf "$TMPDIR_ROOT"' EXIT
fi

cd "$TMPDIR_ROOT"

# Download
if command -v gh >/dev/null 2>&1; then
  echo "Downloading via gh..."
  gh release download "$TAG" --repo "$REPO" --pattern "$ASSET"
else
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "❌ neither 'gh' CLI nor GITHUB_TOKEN env is available" >&2
    echo "   install gh and run 'gh auth login', or set GITHUB_TOKEN with repo:read scope" >&2
    exit 1
  fi
  echo "Downloading via curl..."
  asset_url=$(curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/releases/tags/$TAG" \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
target = '$ASSET'
for a in data.get('assets', []):
    if a.get('name') == target:
        print(a['url'])
        break
")
  if [ -z "$asset_url" ]; then
    echo "❌ asset $ASSET not found in release $TAG" >&2
    exit 1
  fi
  curl -fL -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/octet-stream" \
    -o "$ASSET" "$asset_url"
fi

if [ ! -f "$ASSET" ]; then
  echo "❌ download produced no file" >&2
  exit 1
fi

echo "Extracting..."
unzip -q "$ASSET"
cd claude-code-package

if [ ! -x install.sh ]; then
  echo "❌ extracted package missing install.sh" >&2
  exit 1
fi

echo
echo "Running embedded install.sh ${INSTALL_ARGS[*]:-}"
echo "================================================"
./install.sh "${INSTALL_ARGS[@]}"

echo
echo "✓ Installed from release $TAG (${PLATFORM})"
if [ "$KEEP_TEMP" = true ]; then
  echo "Temp dir kept: $TMPDIR_ROOT"
fi
