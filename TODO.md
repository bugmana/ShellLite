# ShellLite — Development Roadmap & Completed Features

## 📋 Milestone 1: Terminal Experience & Personalization

### 1. 🎨 Curated Themes & Font Customization
- [x] Implement theme preset selector in settings/terminal config:
  - Presets: *ShellLite Obsidian (Default), Catppuccin Mocha, Dracula, Nord, Tokyo Night, Solarized Dark*.
- [x] Support custom font size (slider/stepper) and line height adjustments.
- [x] Bundled Monospace styling for powerline and glyph rendering.
- [x] Persist user theme and typography preferences in `StorageService`.

### 2. 🔍 Terminal Buffer Search & Session Export
- [x] Add in-terminal text search bar (`Ctrl+F` shortcut & AppBar search button).
- [x] Highlight search matches and support navigation (`Next` / `Previous`).
- [x] Add "Export / Copy Buffer Log" action to copy full terminal scrollback to clipboard.
- [x] Clear screen, paste clipboard, and quick gestures guide shortcuts.

---

## ⚡ Milestone 2: Productivity & Key Management

### 3. ⚡ Command Snippets & Quick Actions Bar
- [x] Create `Snippet` data model (`id`, `title`, `command`, `category`).
- [x] Build Snippets Manager screen (CRUD operations for command macros).
- [x] Add quick snippet runner bottom sheet (`SnippetRunnerSheet`) accessible directly from the terminal accessory bar.
- [x] Support parameter placeholders (e.g. `{{service_name}}` or `{{container_name}}`) with prompt on execution.

### 4. 🔑 In-App SSH Key Generator (`ssh-keygen`)
- [x] Implement in-app key pair generation for **Ed25519 (256-bit)** using pure Dart cryptography (`pinenacl`).
- [x] Key Generator UI modal (`SSHKeyGeneratorDialog`):
  - Custom key comment / label.
  - Fingerprint badge.
  - Public Key export box with one-tap copy.
- [x] Directly save generated private key into a new or existing Server Profile.

---

## 🔀 Milestone 3: Multi-Session Management & Monitoring

### 5. 🔀 Persistent Session Management & Quick Switcher
- [x] Manage active server connection via persistent `SessionStore`.
- [x] Support background session retention when navigating back to the server list.
- [x] Remote exit (`exit` / `Ctrl+D`) cleanly cleans up session and returns to server list.
- [x] Active server highlight indicator in the server list with instant re-attach.

### 6. 📊 Server Health Quick Glance (CPU / RAM / Disk Widgets)
- [x] Implement lightweight SSH telemetry collector (`TelemetryService`).
- [x] Add telemetry mini chips on `ServerCard` in the Server List:
  - CPU load average
  - Memory usage percentage (e.g. `1.8G / 7.7G`)
  - Root disk usage (e.g. `45G / 234G`)
- [x] Add pull-to-refresh and one-tap health check button.

---

## 🔒 Milestone 4: Security & Biometrics

### 7. 🔒 Biometric App Lock & Credential Protection
- [x] Integrate `local_auth` for Face ID, Touch ID, and Fingerprint Prompt (`SecurityService`).
- [x] Add "Biometric App Lock" setting toggle in the Appearance & Security modal.
- [x] Full-screen `AppLockScreen` requiring authentication on launch.
