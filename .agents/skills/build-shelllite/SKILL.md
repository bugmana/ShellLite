---
name: build-shelllite
description: Build commands, DevOps setup, testing policies, and git commit practices for ShellLite. Use when building, testing, running services, or committing changes in the ShellLite repository.
---

# ShellLite Build & DevOps

## Prerequisites
- Flutter SDK (3.24+ stable channel)
- Java 17 (for Android builds)
- Xcode (for iOS builds, macOS only)

```bash
flutter pub get
```

## Build Targets

### Web
```bash
flutter build web --base-href /
# Ensure web server user can read output
chmod -R a+rX build/web
```

### Android
```bash
# APK
flutter build apk --release

# App Bundle (Play Store)
flutter build appbundle --release
```

### iOS
```bash
flutter build ipa --release
```

## Testing & Quality Assurance
- **Static Analysis**: `flutter analyze`
- **Tests**: `flutter test`
- **Policy**: Only run `flutter test` when necessary (e.g. after changes to models, providers, business logic, or before releasing/submitting PRs). Do not run tests on routine UI styling or documentation edits.

## DevOps Setup

### Web Deployment Architecture & SSH Bridge
Browsers cannot initiate direct TCP connections to SSH servers. ShellLite web uses a WebSocket bridge:
1. **Bridge (`websockify`)**:
   ```bash
   websockify 127.0.0.1:8022 127.0.0.1:22
   ```
2. **Reverse Proxy (Caddy)**: Serves `build/web` and proxies `/ssh-ws*` to websockify:
   ```caddy
   shell.yourdomain.com {
       encode zstd gzip

       # Proxy SSH WebSocket traffic
       handle /ssh-ws* {
           reverse_proxy 127.0.0.1:8022
       }

       # Serve Flutter Web SPA
       handle {
           root * /path/to/ShellLite/build/web

           @no_cache {
               path / /index.html /flutter_bootstrap.js /flutter_service_worker.js /version.json
           }
           header @no_cache Cache-Control "no-cache, no-store, must-revalidate"

           @static_assets {
               path /assets/* /canvaskit/* *.wasm *.png *.ico *.ttf *.otf
           }
           header @static_assets Cache-Control "public, max-age=31536000, immutable"

           try_files {path} /index.html
           file_server
       }
   }
   ```

### Local Systemd Services
Service definitions are in [`systemd/`](file:///home/aron/projects/ShellLite/systemd):
- `shelllite.service`: Development web server (`flutter run -d web-server --web-port=8080 ...`).
- `shelllite-watcher.path` & `shelllite-watcher.service`: Monitors `lib/` and rebuilds `build/web` on change.

### GitHub Actions CI/CD
Workflows are in [`.github/workflows/`](file:///home/aron/projects/ShellLite/.github/workflows):
- `ci.yml`: Runs on push and PR to `main` and `master`. Executes `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --release`.
- `build-android.yml`: Builds release APK/AAB with keystore secrets.
- `build-ios.yml`: Builds iOS IPA artifact.
- `release.yml`: Automated multi-platform release workflow triggered via `workflow_dispatch`. Calculates version, tags git commit, triggers Android and iOS builds, publishes GitHub Release, and optionally deploys AAB to Google Play Console.
- `deploy-play-store.yml`: On-demand deployment workflow to publish an existing or latest release AAB directly to Google Play Console tracks.
- `dependabot-auto-merge.yml`: Automatically merges authorized Dependabot updates.

## Release Process & Publishing

ShellLite releases are automated via GitHub Actions [`.github/workflows/release.yml`](file:///home/aron/projects/ShellLite/.github/workflows/release.yml).

### Pre-Release Checklist
1. Ensure all changes are committed and pushed to `main`:
   ```bash
   git status
   git push origin main
   ```
2. Verify code quality and test suite:
   ```bash
   flutter analyze
   flutter test
   ```

### Triggering a Release
ShellLite uses automated semantic versioning powered by Conventional Commits (`scripts/resolve_version.sh`).

- **Automated Semantic Release (Recommended)**:
  Automatically analyzes git commits since the last tag to determine major (`BREAKING CHANGE` or `!:`), minor (`feat:`), or patch (`fix:`, `refactor:`, `perf:`), and generates categorized release notes for both GitHub and Google Play:
  ```bash
  gh workflow run release.yml -f bump_type=auto
  ```
  *(Note: `auto` is the default when triggering `release.yml` without arguments).*

- **Custom Release Notes (Curated Announcements)**:
  Provide custom release notes directly to override automated generation:
  ```bash
  gh workflow run release.yml \
    -f bump_type=auto \
    -f custom_play_store_notes="• Terminal: Improved mouse wheel scrolling in persistent tmux sessions.\n• Performance and connection stability enhancements." \
    -f custom_changelog="### Highlights\n- Enhanced tmux scrolling support.\n- Connection lifecycle stability improvements."
  ```

- **Manual Override Bumps**:
  - **Patch release** (e.g. `1.0.5` -> `1.0.6`):
    ```bash
    gh workflow run release.yml -f bump_type=patch
    ```
  - **Minor release** (e.g. `1.0.5` -> `1.1.0`):
    ```bash
    gh workflow run release.yml -f bump_type=minor
    ```
  - **Major release** (e.g. `1.0.5` -> `2.0.0`):
    ```bash
    gh workflow run release.yml -f bump_type=major
    ```
  - **Custom version**:
    ```bash
    gh workflow run release.yml -f bump_type=custom -f custom_version=1.2.0
    ```

- **Local Preview & Dry Run**:
  Preview the next version, GitHub changelog, and Google Play "What's New" locally without tagging or releasing:
  ```bash
  ./scripts/resolve_version.sh auto
  ```

### Release Notes Standards: GitHub vs. Google Play

Release notes serve two very different audiences and must be crafted accordingly:

#### 1. Google Play Store Release Notes (`whatsnew/whatsnew-en-US`)
Google Play has strict constraints and an end-user audience:
- **Strict 500-Character Maximum**: Enforced hard limit by Google Play Console API. Notes exceeding 500 characters cause deployment failure.
- **End-User Focus**: Store users care about features, UI improvements, and visible bug fixes. **Never** expose internal CI/CD workflows, CodeQL rules, test updates, runner upgrades, or dependabot updates in Play Store notes.
- **Formatting Rules**:
  - Use clean unicode bullet points (`• `).
  - Capitalize scopes and descriptions (e.g. `• Terminal: Correct mouse wheel button IDs for tmux scrolling`).
  - **No raw markdown headings** (`####`), backticks (`` `da676db` ``), or git commit hashes.
- **Graceful Truncation**: Truncate cleanly at bullet point boundaries if notes approach 500 characters. Never use `head -c 500` which cuts off mid-word or mid-sentence.
- **Maintenance Fallback**: When a release contains only internal CI/maintenance commits, fall back to a clean user-facing summary (e.g. `• Performance improvements, internal maintenance, and bug fixes.`).

#### 2. GitHub Releases
GitHub Releases are for developers, sideloaders, and contributors:
- **Categorized Sections**:
  - `#### 💥 Breaking Changes`
  - `#### 🚀 Features` (`feat:`)
  - `#### 🐛 Bug Fixes` (`fix:`)
  - `#### ⚡ Performance Improvements` (`perf:`)
  - `#### ♻️ Code Refactoring` (`refactor:`)
  - `#### 🧰 Maintenance & Documentation` (`ci:`, `docs:`, `chore:`, `test:`)
- **Traceability**: Retains git commit hashes and links to pull requests.
- **Download & Sideload Guides**: Includes direct links to `ShellLite.apk`, `ShellLite.aab`, `ShellLite.ipa` (SideStore/AltStore), and live web app.

### Release Pipeline Stages
The `release.yml` workflow orchestrates five main steps:
1. **`resolve-version`**:
   - Queries the latest git tag (e.g. `v1.8.1`).
   - Computes the new semantic version according to `bump_type`.
   - Generates both GitHub changelog and Play Store notes via `scripts/resolve_version.sh`.
   - Creates and pushes an annotated git tag (e.g. `v1.8.2`).
2. **`build-ios`**:
   - Reusable workflow [`.github/workflows/build-ios.yml`](file:///home/aron/projects/ShellLite/.github/workflows/build-ios.yml).
   - Generates sideloadable iOS IPA (`ShellLite.ipa`) compatible with SideStore, AltStore, and Sideloadly.
3. **`build-android`**:
   - Reusable workflow [`.github/workflows/build-android.yml`](file:///home/aron/projects/ShellLite/.github/workflows/build-android.yml).
   - Generates signed release APK (`ShellLite.apk`) and App Bundle (`ShellLite.aab`). Supports optional `build_number` and `BUILD_NUMBER_OFFSET`.
4. **`publish-release`**:
   - Downloads IPA, APK, and AAB build artifacts.
   - Publishes the GitHub Release tagged with `vX.Y.Z` and attaches all installer assets.
5. **`deploy-play-store`**:
   - Downloads signed AAB artifact.
   - Validates localized release notes in `whatsnew/whatsnew-en-US` (user-facing, <= 500 chars).
   - Uploads bundle to Google Play Console (defaults to `internal` for immediate test availability; supports `alpha`, `beta`, `production`).

### On-Demand Google Play Deployment
To publish an existing release artifact or update track/notes without triggering a new semantic release:
```bash
gh workflow run deploy-play-store.yml \
  -f track=internal \
  -f release_tag=v1.8.3 \
  -f custom_play_store_notes="• Terminal: Improved mouse wheel scrolling in persistent tmux sessions."
```

### Monitoring & Verifying the Release
Track the workflow progress:
```bash
# List recent release workflow runs
gh run list --workflow=release.yml

# Watch the running workflow interactively
gh run watch <run-id>

# View the published release
gh release view
```

## Git Commit & Push Workflow
- **Commit Convention**: Conventional Commits format with scope:
  ```text
  <type>(<scope>): <short description>
  ```
  - **User-Facing Types** (automatically featured in Play Store notes & GitHub Highlights):
    - `feat`: New user-visible feature or capability (e.g. `feat(terminal): add close keyboard button`).
    - `fix`: Bug fix affecting user experience (e.g. `fix(terminal): correct mouse wheel button IDs for tmux scrolling`).
    - `perf`: Performance improvement (e.g. `perf(render): reduce terminal frame repaint latency`).
  - **Internal Maintenance Types** (kept in GitHub Maintenance section, omitted from Play Store):
    - `refactor`: Internal code reorganization without behavior change.
    - `ci`: CI/CD workflow, runner, or action updates.
    - `docs`: Documentation, guides, or readme updates.
    - `test`: Unit, widget, or integration test additions.
    - `chore`: Dependency updates or build configuration tweaks.
- **Push Policy**: Do **not** push on every commit. Stage and commit logically grouped changes locally, and push only when a complete milestone or feature is ready.
