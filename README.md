# ShellLite ⚡

> Modern, lightweight, cross-platform SSH client & terminal emulator for **iOS**, **Android**, and **Linux** built with Flutter & Dart.

---

## ✨ Features

* **Pure Dart SSHv2 Engine**: Powered by [`dartssh2`](https://pub.dev/packages/dartssh2) with interactive PTY shell sessions.
* **Full ANSI Terminal Emulator**: Hardware-accelerated terminal rendering via [`xterm.dart`](https://pub.dev/packages/xterm) with VT100 colors, cursor handling, screen buffers, and dynamic window resizing.
* **Flexible Authentication**:
  * Password authentication with secure storage.
  * Unencrypted OpenSSH private keys (**Ed25519**, **ECDSA P-256/P-384/P-521**, **RSA**).
* **Encrypted Credential Storage**: Uses [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) (iOS Keychain, Android EncryptedSharedPreferences/KeyStore, Linux Secret Service).
* **Terminal Keyboard Accessory Bar**: Quick-access shortcuts for `⇥ Tab`, `^C`, `^D`, `↑`, `↓`, `←`, `→`, `Esc`, `|`, `~`, `/`, and `-`.
* **Startup Commands**: Optionally specify an initial command (e.g. `tmux attach || tmux new`, `htop`) to run automatically upon connection.
* **Local Emulation on Linux**: Run and test the full UI and SSH terminal flow directly on your Linux desktop with sub-second **Hot Reload**.

---

## 🛠️ Tech Stack

* **Framework:** [Flutter 3.24+](https://flutter.dev)
* **Language:** [Dart 3.5+](https://dart.dev)
* **Key Libraries:**
  * `dartssh2` — SSHv2 client implementation
  * `xterm` — ANSI / VT100 terminal emulator widget
  * `flutter_secure_storage` — Hardware-backed encrypted credential storage
  * `shared_preferences` — Server profile list persistence
  * `provider` — State management
  * `uuid` — Unique profile identifiers

---

## 📁 Architecture & Directory Layout

```text
ShellLite/
├── lib/
│   ├── main.dart                       # App entry point, MultiProvider & Theme setup
│   ├── models/
│   │   ├── auth_method.dart            # PasswordAuth & SSHKeyAuth types
│   │   └── server_profile.dart         # Server profile model with JSON serialization
│   ├── providers/
│   │   └── server_store.dart           # ChangeNotifier for profile CRUD & state
│   ├── screens/
│   │   ├── server_list_screen.dart     # Server profiles list with search & empty state
│   │   ├── server_form_screen.dart     # Add/Edit server profile form with key validator
│   │   └── terminal_screen.dart        # xterm.dart ANSI terminal view & SSH stream piping
│   ├── services/
│   │   ├── key_parser.dart             # OpenSSH PEM parser & encryption validator
│   │   ├── ssh_service.dart            # dartssh2 client wrapper & PTY lifecycle
│   │   └── storage_service.dart        # Secure storage & preferences manager
│   ├── theme/
│   │   └── app_theme.dart              # Dark terminal color palette & component themes
│   └── widgets/
│       ├── keyboard_accessory_bar.dart # Scrollable terminal shortcut toolbar
│       └── server_card.dart            # Server profile list item card
├── test/
│   ├── models/                         # Model serialization & equality tests
│   ├── providers/                      # ServerStore CRUD tests
│   ├── services/                       # Key parser & secure storage tests
│   └── widgets/                        # Widget rendering & interaction tests
├── .github/workflows/
│   ├── build-ios.yml                   # Reusable Flutter test & iOS build workflow
│   ├── ci.yml                          # Continuous integration for PRs & main
│   └── release.yml                     # One-click release workflow for ShellLite.ipa
├── release.sh                          # Interactive release automation script
└── pubspec.yaml                        # Flutter package configuration
```

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (`3.24.0` or newer)
* Linux, macOS, or Windows host

### Local Setup & Testing on Linux
1. **Clone the repository:**
   ```bash
   git clone https://github.com/bugmana/ShellLite.git
   cd ShellLite
   ```
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```
3. **Run unit & widget tests:**
   ```bash
   flutter test
   ```
4. **Run static analysis:**
   ```bash
   flutter analyze
   ```
5. **Run locally on Linux Desktop with Hot Reload:**
   ```bash
   flutter run -d linux
   ```

---

## 📦 Building & Releases

### Building for iOS (IPA)
To compile an `.ipa` for sideloading on iPhone:
```bash
flutter build ios --no-codesign --release
```

### GitHub Actions Automation
* **CI Workflow**: Automatically runs static analysis, executes all 25 unit/widget tests, and verifies the iOS build on every PR and commit to `main`.
* **Release Workflow**: Triggered by pushing a version tag (e.g. `./release.sh 1.0.2`) or via **One-Click Release** in the GitHub Actions UI to build, sign ad-hoc, package `ShellLite.ipa`, and publish to GitHub Releases.

### Sideloading on iPhone
1. Download `ShellLite.ipa` from [GitHub Releases](https://github.com/bugmana/ShellLite/releases).
2. Open in **SideStore** or install via **Sideloadly / AltStore**.
3. Trust your Apple ID certificate under **Settings > General > VPN & Device Management** and launch **ShellLite**!

---

## 📄 License
MIT License.
