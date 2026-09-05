---
name: build-shelllite
description: Build commands, DevOps setup, testing policies, and git commit practices for ShellLite. Use when building, testing, running services, or committing changes in the ShellLite repository.
---

# ShellLite Build & DevOps

## Prerequisites
- Flutter SDK (3.24+ stable channel)
- Java 17 (for Android builds)
- Xcode (for iOS builds, macOS only)
- Clang / CMake / GTK3 development headers (for Linux builds)

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

### Linux
```bash
flutter build linux --release
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
- `release.yml`: Automated multi-platform release workflow triggered via `workflow_dispatch`. Calculates version, tags git commit, triggers Android and iOS builds, and publishes GitHub Release.
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
  Automatically analyzes git commits since the last tag to determine major (`BREAKING CHANGE` or `!:`), minor (`feat:`), or patch (`fix:`, `refactor:`, `perf:`), and generates categorized release notes:
  ```bash
  gh workflow run release.yml -f bump_type=auto
  ```
  *(Note: `auto` is the default when triggering `release.yml` without arguments).*

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
  Preview the next version and changelog locally without tagging or releasing:
  ```bash
  ./scripts/resolve_version.sh auto
  ```

### Release Pipeline Stages
The `release.yml` workflow orchestrates four main steps:
1. **`resolve-version`**:
   - Queries the latest git tag (e.g. `v1.0.4`).
   - Computes the new semantic version according to `bump_type`.
   - Creates and pushes an annotated git tag (e.g. `v1.0.5`).
2. **`build-ios`**:
   - Reusable workflow [`.github/workflows/build-ios.yml`](file:///home/aron/projects/ShellLite/.github/workflows/build-ios.yml).
   - Generates sideloadable iOS IPA (`ShellLite.ipa`) compatible with SideStore, AltStore, and Sideloadly.
3. **`build-android`**:
   - Reusable workflow [`.github/workflows/build-android.yml`](file:///home/aron/projects/ShellLite/.github/workflows/build-android.yml).
   - Generates signed release APK (`ShellLite.apk`) and App Bundle (`ShellLite.aab`).
4. **`publish-release`**:
   - Downloads IPA, APK, and AAB build artifacts.
   - Publishes the GitHub Release tagged with `vX.Y.Z` and attaches all installer assets.

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
  - Types: `feat`, `fix`, `refactor`, `style`, `ci`, `docs`, `chore`.
  - Examples:
    - `feat(terminal): add close keyboard button`
    - `fix(android): resolve release keystore path`
    - `ci(workflow): update build runner`
- **Push Policy**: Do **not** push on every commit. Stage and commit logically grouped changes locally, and push only when a complete milestone or feature is ready.
