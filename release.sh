#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# release.sh — Tag a new ShellLite release and push it to trigger GitHub Actions.
#
# Usage:
#   ./release.sh <version>          # e.g.  ./release.sh 1.2.0
#
# What it does:
#   1. Validates the version argument (must be X.Y.Z).
#   2. Ensures the working tree is clean (no uncommitted changes).
#   3. Runs the unit tests locally — aborts if any fail.
#   4. Creates an annotated git tag  v<version>.
#   5. Pushes the tag to origin, which triggers the GitHub Actions workflow to build and release ShellLite.ipa.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Helpers ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo "${GREEN}▶${NC} $*"; }
warn()  { echo "${YELLOW}⚠${NC}  $*"; }
error() { echo "${RED}✗${NC}  $*" >&2; exit 1; }

# ── Argument validation ───────────────────────────────────────────────────────
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    error "Usage: ./release.sh <version>   (e.g.  ./release.sh 1.2.0)"
fi
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    error "Version must be in X.Y.Z format, got: '$VERSION'"
fi
TAG="v$VERSION"

info "Preparing release $TAG …"

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

# ── Guard: tag must not already exist ────────────────────────────────────────
if git rev-parse "$TAG" >/dev/null 2>&1; then
    error "Tag '$TAG' already exists. Bump the version number."
fi

# ── Run unit tests ────────────────────────────────────────────────────────────
info "Running unit tests …"
if ! swift test --quiet; then
    error "Tests failed — fix them before releasing."
fi
info "All tests passed."

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

