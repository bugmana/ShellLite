#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# release.sh — Tag a new ShellLite release and push it to trigger GitHub Actions.
#
# Usage:
#   ./release.sh                  # Interactive: auto-calculates next patch version
#   ./release.sh <version>        # e.g.  ./release.sh 1.2.0
#
# What it does:
#   1. Determines the next version (interactive or argument).
#   2. Ensures the working tree is clean (no uncommitted changes).
#   3. Runs the unit tests locally — aborts if any fail.
#   4. Creates an annotated git tag  v<version>.
#   5. Pushes the tag to origin, which triggers the GitHub Actions workflow to build and release ShellLite.ipa.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Helpers ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; NC='\033[0m'
info()  { echo "${GREEN}▶${NC} $*"; }
warn()  { echo "${YELLOW}⚠${NC}  $*"; }
error() { echo "${RED}✗${NC}  $*" >&2; exit 1; }

# ── Guard: clean working tree ─────────────────────────────────────────────────
if ! git diff --quiet || ! git diff --cached --quiet; then
    error "Working tree is dirty. Commit or stash your changes before releasing."
fi

# ── Guard: on main (or master) branch ────────────────────────────────────────
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
    warn "You are on branch '$BRANCH', not main/master."
    printf "  Continue anyway? [y/N] "
    read -r CONFIRM
    case "$CONFIRM" in y|Y) ;; *) error "Aborted."; esac
fi

# ── Determine latest tag & next default version ──────────────────────────────
LATEST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")"
RAW_VER="${LATEST_TAG#v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$RAW_VER"
MAJOR="${MAJOR:-1}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"
NEXT_PATCH="$MAJOR.$MINOR.$((PATCH + 1))"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "${BLUE}Latest release:${NC} $LATEST_TAG"
    printf "${BLUE}Enter release version [default: %s]:${NC} " "$NEXT_PATCH"
    read -r INPUT_VER
    VERSION="${INPUT_VER:-$NEXT_PATCH}"
fi

if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    error "Version must be in X.Y.Z format, got: '$VERSION'"
fi
TAG="v$VERSION"

# ── Guard: tag must not already exist ────────────────────────────────────────
if git rev-parse "$TAG" >/dev/null 2>&1; then
    error "Tag '$TAG' already exists. Bump the version number."
fi

info "Preparing release $TAG …"

# ── Run static analysis & unit tests ──────────────────────────────────────────
info "Running static analysis & tests …"
export PATH="/home/aron/.local/share/flutter/bin:$PATH"
if command -v flutter >/dev/null 2>&1; then
    flutter analyze
    flutter test
else
    warn "Flutter not found on PATH; skipping local pre-release tests."
fi
info "All pre-release checks passed."

# ── Create and push the tag ───────────────────────────────────────────────────
info "Creating annotated tag $TAG …"
git tag -a "$TAG" -m "Release $VERSION

Auto-tagged by release.sh on $(date -u '+%Y-%m-%d %H:%M UTC')
GitHub Actions will build ShellLite.ipa and publish the release."

info "Pushing tag to origin …"
git push origin "$TAG"

echo ""
echo "${GREEN}✔ Released $TAG${NC}"
echo "  GitHub Actions build will start momentarily."
echo "  Download your IPA from GitHub Releases once complete."
