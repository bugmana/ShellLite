# ShellLite Agent Team Handover & Operating Guide

> **Target Audience**: Autonomous 3-Agent Collaborative Team  
> **Core Objective**: Make ShellLite leaner, reduce operational and cognitive complexity, optimize Flutter client code, and harden GitHub CI/CD workflows.  
> **Repository Baseline**: `v1.8.4` on `main` (149/149 tests passing, 0 analyzer issues).

---

## 1. Executive Summary & Context

ShellLite is a lightweight, privacy-focused SSH client and terminal emulator built with Flutter for Android, iOS, and Web. 

Over recent iterations, ShellLite has evolved rapidly, accumulating multiple workflows, large monolithic widget screens, and duplicated documentation. We recently consolidated the documentation into a single `README.md` and one unified developer skill (`.agents/skills/build-shelllite/SKILL.md`), removed redundant standalone deploy workflows, resolved terminal scrolling bugs in `tmux`, and stabilized Google Play deployments to the `internal` testing track.

The mission of this 3-agent team is to take ShellLite to the next level of engineering maturity:
1. **Dramatically reduce codebase footprint and complexity** (decompose 800+ line widget monoliths, eliminate dead code, prune unneeded dependencies).
2. **Optimize and harden GitHub Actions workflows** (eliminate redundant CI runs, speed up build times, update deprecated Node 20 runners).
3. **Protect core architectural invariants** (privacy, tmux scrolling compatibility, strict git commit/push policies, single-README rule).

---

## 2. Team Structure & Responsibilities

```text
               +-------------------------------------------------------+
               |                  Agent 3: Supervisor                  |
               |         (Lead Architect & Governance Lead)            |
               +-------------------------------------------------------+
                                          |
                        +-----------------+-----------------+
                        |                                   |
    +---------------------------------------+   +---------------------------------------+
    |       Agent 1: Flutter & Dart         |   |         Agent 2: CI/CD & DevOps       |
    |      (Client & Framework Lead)        |   |       (Workflows & Release Lead)      |
    +---------------------------------------+   +---------------------------------------+
```

### Agent 1: Flutter & Dart Specialist (Client Lead)
- **Domain Ownership**: `lib/`, `test/`, `pubspec.yaml`, assets.
- **Primary Goals**:
  1. **Deconstruct UI Monoliths**: Decompose oversized screens and modals into modular, testable components:
     - `lib/screens/server_form_screen.dart` (935 lines)
     - `lib/widgets/keyboard_accessory_bar.dart` (902 lines)
     - `lib/screens/terminal_screen.dart` (856 lines)
     - `lib/widgets/file_upload_modal.dart` (818 lines)
     - `lib/widgets/customize_accessory_keys_modal.dart` (655 lines)
  2. **Dependency & Asset Pruning**:
     - Audit `pubspec.yaml` (e.g. check if `crypto`, `pinenacl`, `uuid` can be trimmed or if lighter alternatives exist).
     - Check font and asset bundles in `assets/` to ensure no unused weights or bloat.
  3. **Terminal Invariant Defense**:
     - Maintain `ShellLiteMouseHandler` mapping: wheel events **must** map to unshifted 64 (up) and 65 (down). Bit 2 (`+4`) must **never** be set on unshifted wheel events to prevent `tmux` silent scroll drops.
     - Maintain stateful UTF-8 decoding in `lib/services/ssh_service.dart`.
  4. **Quality Bar**:
     - Maintain 0 analyzer warnings (`flutter analyze`).
     - Maintain 100% test pass rate across all unit and widget tests.

### Agent 2: GitHub Actions & CI/CD Specialist (DevOps Lead)
- **Domain Ownership**: `.github/workflows/`, `scripts/`, repository variables, build runners.
- **Primary Goals**:
  1. **Workflow Streamlining**:
     - Maintain `.github/workflows/release.yml` as the **single source of truth** for all releases and store deployments. Do not introduce auxiliary one-off deploy workflows.
     - Standardize runner images (`ubuntu-slim` for light tasks, `ubuntu-24.04` for Android, `macos-14` for iOS).
     - Address GitHub Actions Node.js 20 deprecation warnings by pinning action versions that run natively on Node 24.
  2. **Build Time & Cache Optimization**:
     - Review Gradle, Flutter, and CocoaPods caching to eliminate duplicate downloading and cache churn.
     - Ensure path filters (`paths-ignore` for markdown/docs) and concurrency groups (`cancel-in-progress: true`) prevent redundant CI execution.
  3. **Release & Store Deployment Guardrails**:
     - Maintain Google Play deployment targeting `internal` by default.
     - Ensure release notes strictly adhere to the <= 500 character limit without mid-line truncation.

### Agent 3: Lead Architect & Supervisor (Governance Lead)
- **Domain Ownership**: Cross-cutting architecture, code reviews, PR approvals, conflict resolution, repository policy enforcement.
- **Primary Goals**:
  1. **Strict Policy Enforcement**:
     - **Single-README Policy**: Exactly 1 `README.md` at root for public documentation, and 1 `.agents/skills/build-shelllite/SKILL.md` for developer/agent instructions. No extra handover notes or scattered markdown docs.
     - **Push Policy**: **Commit locally, push ONLY when explicitly asked by the user**. Agents must never execute `git push` autonomously.
     - **Zero Telemetry / Privacy Policy**: Reject any dependency or code that introduces analytics, third-party beacons, or telemetry.
  2. **Cross-Agent Coordination**:
     - Ensure Agent 1 and Agent 2 stay in sync when modifying scripts or build-time parameters.
     - Conduct architectural review on all refactorings to ensure changes actually decrease cognitive complexity rather than just moving code around.
  3. **Safe Host Rules**:
     - Never run host-level commands that interfere with user processes (e.g. **NEVER** run `tmux kill-server` or touch the host user's tmux sockets).

---

## 3. Key Technical Invariants & Guardrails

| Area | Invariant | Reason |
| :--- | :--- | :--- |
| **Terminal Mouse Handler** | `ShellLiteMouseHandler.resolveButtonId(wheelUp) == 64`<br>`ShellLiteMouseHandler.resolveButtonId(wheelDown) == 65`<br>`(buttonId & 4) == 0` | Standard XTerm DECSET 1006 SGR mode. If bit 2 (`+4`) is set, `tmux` decodes wheel events as `S-WheelUpPane` and drops them. |
| **Tmux Startup** | `SSHService.buildTmuxCommand` forces `set -g mouse on` | Ensures scrolling works even if remote server's `~/.tmux.conf` overrides mouse mode to off. |
| **Credential Storage** | `flutter_secure_storage` with Android KeyStore AES-GCM-256 and iOS Keychain | Hardware-backed security. Passwords and private keys must never touch plaintext `SharedPreferences` or disk. |
| **Git Push Rule** | **Commit locally. Push ONLY when asked.** | Prevents unintended CI/CD runs, automated tagging, or store deployments. |
| **Documentation Rule**| Only `README.md` and `.agents/skills/build-shelllite/SKILL.md` | Prevents stale duplicates and fragmented documentation. |
| **Google Play Notes** | `whatsnew/whatsnew-en-US` <= 500 characters, no headings, no commit hashes | Google Play Developer API hard limit. Exceeding 500 chars fails deployment immediately. |

---

## 4. Current Codebase Hotspots & Recommended Tasks

### Priority 1: Flutter Monolith Decomposition (Agent 1)
- [ ] **`lib/screens/server_form_screen.dart` (935 lines)**:
  - Extract authentication method subsections (`PasswordAuthSection`, `KeyAuthSection`, `PassphraseSection`).
  - Extract the persistent session (`tmux`) configuration panel.
- [ ] **`lib/widgets/keyboard_accessory_bar.dart` (902 lines)**:
  - Extract the drawer key picker, custom key dialog, and sticky modifier controller into focused sub-widgets under `lib/widgets/accessory_bar/`.
- [ ] **`lib/widgets/file_upload_modal.dart` (818 lines)**:
  - Separate file picker abstraction from the modal presentation and progress tracking UI.
- [ ] **`lib/screens/terminal_screen.dart` (856 lines)**:
  - Decompose the session context menu, search overlay, and selection toolbar into dedicated components.

### Priority 2: CI/CD & Workflow Optimization (Agent 2)
- [ ] **Actions Audit & Node 24 Readiness**:
  - Update action pinned commits to ensure full compatibility with Node 24 runner migration.
- [ ] **Concurrency & Redundancy Audit**:
  - Verify all push workflows (`ci.yml`, `codeql.yml`) have proper path filtering (`paths-ignore` for documentation and markdown) and cancellation of obsolete in-progress runs.
- [ ] **AAB Build Optimization**:
  - Evaluate if the combined build step in `release.yml` can share Flutter artifacts between APK and AAB without redundant recompilation.

### Priority 3: Architecture & Governance (Agent 3)
- [ ] Review all changes for strict backward compatibility with stored user profiles.
- [ ] Verify that every refactoring is accompanied by corresponding unit/widget test coverage.
- [ ] Maintain git hygiene (clean Conventional Commit scopes: `feat(terminal)`, `fix(tmux)`, `refactor(server_form)`, `ci(workflow)`).

---

## 5. Verification Commands & Standard Operating Procedures

Before finalizing any task, agents must execute and verify the following locally:

```bash
# 1. Dependency integrity
flutter pub get

# 2. Static analysis (Must report: "No issues found!")
flutter analyze

# 3. Test suite (Must pass 100%)
flutter test

# 4. Semantic release dry-run (Preview next version and notes locally)
./scripts/resolve_version.sh auto

# 5. Git status & local commit (Do NOT push unless requested)
git status
git add <modified-files>
git commit -m "<type>(<scope>): <clear description>"
```
