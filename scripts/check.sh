#!/usr/bin/env bash
# Local checks: ./scripts/check.sh [--web] [test paths...]
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

build_web=false
test_arguments=(--no-pub)
for argument in "$@"; do
  case "$argument" in
    --web) build_web=true ;;
    --help|-h)
      echo 'Usage: ./scripts/check.sh [--web] [test paths...]'
      echo 'Runs dependency setup, analysis, and tests. --web adds a release Web build.'
      exit 0
      ;;
    -*) echo "Unknown option: $argument" >&2; exit 2 ;;
    *)
      if [[ ! -e "$argument" ]]; then
        echo "Test path does not exist: $argument" >&2
        exit 2
      fi
      test_arguments+=("$argument")
      ;;
  esac
done

flutter pub get
flutter analyze --no-pub
flutter test "${test_arguments[@]}"
if [[ "$build_web" == true ]]; then
  flutter build web --release --no-pub
fi
