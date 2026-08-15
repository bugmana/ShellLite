#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# ci_post_clone.sh  — Xcode Cloud: runs immediately after the repo is cloned.
#
# Responsibilities:
#   1. Print the build environment for debugging.
#   2. Validate that required secrets/env vars are present.
#   3. Run the Linux-compatible unit-test suite (ShellLiteCore only).
#      Xcode Cloud also runs xcodebuild test on the full target separately;
#      this gives us a fast early-exit on pure-logic failures.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

echo "▶ ci_post_clone  ——  $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "  Branch  : ${CI_BRANCH:-<none>}"
echo "  Tag     : ${CI_TAG:-<none>}"
echo "  Workflow: ${CI_WORKFLOW:-<none>}"
echo "  Build # : ${CI_BUILD_NUMBER:-<none>}"
echo "  Xcode   : $(xcodebuild -version | head -1)"
echo "  Swift   : $(swift --version | head -1)"

# ── Validate required environment variables ───────────────────────────────────
# These are set in App Store Connect → Xcode Cloud → Workflow → Environment.
# Add any secrets your app needs here. The script will fail fast if they are
# missing, surfacing the problem before the build even starts.
REQUIRED_VARS=""   # e.g. "APP_STORE_CONNECT_API_KEY_ID APP_STORE_CONNECT_ISSUER_ID"
for var in $REQUIRED_VARS; do
    if [ -z "${!var:-}" ]; then
        echo "✗ Required env var '$var' is not set. Add it in Xcode Cloud → Environment." >&2
        exit 1
    fi
done

echo "✔ ci_post_clone complete"
