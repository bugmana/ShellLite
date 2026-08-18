# ShellLite ⚡

> Modern, lightweight, cross-platform SSH client & terminal emulator for **iOS**, **Android**, and **Linux** built with Flutter & Dart.

---

## ✨ Features

* **Pure Dart SSHv2 Engine**: Powered by [`dartssh2`](https://pub.dev/packages/dartssh2) with interactive PTY shell sessions.
* **ANSI Terminal Emulator**: Hardware-accelerated terminal rendering via [`xterm.dart`](https://pub.dev/packages/xterm) with VT100 styling, cursor handling, screen buffers, and window resizing.
* **Flexible Authentication & Key Generator**: Password auth, unencrypted OpenSSH keys (**Ed25519**, **ECDSA**, **RSA**), and built-in **Ed25519 key generator**.
* **Encrypted Storage**: Secure credentials via [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) (Keychain / KeyStore / Secret Service).
* **Directional HUD Overlay**: Floating gesture joystick activated on press-and-hold for smooth terminal navigation and autocomplete.
* **Multiple Theme Presets**: Pre-configured terminal and UI themes (Obsidian, Catppuccin Mocha, Dracula, Nord, Tokyo Night, Solarized Dark).
* **Command Snippet Manager**: Save, categorize, parameterize (`{{param}}`), and execute frequent SSH command snippets.
* **Background Health Telemetry**: Live CPU load, RAM usage, disk consumption, and server uptime monitoring.
* **Biometric App Lock**: Face ID / Fingerprint protection with sticky auth.
* **Persistent Sessions (tmux)**: Automatic tmux auto-attach / session preservation across disconnections.
* **Keyboard Accessory Bar**: Quick touch shortcuts for `⇥ Tab`, `^C`, `^D`, `↑`, `↓`, `←`, `→`, `Esc`, `|`, `~`, `/`, and `-`.

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

## 🌐 Web & Mobile Safari Development

ShellLite is hosted over **HTTPS on port 443** for instant testing on **Safari (iPhone 14)** and desktop browsers:

- **Live URL**: [https://shell.strandberg.dev/](https://shell.strandberg.dev/)
- **Automatic SSL**: Let's Encrypt managed by Caddy.

### 🔥 Automatic Hot Reload on File Save

Whenever you edit and save any `.dart` file in `lib/`, the development server **automatically detects changes and hot-reloads instantly (~100ms–200ms)**. No manual commands needed!

> [!IMPORTANT]
> **Server Rebuild / Restart After Each Implementation**:
> After finishing each feature implementation or modifying dependencies/models, always rebuild or restart the development server service to ensure a clean state and proper asset compilation:
> ```bash
> sudo systemctl restart shelllite  # Restart / rebuild server state
> ```

Manual controls:
```bash
sudo systemctl reload shelllite   # Force manual Hot Reload
sudo systemctl restart shelllite  # Force clean restart & rebuild
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
│   ├── main.dart                       # App entry point, MultiProvider & Theme init
│   ├── config/                         # App constants, terminal & storage configs
│   ├── models/                         # ServerProfile, AuthMethod, Snippet, ServerTelemetry
│   ├── providers/                      # ServerStore, SessionStore, SnippetStore, TelemetryStore, SecurityStore
│   ├── screens/                        # ServerListScreen, ServerFormScreen, TerminalScreen, SnippetManagerScreen
│   ├── services/                       # KeyParser, KeyGenerator, SSHService, StorageService, TelemetryService, SecurityService
│   ├── theme/                          # Dynamic multi-theme palettes & TerminalThemePresets
│   └── widgets/                        # KeyboardAccessoryBar, ServerCard, DirectionalHUD, SearchBar, Modals
├── test/                               # Comprehensive unit & widget test suites
├── .github/workflows/
│   ├── ci.yml                          # Parallel CI (tests, web, android, and ios builds)
│   ├── build-android.yml               # Reusable Android APK & AAB packager
│   ├── build-ios.yml                   # Reusable iOS build & IPA packager
│   └── release.yml                     # Unified multi-platform release workflow
└── pubspec.yaml
```

---

## 📦 Releases & Sideloading

### 🤖 Android Installation
1. Download **`ShellLite.apk`** from [GitHub Releases](https://github.com/bugmana/ShellLite/releases).
2. Open the `.apk` file on your Android device to install (allow *Install unknown apps* when prompted).
3. Alternatively, developers can use **`ShellLite.aab`** for Google Play distribution.

### 🍏 iOS Sideloading
1. Download **`ShellLite.ipa`** from [GitHub Releases](https://github.com/bugmana/ShellLite/releases).
2. Install via your preferred sideloading method:
   - **SideStore**: Open `ShellLite.ipa` directly in the SideStore app on your iPhone.
   - **AltStore / Sideloadly**: Select `ShellLite.ipa` from your PC/Mac and install to your connected iOS device.

### 🚀 Triggering a New Release (GitHub Actions)
1. Go to **Actions** → **[Release Multi-Platform](https://github.com/bugmana/ShellLite/actions/workflows/release.yml)**.
2. Click **Run workflow** and choose your version bump level (`patch`, `minor`, `major`, or `custom`).
3. GitHub Actions will automatically tag the version, compile both iOS and Android release bundles in parallel, and publish a new GitHub Release with `ShellLite.ipa`, `ShellLite.apk`, and `ShellLite.aab`.

---

## 📄 License
MIT License.
