#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# ci_post_xcodebuild.sh  — Xcode Cloud: runs after xcodebuild finishes.
#
# Responsibilities:
#   1. Print a build summary (status, version, artifact location).
#   2. On success: echo a confirmation that the IPA/archive is being uploaded
#      to TestFlight (Xcode Cloud handles the actual upload automatically when
#      the workflow's "Post-Actions" is set to "TestFlight Internal Testing").
#   3. On failure: print a clear failure banner (Xcode Cloud will mark the
#      build as failed regardless; this just improves log readability).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

echo "▶ ci_post_xcodebuild  ——  $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# CI_XCODEBUILD_EXIT_CODE is set by Xcode Cloud to the exit code of xcodebuild.
EXIT_CODE="${CI_XCODEBUILD_EXIT_CODE:-0}"
TAG="${CI_TAG:-<branch build>}"
BUILD_NUMBER="${CI_BUILD_NUMBER:-?}"

if [ "$EXIT_CODE" -eq 0 ]; then
    echo ""
    echo "  ┌────────────────────────────────────────────┐"
    echo "  │  ✅  BUILD SUCCEEDED                        │"
    echo "  │                                            │"
    echo "  │  Tag          : $TAG"
    echo "  │  Build #      : $BUILD_NUMBER"
    echo "  │  Distribution : TestFlight (internal)      │"
    echo "  └────────────────────────────────────────────┘"
    echo ""
    echo "  Xcode Cloud will upload the IPA to TestFlight automatically."
    echo "  Testers in the internal group will receive a notification."
else
    echo ""
    echo "  ┌────────────────────────────────────────────┐"
    echo "  │  ❌  BUILD FAILED  (exit code $EXIT_CODE)  │"
    echo "  │                                            │"
    echo "  │  Tag          : $TAG"
    echo "  │  Build #      : $BUILD_NUMBER"
    echo "  └────────────────────────────────────────────┘"
    echo ""
    echo "  Check the build log above for compiler/test errors." >&2
    # Do NOT exit non-zero here — Xcode Cloud already knows the build failed.
    # Exiting non-zero from a post-script causes a misleading "script failed"
    # error that obscures the real cause in the UI.
fi

echo "✔ ci_post_xcodebuild complete"
