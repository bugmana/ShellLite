# ShellLite ⚡

> Modern, lightweight, cross-platform SSH client & terminal emulator for **iOS**, **Android**, and **Linux** built with Flutter & Dart.

---

## ✨ Features

* **Pure Dart SSHv2 Engine**: Powered by [`dartssh2`](https://pub.dev/packages/dartssh2) with interactive PTY shell sessions.
* **ANSI Terminal Emulator**: Hardware-accelerated terminal rendering via [`xterm.dart`](https://pub.dev/packages/xterm) with VT100 styling, cursor handling, screen buffers, and window resizing.
* **Flexible Authentication**: Password auth and unencrypted OpenSSH keys (**Ed25519**, **ECDSA**, **RSA**).
* **Encrypted Storage**: Secure credentials via [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) (Keychain / KeyStore / Secret Service).
* **Keyboard Accessory Bar**: Quick touch shortcuts for `⇥ Tab`, `^C`, `^D`, `↑`, `↓`, `←`, `→`, `Esc`, `|`, `~`, `/`, and `-`.
* **Startup Commands**: Optional command execution upon connect (e.g. `tmux attach || tmux new`).

---

## 🐧 Linux Development

Run and test the full app locally on Linux with **Hot Reload**:

```bash
# 1. Install build dependencies (Debian / Ubuntu)
sudo apt update && sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev

# 2. Run with Hot Reload
flutter run -d linux

# 3. (Optional) Build release binary
flutter build linux --release
```

---

## 🧪 Testing & Linting

```bash
flutter test       # Runs all unit & widget tests
flutter analyze    # Runs static analysis
```

---

## 📁 Project Structure

```text
ShellLite/
├── lib/
│   ├── main.dart                       # App entry point & MultiProvider
│   ├── models/                         # ServerProfile & AuthMethod
│   ├── providers/                      # ServerStore (state & CRUD)
│   ├── screens/                        # ServerListScreen, ServerFormScreen, TerminalScreen
│   ├── services/                       # KeyParser, SSHService, StorageService
│   ├── theme/                          # Terminal dark theme
│   └── widgets/                        # KeyboardAccessoryBar, ServerCard
├── test/                               # Model, provider, service & widget tests
├── .github/workflows/
│   ├── ci.yml                          # CI workflow (analysis, tests & iOS build verification on main)
│   ├── build-ios.yml                   # Reusable iOS build & IPA packager
│   └── release.yml                     # Manual release workflow (workflow_dispatch)
└── pubspec.yaml
```

---

## 📦 iOS Sideloading

1. Trigger the **Release iOS IPA** workflow in GitHub Actions (or run `flutter build ios --no-codesign --release` on macOS).
2. Download `ShellLite.ipa` from [GitHub Releases](https://github.com/bugmana/ShellLite/releases).
3. Install via **SideStore**, **Sideloadly**, or **AltStore**.

---

## 📄 License
MIT License.
