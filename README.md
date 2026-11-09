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
- Terminal text size from 10 to 22 pt, adjusted with the minus and plus buttons in Settings.
- Touch text selection with draggable handles, edge scrolling, and a floating action toolbar.
- Tap or long-press printed HTTP(S) links to select the full URL and copy it with **Copy link**.

### Keyboard Accessory Bar
- One key row with Escape, Tab, Ctrl, arrows, Paste, More keys, and the keyboard toggle.
- Sticky modifier keys: `Ctrl` and `Alt` supporting single-tap latch (applies to next keystroke) and double-tap lock.
- Customizable keys: Add custom keys with escape sequences (`\e`, `\t`, `\n`, `^C`, hex `\x1b`) and reorder via drag-and-drop.
- More keys opens one sheet with control, navigation, function, and tmux shortcuts. Customize keys in Settings.
- Haptic feedback on keystroke (can be disabled in settings).

### Authentication and Key Management
- Password authentication and unencrypted or passphrase-encrypted OpenSSH private keys (Ed25519, ECDSA, RSA).
- Credentials encrypted locally via hardware security: Apple Keychain on iOS and KeyStore on Android.
- Limit of 10 configured server profiles.
- Start with Host, Username, and authentication. More options contains Name, Port, tmux, and Startup command. Startup command stays editable with tmux enabled and runs on connections without tmux.

### File Transfer
- Upload one file from the terminal menu. Confirm the destination folder (home by default), then tap Upload.
- Chunked transfers with progress and cancellation. Existing files require replacement confirmation; uploads are staged before publishing the final file.
- SFTP on native platforms; streamed standard input (`cat > remote_file`) on Web to circumvent JavaScript runtime limitations with 64-bit integer SFTP packet offsets.
- Native file picker on iOS and Android; DOM file input element on Web.

### Session Persistence
- Optional automatic `tmux` session attach (`tmux new-session -A -s <name>`), falling back to standard shell if `tmux` is absent.
- Initial command execution on connect when persistent session is disabled.

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

## Using terminal links and selection

Tap or long-press a printed `http://` or `https://` URL to select the whole link, including soft-wrapped lines, then tap **Copy link**. Paste it into your preferred browser. Printed URL taps stay in ShellLite for copying, even when a remote app requests mouse input. Other taps keep their normal terminal behavior.

For other output, long-press a word and drag the selection handles to adjust the range. Drag near the top or bottom of the terminal to scroll through output. Choose **Copy** to copy the selection or **Select All** to select the buffer.

When pasting a link into your device browser, `localhost` refers to that device, not the remote SSH server. ShellLite does not automatically create a tunnel. Bare domains and hidden OSC 8 hyperlink targets are not detected.

## Contributing

Use Flutter stable with the Dart SDK required by [`pubspec.yaml`](pubspec.yaml). Android builds require Java 17; iOS builds require macOS and Xcode.

```bash
flutter pub get
flutter run -d chrome
```

Run local checks with one dependency setup:

```bash
./scripts/check.sh                              # analysis and all tests
./scripts/check.sh test/services/terminal_link_test.dart  # analysis and focused tests
./scripts/check.sh --web                        # also build Web for release
```

Use focused tests while editing, then run the full command before pushing. CI still runs the full suite and platform builds.

Run a browser smoke test against the deployed app:

```bash
python3 -m venv /tmp/shelllite-smoke
/tmp/shelllite-smoke/bin/pip install -r scripts/requirements-web-smoke.txt
/tmp/shelllite-smoke/bin/python -m playwright install chromium
/tmp/shelllite-smoke/bin/python scripts/web_smoke.py
/tmp/shelllite-smoke/bin/python scripts/web_smoke.py --mobile
```

The test types into the real UI, adds a dummy server, reloads, checks its saved fields, and deletes it. Each run uses isolated browser storage and blocks WebSockets; no SSH connection is made. Use `--url http://localhost:8080` for a locally served web build. Traces and failure screenshots go to `build/web-smoke/`. The manual **Web smoke** Actions workflow runs desktop and mobile viewport checks against `https://shell.strandberg.dev`; mobile emulation does not replace device testing.

See [Repository Guidelines](AGENTS.md) for project structure, build and test commands, code style, and pull request conventions. CI definitions in [`.github/workflows/`](.github/workflows/) describe the checks and platform builds used for code changes.

## Releases and web deployment

Native releases and the hosted web app deploy separately.

After checking and pushing changes to `main`, create a release with:

```bash
gh workflow run release.yml -f bump_type=auto -f deploy_to_play_store=true -f play_store_track=internal
gh run list --workflow=release.yml
gh run watch <run-id>
```

The workflow derives the next version from Conventional Commits, creates a tag, builds Android and iOS artifacts, publishes a GitHub release with release notes, and deploys the Android bundle to Google Play internal testing. Use the workflow's `custom_changelog` and `custom_play_store_notes` inputs for curated notes; Play notes must be at most 500 characters. Production promotion is a separate action.

On the host serving `shell.strandberg.dev`, rebuild the web app with the release version:

```bash
flutter build web --release --base-href / --build-name=1.11.3
chmod -R a+rX build/web
```

The host serves `build/web/` through its reverse proxy. GitHub release publication does not update that directory. The optional watcher units in `systemd/` are not installed on the current host; rebuild explicitly. Verify the served build and run the desktop/mobile smoke checks after deploying. The manual **Web smoke** workflow can also run these checks with `gh workflow run web-smoke.yml`.

The sibling [`strandberg.dev`](https://github.com/bugmana/strandberg.dev) repository publishes the main website and ShellLite privacy page through GitHub Pages. Its deployment does not rebuild the ShellLite app.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
