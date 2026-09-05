#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Semantic Version & Changelog Resolver for ShellLite
#
# Analyzes Conventional Commits since the latest git tag:
# - BREAKING CHANGE / !: -> Major bump
# - feat:                -> Minor bump
# - fix/refactor/perf:   -> Patch bump
# - auto:                -> Automatically calculates bump based on commit history
# ─────────────────────────────────────────────────────────────────────────────

BUMP_TYPE="${1:-${BUMP_TYPE:-auto}}"
CUSTOM_VERSION="${2:-${CUSTOM_VERSION:-}}"
DRY_RUN="${DRY_RUN:-false}"

# 1. Find latest semver tag
LATEST_TAG=$(git tag -l "v[0-9]*.[0-9]*.[0-9]*" --sort=-v:refname | head -n1 || true)
if [ -z "$LATEST_TAG" ]; then
  LATEST_TAG="v1.0.0"
fi

RAW_VER="${LATEST_TAG#v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$RAW_VER"
MAJOR=${MAJOR:-1}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

# 2. Inspect commits since latest tag
COMMIT_RANGE="${LATEST_TAG}..HEAD"
COMMIT_COUNT=$(git rev-list --count "$COMMIT_RANGE" 2>/dev/null || echo "0")

HAS_BREAKING=false
HAS_FEAT=false
HAS_FIX=false
HAS_REFACTOR=false
HAS_PERF=false

CHANGELOG_BREAKING=""
CHANGELOG_FEAT=""
CHANGELOG_FIX=""
CHANGELOG_PERF=""
CHANGELOG_REFACTOR=""
CHANGELOG_OTHER=""

if [ "$COMMIT_COUNT" -gt 0 ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    HASH=$(echo "$line" | awk '{print $1}')
    MSG=$(echo "$line" | cut -d' ' -f2-)
    BODY=$(git log -1 --pretty=format:"%b" "$HASH" 2>/dev/null || echo "")

    if echo "$MSG" | grep -qE '^([a-zA-Z]+)(\([^\)]+\))?!:' || echo "$BODY" | grep -q "BREAKING CHANGE"; then
      HAS_BREAKING=true
      CHANGELOG_BREAKING="${CHANGELOG_BREAKING}- ${MSG} (\`${HASH}\`)"$'\n'
    elif echo "$MSG" | grep -qE '^feat(\([^\)]+\))?:'; then
      HAS_FEAT=true
      CHANGELOG_FEAT="${CHANGELOG_FEAT}- ${MSG} (\`${HASH}\`)"$'\n'
    elif echo "$MSG" | grep -qE '^fix(\([^\)]+\))?:'; then
      HAS_FIX=true
      CHANGELOG_FIX="${CHANGELOG_FIX}- ${MSG} (\`${HASH}\`)"$'\n'
    elif echo "$MSG" | grep -qE '^perf(\([^\)]+\))?:'; then
      HAS_PERF=true
      CHANGELOG_PERF="${CHANGELOG_PERF}- ${MSG} (\`${HASH}\`)"$'\n'
    elif echo "$MSG" | grep -qE '^refactor(\([^\)]+\))?:'; then
      HAS_REFACTOR=true
      CHANGELOG_REFACTOR="${CHANGELOG_REFACTOR}- ${MSG} (\`${HASH}\`)"$'\n'
    else
      CHANGELOG_OTHER="${CHANGELOG_OTHER}- ${MSG} (\`${HASH}\`)"$'\n'
    fi
  done < <(git log "$COMMIT_RANGE" --pretty=format:"%h %s")
fi

# 3. Determine bump type
RESOLVED_BUMP="$BUMP_TYPE"
SHOULD_RELEASE="true"

if [ "$BUMP_TYPE" = "auto" ]; then
  if [ "$COMMIT_COUNT" -eq 0 ]; then
    SHOULD_RELEASE="false"
    RESOLVED_BUMP="none"
  elif [ "$HAS_BREAKING" = true ]; then
    RESOLVED_BUMP="major"
  elif [ "$HAS_FEAT" = true ]; then
    RESOLVED_BUMP="minor"
  elif [ "$HAS_FIX" = true ] || [ "$HAS_REFACTOR" = true ] || [ "$HAS_PERF" = true ]; then
    RESOLVED_BUMP="patch"
  else
    RESOLVED_BUMP="patch"
  fi
fi

# 4. Calculate new version
if [ "$RESOLVED_BUMP" = "major" ]; then
  MAJOR=$((MAJOR + 1))
  MINOR=0
  PATCH=0
  NEW_VERSION="$MAJOR.$MINOR.$PATCH"
elif [ "$RESOLVED_BUMP" = "minor" ]; then
  MINOR=$((MINOR + 1))
  PATCH=0
  NEW_VERSION="$MAJOR.$MINOR.$PATCH"
elif [ "$RESOLVED_BUMP" = "patch" ]; then
  PATCH=$((PATCH + 1))
  NEW_VERSION="$MAJOR.$MINOR.$PATCH"
elif [ "$RESOLVED_BUMP" = "custom" ]; then
  if [ -z "$CUSTOM_VERSION" ]; then
    echo "Error: custom bump selected but no custom version provided" >&2
    exit 1
  fi
  NEW_VERSION="${CUSTOM_VERSION#v}"
elif [ "$RESOLVED_BUMP" = "none" ]; then
  NEW_VERSION="$RAW_VER"
else
  echo "Error: Unknown bump type: $RESOLVED_BUMP" >&2
  exit 1
fi

NEW_TAG="v$NEW_VERSION"

# 5. Build Markdown Changelog
CHANGELOG=""
if [ -n "$CHANGELOG_BREAKING" ]; then
  CHANGELOG="${CHANGELOG}#### 💥 Breaking Changes"$'\n'"${CHANGELOG_BREAKING}"$'\n'
fi
if [ -n "$CHANGELOG_FEAT" ]; then
  CHANGELOG="${CHANGELOG}#### 🚀 Features"$'\n'"${CHANGELOG_FEAT}"$'\n'
fi
if [ -n "$CHANGELOG_FIX" ]; then
  CHANGELOG="${CHANGELOG}#### 🐛 Bug Fixes"$'\n'"${CHANGELOG_FIX}"$'\n'
fi
if [ -n "$CHANGELOG_PERF" ]; then
  CHANGELOG="${CHANGELOG}#### ⚡ Performance Improvements"$'\n'"${CHANGELOG_PERF}"$'\n'
fi
if [ -n "$CHANGELOG_REFACTOR" ]; then
  CHANGELOG="${CHANGELOG}#### ♻️ Code Refactoring"$'\n'"${CHANGELOG_REFACTOR}"$'\n'
fi
if [ -n "$CHANGELOG_OTHER" ]; then
  CHANGELOG="${CHANGELOG}#### 🧰 Maintenance & Documentation"$'\n'"${CHANGELOG_OTHER}"$'\n'
fi
if [ -z "$CHANGELOG" ]; then
  CHANGELOG="Release $NEW_TAG"$'\n'
fi

echo "=========================================="
echo "Semantic Release Resolution Summary"
echo "=========================================="
echo "Previous Tag:   $LATEST_TAG"
echo "Commit Range:   $COMMIT_RANGE ($COMMIT_COUNT commits)"
echo "Selected Bump:  $BUMP_TYPE"
echo "Resolved Bump:  $RESOLVED_BUMP"
echo "New Version:    $NEW_VERSION"
echo "New Tag:        $NEW_TAG"
echo "Should Release: $SHOULD_RELEASE"
echo "=========================================="
echo "Generated Changelog:"
echo "$CHANGELOG"
echo "=========================================="

# 6. Export to GitHub Actions if in CI
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "version=$NEW_VERSION" >> "$GITHUB_OUTPUT"
  echo "tag=$NEW_TAG" >> "$GITHUB_OUTPUT"
  echo "should_release=$SHOULD_RELEASE" >> "$GITHUB_OUTPUT"
  echo "bump_type=$RESOLVED_BUMP" >> "$GITHUB_OUTPUT"
  
  # Multiline output for changelog
  echo "changelog<<EOF" >> "$GITHUB_OUTPUT"
  echo "$CHANGELOG" >> "$GITHUB_OUTPUT"
  echo "EOF" >> "$GITHUB_OUTPUT"
fi
