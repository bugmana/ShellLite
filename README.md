# ShellLite ⚡

[![CI](https://github.com/bugmana/ShellLite/actions/workflows/ci.yml/badge.svg)](https://github.com/bugmana/ShellLite/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Linux%20%7C%20Web-blue)](https://github.com/bugmana/ShellLite)

> Modern, secure, lightweight SSH client and terminal emulator for **iOS**, **Android**, **Linux**, and **Web**, built with Flutter & Dart.

---

## ✨ Features

- **Pure Dart SSHv2 Engine**: Powered by [`dartssh2`](https://pub.dev/packages/dartssh2) with interactive PTY shell sessions.
- **Hardware-Accelerated Terminal**: ANSI/VT100 rendering via [`xterm.dart`](https://pub.dev/packages/xterm) with custom cursor styling, scrollback buffer, and dynamic resizing.
- **Multiple Theme Presets**: Pre-configured terminal and UI palettes (**Obsidian**, **Catppuccin Mocha**, **Dracula**, **Nord**, **Tokyo Night**, and **Solarized Dark**).
- **Flexible Authentication & Key Generator**: Password auth, unencrypted OpenSSH keys (**Ed25519**, **ECDSA**, **RSA**), and a built-in **Ed25519 key generator**.
- **Hardware-Backed Encryption**: Secure storage for server credentials via [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) (iOS Keychain / Android KeyStore / Linux Secret Service).
- **Biometric Security**: Protect your servers and sessions with Face ID, Touch ID, or Android Biometric Prompt.
- **Directional Navigation HUD**: Press-and-hold virtual joystick overlay for effortless cursor navigation and command history scrolling on mobile touchscreens.
- **Live Server Telemetry**: Background health dashboard monitoring CPU load, memory usage, disk utilization, and uptime.
- **Persistent Sessions (tmux)**: Automatic tmux session attach and reconnection resilience.
- **Customizable Keyboard Accessory Bar**: Dedicated tactile shortcuts (`⇥ Tab`, `^C`, `^D`, `↑`, `↓`, `←`, `→`, `Esc`, macros) with drag-and-drop reordering and custom keys.

---

## 📦 Download & Installation

### 🤖 Android
- Download the latest **`ShellLite.apk`** from [GitHub Releases](https://github.com/bugmana/ShellLite/releases) and open it on your Android device to install directly.
- Store distribution packages are also available as **`ShellLite.aab`** (Android App Bundle).

### 🍏 iOS
- Download the latest **`ShellLite.ipa`** from [GitHub Releases](https://github.com/bugmana/ShellLite/releases) and install via **SideStore**, **AltStore**, or **Sideloadly**.

### 🌐 Web Demo
- Try the live web version instantly in your browser at **[https://shell.strandberg.dev/](https://shell.strandberg.dev/)**.

---

## 📁 Project Structure

```text
ShellLite/
├── docs/                           # Publishing, deployment & handover guides
│   └── GOOGLE_PLAY_HANDOVER.md     # Google Play Store publishing & release guide
├── lib/                            # Application source code
│   ├── config/                     # App constants, terminal, accessory & storage configs
│   ├── models/                     # ServerProfile, AuthMethod, ServerTelemetry
│   ├── providers/                  # ServerStore, SessionStore, TelemetryStore, SecurityStore, TerminalSettingsStore
│   ├── screens/                    # ServerListScreen, ServerFormScreen, TerminalScreen
│   ├── services/                   # KeyParser, KeyGenerator, SSHService, StorageService, TelemetryService
│   ├── theme/                      # Dynamic multi-theme palettes & TerminalThemePresets
│   └── widgets/                    # AccessoryBar, DirectionalHUD, SearchBar, Modals, AppLockScreen
├── test/                           # Comprehensive unit & widget test suites
└── .github/workflows/              # Automated CI/CD & Multi-Platform Release workflows
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue for bug reports and feature suggestions.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Ensure all tests pass (`flutter test && flutter analyze`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
