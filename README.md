# ShellLite

[![CI](https://github.com/bugmana/ShellLite/actions/workflows/ci.yml/badge.svg)](https://github.com/bugmana/ShellLite/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Web-blue)](https://github.com/bugmana/ShellLite)

SSH client and terminal emulator for iOS, Android, and Web, built with Flutter.

---

## Platforms

ShellLite targets three platforms:

- **Android**: Distributed as standalone APK (`ShellLite.apk`) and Google Play Store App Bundle (`ShellLite.aab`).
- **iOS**: Distributed as sideloadable IPA (`ShellLite.ipa`) for installation via SideStore, AltStore, or Sideloadly.
- **Web**: Hosted single-page application connecting to SSH servers through a WebSocket bridge. Live deployment: [https://shell.strandberg.dev/](https://shell.strandberg.dev/).

---

## Features

### SSH and Terminal Emulation
- Pure Dart SSHv2 protocol client via [`dartssh2`](https://pub.dev/packages/dartssh2).
- ANSI/VT100 terminal emulation via [`xterm.dart`](https://pub.dev/packages/xterm) with dynamic PTY window resizing and configurable scrollback up to 10,000 lines.
- Stateful UTF-8 stream decoding to prevent character truncation across network packet boundaries.
- Six color presets: ShellLite Obsidian, Catppuccin Mocha, Dracula, Nord, Tokyo Night, and Solarized Dark.
- Adjustable terminal font size (10 to 22 pt) using JetBrains Mono with system fallbacks.
- Touch text selection with draggable start/end handles and a floating copy/select-all toolbar.

### Keyboard Accessory Bar
- Mobile-optimized key row: Tab, Shift+Tab, arrow keys, Escape, and quick interrupt (`^C`).
- Sticky modifier keys: `Ctrl` and `Alt` supporting single-tap latch (applies to next keystroke) and double-tap lock.
- Customizable keys: Add custom keys with escape sequences (`\e`, `\t`, `\n`, `^C`, hex `\x1b`) and reorder via drag-and-drop.
- Inline expandable drawer organizing Control, Navigation, and Function (F1–F12) keys.
- Haptic feedback on keystroke (can be disabled in settings).

### Authentication and Key Management
- Password authentication and unencrypted or passphrase-encrypted OpenSSH private keys (Ed25519, ECDSA, RSA).
- Built-in on-device Ed25519 key generator with one-tap public key copying and automated `authorized_keys` setup scripts.
- Clipboard auto-parser for connection strings (extracts host, port, and user from `ssh -p <port> <user>@<host>`).
- Credentials encrypted locally via hardware security: Apple Keychain on iOS and KeyStore on Android.
- Limit of 10 configured server profiles.

### File Transfer
- Upload files directly to the remote server from within the terminal session.
- Chunked streaming (32 KB chunks) with progress tracking and cancellation.
- SFTP on native platforms; streamed standard input (`cat > remote_file`) on Web to circumvent JavaScript runtime limitations with 64-bit integer SFTP packet offsets.
- Native file picker on iOS and Android; DOM file input element on Web.

### Session Persistence and Telemetry
- Optional automatic `tmux` session attach (`tmux new-session -A -s <name>`), falling back to standard shell if `tmux` is absent.
- Initial command execution on connect when persistent session is disabled.
- Server telemetry queried over SSH: CPU load/utilization, memory consumption, root disk usage, and uptime.

### Privacy
- All credentials, private keys, and session data remain on the local device.
- Zero analytics SDKs, advertising frameworks, or tracking beacons.
- In-app and web privacy policy: [https://strandberg.dev/privacy/shelllite/](https://strandberg.dev/privacy/shelllite/).

---

## Architecture

```text
               +---------------------------------------------------+
               |                    ShellLite                      |
               |       (Flutter UI + Provider State Stores)        |
               +---------------------------------------------------+
                                         |
                      +------------------+------------------+
                      |                                     |
              [iOS / Android]                             [Web]
                      |                                     |
              Direct TCP Socket                    WebSocket (wss://)
                      |                                     |
                      |                           +-------------------+
                      |                           | Reverse Proxy     |
                      |                           | (Caddy / Nginx)   |
                      |                           +-------------------+
                      |                                     |
                      |                           +-------------------+
                      |                           | websockify        |
                      |                           +-------------------+
                      |                                     |
                      |                                TCP Socket
                      |                                     |
                      +------------------+------------------+
                                         |
                                  SSH Server (:22)
```

Web browsers cannot establish raw TCP socket connections. For the Web target, ShellLite connects via a WebSocket bridge:
1. ShellLite Web initiates a WebSocket connection to `wss://<host>/ssh-ws`.
2. A reverse proxy (e.g., Caddy or Nginx) terminates TLS and routes `/ssh-ws` to `websockify`.
3. `websockify` bridges WebSocket frames to the target SSH TCP port (`127.0.0.1:22`).

Native targets (iOS and Android) connect directly to SSH servers over TCP.

---

## Development and Build

### Prerequisites
- Flutter SDK (3.24+ stable channel)
- Java 17 (for Android builds)
- Xcode 15+ and macOS (for iOS builds)

### Setup
```bash
git clone https://github.com/bugmana/ShellLite.git
cd ShellLite
flutter pub get
```

### Build Commands

#### Web
```bash
flutter build web --base-href /
```

#### Android
```bash
# APK
flutter build apk --release

# App Bundle (for Google Play Store)
flutter build appbundle --release
```

#### iOS
```bash
flutter build ipa --release
```

### Verification
```bash
# Static analysis
flutter analyze

# Test suite
flutter test
```

---

## Project Structure

```text
ShellLite/
├── docs/                     Documentation, release notes, and store assets
│   ├── GOOGLE_PLAY_HANDOVER.md
│   └── store_assets/
├── lib/
│   ├── config/               Application limits, terminal styles, key definitions
│   ├── models/               ServerProfile, AuthMethod, ServerTelemetry
│   ├── providers/            ServerStore, SessionStore, TelemetryStore, TerminalSettingsStore
│   ├── screens/              Server list, server form, terminal, privacy policy
│   ├── services/             SSH service, socket factory, file transfer, key generator, storage
│   ├── theme/                Theme presets, application palettes, typography
│   └── widgets/              Keyboard accessory bar, file upload, selection handles, modals
├── test/                     Unit, widget, and integration test suites
├── scripts/                  Version resolution and release automation
└── .github/workflows/        CI/CD workflows for Android, iOS, and Web releases
```

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
