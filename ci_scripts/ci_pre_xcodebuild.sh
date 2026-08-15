#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# ci_pre_xcodebuild.sh  — Xcode Cloud: runs just before xcodebuild.
#
# Responsibilities:
#   1. Derive a marketing version (CFBundleShortVersionString) from the git tag
#      that triggered this workflow (e.g. "v1.4.2" → "1.4.2").
#   2. Stamp CFBundleVersion with the Xcode Cloud build number so every
#      TestFlight build has a unique, monotonically increasing number.
#   3. Inject both values into the Info.plist via PlistBuddy so Xcode picks
#      them up at build time without touching the source-controlled file.
#
# Trigger assumption: this workflow is started by pushing a tag of the form
#   v<MAJOR>.<MINOR>.<PATCH>   e.g.  v1.0.0  v2.3.11
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

echo "▶ ci_pre_xcodebuild  ——  $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# ── Resolve marketing version from tag ───────────────────────────────────────
TAG="${CI_TAG:-}"
if [ -z "$TAG" ]; then
    # Fallback when run on a branch (e.g. a PR build): use last reachable tag.
    TAG="$(git describe --tags --abbrev=0 2>/dev/null || echo 'v0.0.0')"
    echo "  No CI_TAG — using last reachable tag: $TAG"
fi

# Strip leading 'v' prefix.
MARKETING_VERSION="${TAG#v}"

# Basic validation: must look like X.Y.Z
if ! echo "$MARKETING_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "  ⚠ Tag '$TAG' does not match vX.Y.Z — using 0.0.0 as marketing version." >&2
    MARKETING_VERSION="0.0.0"
fi

# ── Build number from Xcode Cloud's monotonic counter ────────────────────────
BUILD_NUMBER="${CI_BUILD_NUMBER:-1}"

echo "  Marketing version : $MARKETING_VERSION"
echo "  Build number      : $BUILD_NUMBER"

# ── Stamp the Info.plist ─────────────────────────────────────────────────────
# Xcode Cloud sets CI_PRIMARY_REPOSITORY_PATH to the repo root.
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-.}"

# Locate the app's Info.plist. Adjust the glob if your layout differs.
PLIST_PATH=$(find "$REPO_ROOT" -name "Info.plist" \
    -path "*/ShellLite/*" \
    -not -path "*/.build/*" \
    -not -path "*/Tests/*" \
    | head -1)

if [ -n "$PLIST_PATH" ]; then
    echo "  Stamping: $PLIST_PATH"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING_VERSION" "$PLIST_PATH"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER"              "$PLIST_PATH"
else
    # SPM-only packages often don't have a standalone Info.plist; Xcode
    # auto-generates one. In that case pass values via build settings instead.
    echo "  No Info.plist found — injecting via INFOPLIST_KEY_ build settings."
    # Xcode Cloud respects these env vars when generating the plist:
    export INFOPLIST_KEY_CFBundleVersion="$BUILD_NUMBER"
    export MARKETING_VERSION="$MARKETING_VERSION"
fi

echo "✔ ci_pre_xcodebuild complete"
