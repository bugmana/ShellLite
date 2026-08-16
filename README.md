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
* **First-Class Linux Emulation**: Run and test the full UI, state, and SSH terminal flow directly on Linux with sub-second **Hot Reload**.

---

## 🐧 Linux Development & Emulation

ShellLite can be run natively on Linux desktop for rapid UI development, terminal emulation, and end-to-end SSH testing.

### 1. Install System Dependencies

#### Ubuntu / Debian / Pop!_OS
```bash
sudo apt update
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev libjsoncpp-dev
```

#### Fedora
```bash
sudo dnf install -y clang cmake ninja-build pkg-config gtk3-devel libsecret-devel jsoncpp-devel
```

#### Arch Linux / Manjaro
```bash
sudo pacman -S --needed clang cmake ninja pkgconf gtk3 libsecret jsoncpp
```

### 2. Enable Linux Desktop in Flutter
```bash
flutter config --enable-linux-desktop
```

### 3. Run Locally with Hot Reload
```bash
flutter run -d linux
```
* Press `r` in the terminal for **Hot Reload**.
* Press `R` for **Hot Restart**.
* Press `q` to quit.

### 4. Build Standalone Linux App
```bash
flutter build linux --release
```
The compiled binary will be located at `build/linux/x64/release/bundle/shell_lite`.

---

## 🧪 Testing & Code Quality

Run the test suite locally (runs without requiring any native compiler):
```bash
# Run all 25 unit & widget tests
flutter test

# Run static analysis / linting
flutter analyze
```

---

## 🛠️ Architecture & Directory Layout

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
│   ├── ci.yml                          # Fast Ubuntu CI for analysis & tests
│   ├── build-ios.yml                   # Reusable Flutter iOS build & IPA packager
│   └── release.yml                     # One-click release workflow for ShellLite.ipa
├── release.sh                          # Interactive release automation script
└── pubspec.yaml                        # Flutter package configuration
```

---

## 📦 iOS Builds & Release Pipeline

> **Note:** The iOS build pipeline can be triggered on demand via GitHub Actions once ready.

### Local iOS Build (macOS host)
```bash
flutter build ios --no-codesign --release
```

### GitHub Actions Workflows
* **CI Workflow (`ci.yml`)**: Runs on `ubuntu-latest` to verify static analysis and run all unit/widget tests on every commit and PR.
* **Build iOS (`build-ios.yml`)**: Compiles the Flutter iOS project and packages `ShellLite.ipa` with ad-hoc signing for sideloading.
* **Release (`release.yml`)**: One-click manual trigger or tag push to build, package `ShellLite.ipa`, and publish to GitHub Releases.

### Sideloading on iPhone
1. Download `ShellLite.ipa` from [GitHub Releases](https://github.com/bugmana/ShellLite/releases).
2. Open in **SideStore** or install via **Sideloadly / AltStore**.
3. Trust your Apple ID certificate under **Settings > General > VPN & Device Management** and launch **ShellLite**!

---

## 📄 License
MIT License.
