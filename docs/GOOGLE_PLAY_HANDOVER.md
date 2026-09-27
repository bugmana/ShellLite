# ShellLite: Google Play Store Handover & Publishing Guide

This document contains instructions, configurations, metadata, and checklists for publishing **ShellLite** (`com.bugmana.shell_lite`) to Google Play Console.

---

## Quick Reference

| Field | Value |
| :--- | :--- |
| **App Name** | `ShellLite` |
| **Package Name / Application ID** | `com.bugmana.shell_lite` |
| **Compile / Target SDK** | `36` (Android 16) |
| **Minimum SDK** | `23` (Android 6.0+) |
| **App Category** | Tools / Productivity |
| **Content Rating** | Everyone (General Utility) |
| **Primary Artifact** | Android App Bundle (`.aab`) |
| **Default Active Track** | Closed testing (`alpha`) |
| **Automated Publishing** | Configured via GitHub Actions (`release.yml`, `deploy-play-store.yml`) |

---

## 1. Keystore Configuration & Signing

Release builds (`.aab` and `.apk`) require signing with the project's upload key.

### CI/CD Signing (Automated)
The GitHub Actions workflow automates signing using four repository secrets:
- `ANDROID_KEYSTORE_BASE64`: Base64-encoded upload keystore (`.jks`)
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password
- `ANDROID_KEY_ALIAS`: Keystore alias (`shelllite-upload`)
- `ANDROID_KEY_PASSWORD`: Key password

### Local Signing (Optional)
To sign release builds locally:
1. Place the upload keystore file on disk.
2. Create `android/key.properties` (ignored by git):
   ```properties
   storePassword=<KEYSTORE_PASSWORD>
   keyPassword=<KEY_PASSWORD>
   keyAlias=shelllite-upload
   storeFile=/path/to/shelllite-upload-keystore.jks
   ```

---

## 2. Building Artifacts

### Via GitHub Actions (Standard)
Releases are built automatically in CI. Build numbers (`versionCode`) increment monotonically with each workflow run, preventing version collision errors in Google Play Console.

To manually offset build numbers, set the `BUILD_NUMBER_OFFSET` repository variable.

### Local Build Command
```bash
flutter pub get
flutter build appbundle --release
```
The output file is located at `build/app/outputs/bundle/release/app-release.aab`.

---

## 3. Store Listing & Graphical Assets

Store assets are located in [`docs/store_assets/`](file:///home/aron/projects/ShellLite/docs/store_assets/):

| Asset | Dimensions | Format | File |
| :--- | :--- | :--- | :--- |
| **App Icon** | 512 × 512 px | 32-bit PNG | [`docs/store_assets/play_store_icon_512x512.png`](file:///home/aron/projects/ShellLite/docs/store_assets/play_store_icon_512x512.png) |
| **Feature Graphic** | 1024 × 500 px | 24-bit PNG | [`docs/store_assets/feature_graphic_1024x500.png`](file:///home/aron/projects/ShellLite/docs/store_assets/feature_graphic_1024x500.png) |
| **Screenshot 1 (Terminal)** | 1080 × 2410 px | 24-bit PNG | [`docs/store_assets/phone_screenshot_1_terminal.png`](file:///home/aron/projects/ShellLite/docs/store_assets/phone_screenshot_1_terminal.png) |
| **Screenshot 2 (Server List)** | 1080 × 2410 px | 24-bit PNG | [`docs/store_assets/phone_screenshot_2_server_list.png`](file:///home/aron/projects/ShellLite/docs/store_assets/phone_screenshot_2_server_list.png) |
| **Screenshot 3 (Settings & Themes)** | 1080 × 2410 px | 24-bit PNG | [`docs/store_assets/phone_screenshot_3_settings_themes.png`](file:///home/aron/projects/ShellLite/docs/store_assets/phone_screenshot_3_settings_themes.png) |
| **Screenshot 4 (New Server)** | 1080 × 2410 px | 24-bit PNG | [`docs/store_assets/phone_screenshot_4_new_server.png`](file:///home/aron/projects/ShellLite/docs/store_assets/phone_screenshot_4_new_server.png) |

### Store Copy

#### Short Description (Max 80 chars)
> Lightweight, secure SSH client & hardware-accelerated terminal emulator.

#### Full Description (Max 4000 chars)
```markdown
ShellLite is an SSH client and terminal emulator built with Flutter for Android.

KEY FEATURES:

• Pure SSHv2 Client: Interactive PTY terminal sessions powered by DartSSH.
• Terminal Emulation: Full ANSI/VT100 rendering with dynamic resizing, custom cursors, and configurable scrollback buffers.
• Theme Presets: Pre-configured palettes including Obsidian, Catppuccin Mocha, Dracula, Nord, Tokyo Night, and Solarized Dark.
• Key and Authentication Management: Support for password authentication, unencrypted OpenSSH keys (Ed25519, ECDSA, RSA), and an on-device Ed25519 key generator.
• Hardware-Backed Encryption: Server credentials and private keys are encrypted locally using Android KeyStore.
• Keyboard Accessory Bar: Direct access to Tab, Ctrl+C, Ctrl+D, Esc, arrow keys, and custom keys.
• Server Telemetry: Background health monitor tracking CPU load, memory usage, disk utilization, and system uptime.
• Persistent Sessions: tmux session attachment and reconnection support.

PRIVACY AND SECURITY:
ShellLite operates strictly on-device. SSH keys, passwords, and server connections remain local.
• Zero data collection, no analytics SDKs, and no ads.
• Hardware-backed local encryption with Android KeyStore.
• Policy URL: https://strandberg.dev/privacy/shelllite/
```

---

## 4. Policy & Content Declarations

### 1. Privacy Policy
- **URL**: `https://strandberg.dev/privacy/shelllite/`
- **In-App Location**: **Settings > About & Privacy > Privacy Policy**
- **Disclosures**: Zero analytics/telemetry, hardware-backed local credential encryption, direct peer-to-peer SSH traffic without proxy servers.

### 2. App Access
- **Option**: "All or some functionality is restricted"
- **Reviewer Note**: *"ShellLite is an SSH client that connects to user-owned SSH servers. To test, enter any standard SSH server endpoint or use public test SSH services."*

### 3. Ads
- **Declaration**: "No, my app does not contain ads".

### 4. Content Rating (IARC)
- **Category**: Utility / Productivity / Tools.
- **Rating**: Everyone (3+) / PEGI 3.

### 5. Target Audience
- **Target Age**: 18+ (or 13+). Not targeted at children.

### 6. Data Safety
- **Data Collection**: No data collected or shared.
- **Encryption**: Data encrypted in transit (SSHv2/TLS) and at rest (Android KeyStore AES-GCM-256 via `flutter_secure_storage`).
- **Data Deletion**: Deleting server entries purges credentials; uninstalling removes all stored application data.

---

## 5. Google Play Testing Tracks

1. **Internal Testing (`internal`)**:
   - Skips Google review (updates available within minutes).
   - Up to 100 testers per email list.
2. **Closed Testing (`alpha`)**:
   - Current active track for ShellLite testing.
   - Requires Google review.
   - Generates automated Firebase Test Lab pre-launch reports.
3. **Production (`production`)**:
   - Public store release after verification on closed testing.

---

## 6. GitHub Actions Automated Publishing

Automated deployment is configured using the Google Play Developer API and a Google Cloud Service Account.

### Secrets Configuration
- `PLAY_STORE_JSON_KEY`: Full JSON key file of the Google Cloud Service Account invited as Admin/Release Manager to `com.bugmana.shell_lite` in Google Play Console.
- `ANDROID_KEYSTORE_*`: Android release keystore secrets for code signing.

### Workflows

#### 1. Multi-Platform Release (`release.yml`)
Triggers an automated semantic release: calculates next semver tag, builds iOS IPA and Android APK/AAB, publishes GitHub Release, and uploads the `.aab` to Google Play Console:
```bash
gh workflow run release.yml -f bump_type=auto
```
*Defaults to `tracks: alpha` (Closed testing).*

#### 2. On-Demand Play Store Deployment (`deploy-play-store.yml`)
Publishes an existing release artifact directly to Google Play without rebuilding or retagging:
```bash
# Deploy latest release to Closed testing (default)
gh workflow run deploy-play-store.yml -f track=alpha

# Deploy to Internal testing
gh workflow run deploy-play-store.yml -f track=internal

# Deploy to Production
gh workflow run deploy-play-store.yml -f track=production -f status=completed
```

---

## Checklist

- [x] Privacy Policy published to `https://strandberg.dev/privacy/shelllite/` and integrated in-app.
- [x] Upload Keystore generated and configured in GitHub Secrets (`ANDROID_KEYSTORE_*`).
- [x] Android release signing configured in `android/app/build.gradle` and CI workflows.
- [x] Google Play App created (`com.bugmana.shell_lite`).
- [x] Store assets (icon, feature graphic, screenshots) prepared in `docs/store_assets/`.
- [x] Mandatory questionnaires (Data Safety, Content Rating, Ads) configured.
- [x] Initial `.aab` uploaded to Google Play Console to enable API deployment.
- [x] Google Cloud Service Account linked and added to GitHub Secrets (`PLAY_STORE_JSON_KEY`).
- [x] Automated CI/CD deployment verified end-to-end.
- [x] Closed testing (`alpha`) track active.
- [ ] Complete closed testing period with testers.
- [ ] Promote build to Production track.
