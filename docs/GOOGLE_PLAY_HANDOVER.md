# 🚀 ShellLite: Google Play Store Handover & Publishing Guide

This document contains the complete end-to-end instructions, configurations, metadata, and checklists required to publish **ShellLite** to the Google Play Store using your Google Play Developer Account.

---

## 📋 Quick Reference

| Field | Value |
| :--- | :--- |
| **App Name** | `ShellLite` (or `ShellLite - SSH & Terminal`) |
| **Package Name / Application ID** | `com.bugmana.shell_lite` |
| **Current Target SDK** | `35` (Android 15) |
| **Minimum SDK** | `23` (Android 6.0+) |
| **App Category** | Tools / Productivity |
| **Content Rating** | Everyone (General Utility) |
| **Primary Artifact** | Android App Bundle (`.aab`) |
| **Default Build Output** | `build/app/outputs/bundle/release/app-release.aab` |

---

## 🔑 1. Release Keystore Generation & Configuration

Google Play requires all upload bundles (`.aab`) to be signed with a secure upload key.

### A. Generate Upload Keystore
Run the following command on your local development machine to create your release keystore:

```bash
keytool -genkey -v -keystore ~/shelllite-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias shelllite-upload
```

> [!CAUTION]
> **Backup your keystore file safely!** If you lose your keystore and password, you will need to contact Google Play Developer Support to reset your upload key. Never commit `.jks` or `key.properties` to version control.

### B. Configure `android/key.properties`
Create the file `android/key.properties` (this file is already ignored in `.gitignore`):

```properties
storePassword=<YOUR_KEYSTORE_PASSWORD>
keyPassword=<YOUR_KEY_PASSWORD>
keyAlias=shelllite-upload
storeFile=/absolute/path/to/shelllite-upload-keystore.jks
```

*(You can also use a relative path such as `../shelllite-upload-keystore.jks` if placed in the project root).*

---

## 📦 2. Building the Production Bundle (`.aab`)

### Local Build Command
Run the standard Flutter release command:

```bash
cd /home/aron/projects/ShellLite
flutter clean
flutter pub get
flutter build appbundle --release
```

The output file will be generated at:
```
build/app/outputs/bundle/release/app-release.aab
```

### Version Bumping for New Releases
Before building subsequent updates for Google Play, bump `version` in `pubspec.yaml`:
```yaml
# Format: versionName+versionCode
# versionName is user-facing (e.g. 1.0.2)
# versionCode must be an incrementing integer for every Play Store upload (e.g. 3, 4, 5...)
version: 1.0.2+3
```

---

## 🎨 3. Store Listing & Graphical Assets

When creating your store listing in Google Play Console, you will need the following assets:

### Required Graphics Specifications

| Asset | Dimensions | Format | Generated File in Repository | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **App Icon** | 512 × 512 px | 32-bit PNG (with alpha) | [`docs/store_assets/play_store_icon_512x512.png`](file:///home/aron/projects/ShellLite/docs/store_assets/play_store_icon_512x512.png) | Master corgi logo, ready to upload. |
| **Feature Graphic** | 1024 × 500 px | 24-bit PNG (no alpha) | [`docs/store_assets/feature_graphic_1024x500.png`](file:///home/aron/projects/ShellLite/docs/store_assets/feature_graphic_1024x500.png) | Obsidian terminal branding with glowing logo. |
| **Phone Screenshot 1** | 1080 × 1920 px | 24-bit PNG (9:16) | [`docs/store_assets/phone_screenshot_1_terminal.png`](file:///home/aron/projects/ShellLite/docs/store_assets/phone_screenshot_1_terminal.png) | Interactive terminal session with `htop` & `neofetch`. |
| **Phone Screenshot 2** | 1080 × 1920 px | 24-bit PNG (9:16) | [`docs/store_assets/phone_screenshot_2_servers.png`](file:///home/aron/projects/ShellLite/docs/store_assets/phone_screenshot_2_servers.png) | Server list & real-time telemetry metrics. |
| **Phone Screenshot 3** | 1080 × 1920 px | 24-bit PNG (9:16) | [`docs/store_assets/phone_screenshot_3_themes_privacy.png`](file:///home/aron/projects/ShellLite/docs/store_assets/phone_screenshot_3_themes_privacy.png) | Theme presets, monospace CLI preview, & Privacy Policy. |

### Store Copy

#### Short Description (Max 80 characters)
> Lightweight, secure SSH client & hardware-accelerated terminal emulator.

#### Full Description (Max 4000 characters)
```markdown
ShellLite is a modern, fast, and secure SSH client and terminal emulator built with Flutter for developers, sysadmins, and DevOps engineers on the go.

✨ KEY FEATURES:

• Pure SSHv2 Client: Fast interactive PTY terminal sessions powered by DartSSH.
• Hardware-Accelerated Terminal: Full ANSI/VT100 rendering with dynamic resizing, custom cursors, and smooth scrollback buffers.
• Multiple Theme Presets: Choose from developer favorites including Obsidian, Catppuccin Mocha, Dracula, Nord, Tokyo Night, and Solarized Dark.
• Robust Key & Auth Management: Support for password auth, unencrypted OpenSSH keys (Ed25519, ECDSA, RSA), and a built-in on-device Ed25519 key generator.
• Hardware-Backed Encryption: Server credentials and private keys are encrypted locally using Android KeyStore.
• Directional Navigation HUD: Touchscreen virtual joystick for effortless cursor positioning and command navigation.
• Customizable Quick Keyboard Bar: Rapid access to Tab, Ctrl+C, Ctrl+D, Esc, arrow keys, and custom macro keys.
• Live Server Telemetry: Background health monitor tracking CPU load, memory usage, disk utilization, and system uptime.
• Persistent Sessions: Seamless tmux session attach and reconnection resilience.

🔒 PRIVACY & SECURITY FIRST:
ShellLite operates strictly on-device. Your SSH keys, passwords, and server connections never touch third-party servers.
• Zero data collection, no analytics SDKs, and no ads.
• Hardware-backed local encryption with Android KeyStore.
• Complete transparency with in-app policy and canonical web policy: https://strandberg.dev/privacy/shelllite/
```

---

## 📝 4. Google Play Console Policy & Content Declarations

Google Play requires completion of several policy questionnaires before publishing:

### 1. Privacy Policy
* **Requirement**: Publicly accessible HTTPS URL.
* **Canonical URL (Enter in Google Play Console)**: `https://strandberg.dev/privacy/shelllite/`
  *(Note: `https://strandberg.dev/privacy/` and `https://shell.strandberg.dev/privacy.html` also redirect to this canonical policy).*
* **In-App Location**: Directly viewable in the app under **Settings > ABOUT & PRIVACY > Privacy Policy** (accessible completely offline).
* **Hosted Repository**: Maintained in git repository [`bugmana/strandberg.dev`](https://github.com/bugmana/strandberg.dev) at `privacy/shelllite/index.md` and deployed via GitHub Pages CDN for 100% availability.
* **Key Commitments & Disclosures**:
  - **Zero Telemetry / Analytics**: No Firebase, Google Analytics, telemetry beacons, or ad tracking frameworks.
  - **Hardware-Backed Encryption**: Credentials (passwords, private keys, passphrases) stored locally via `flutter_secure_storage` using Android KeyStore (AES-GCM-256).
  - **Direct Connections**: Direct peer-to-peer TCP/SSH traffic to user hosts without any relay or proxy interception.
  - **Local Key Generation**: Ed25519 keys generated locally on-device with PineNaCl; private keys never leave the hardware.
  - **Transient Telemetry**: System metrics (CPU, RAM, Disk, Uptime) stay in ephemeral volatile memory and are never persisted or uploaded.
  - **User Data Deletion**: Deleting a server profile purges all stored credentials; uninstalling purges all data.
  - **Publisher Contact**: Aron Strandberg (`aron@strandberg.dev`).

### 2. App Access (Login Credentials for Reviewers)
* **Select**: "All or some functionality is restricted" OR provide demo instructions.
* **Note for Reviewer**: *"ShellLite is an SSH client utility that connects to user-owned SSH servers. To test, enter any standard SSH server endpoint or use public test SSH services."*

### 3. Ads
* **Declaration**: Select **"No, my app does not contain ads"**.

### 4. Content Rating (IARC)
* **Category**: Utility / Productivity / Tools.
* **Answers**:
  - Violence / Sexual content / Profanity: No
  - User interaction: Connects to arbitrary servers (Utility)
  - Location sharing: No
* **Result**: Rating will be **Everyone (3+) / PEGI 3**.

### 5. Target Audience & Content
* **Target Age**: 18+ (or 13+).
* **Appeal to children**: Select **"No"**.

### 6. Data Safety Declaration
Google Play Console requires answering specific Data Safety questions. Use these exact answers:

| Section | Question | Answer & Explanatory Details |
| :--- | :--- | :--- |
| **Data Collection** | Does your app collect or share user data? | **No** (all credentials, keys, logs, and telemetry stay strictly local on-device). |
| **Data Sharing** | Is any user data shared with third parties? | **No** (zero third-party SDKs, analytics, ads, or crash report beacons). |
| **Data in Transit** | Is all user data encrypted in transit? | **Yes** (encrypted over standard SSHv2 / TLS WebSocket bridge directly to user servers). |
| **Data at Rest** | Is data stored securely on the device? | **Yes** (hardware-backed Android KeyStore AES-GCM-256 encryption via `flutter_secure_storage`). |
| **Data Deletion** | Can users delete their data? | **Yes** (deleting a server entry purges stored credentials immediately; uninstalling purges all local storage). |
| **Privacy Policy URL**| Valid privacy policy URL | `https://strandberg.dev/privacy/shelllite/` |

---

## 🧪 5. Testing Tracks & Google Play Account Verification

If your Google Play Developer Account is a **Personal Account** created after November 2023, Google enforces a mandatory testing phase before production release:

1. **Internal Testing Track**:
   - Create an Internal Test track in Google Play Console.
   - Add your own email addresses.
   - Upload `app-release.aab`.
   - You can install and verify updates immediately without waiting for review.

2. **Closed Testing Track (20 Testers Requirement)**:
   - Create a Closed Testing track.
   - Invite at least **20 testers** (opt-in via Google Group or email list).
   - Testers must remain opted-in for **14 consecutive days**.
   - After 14 days, you can apply for Production access directly within the Play Console dashboard.

3. **Production Track**:
   - Promote your tested build from Closed Testing to Production.
   - Rollout percentage: 100% (or staged rollout).

---

## 🤖 6. CI/CD GitHub Actions Automated Publishing (Optional)

To enable GitHub Actions to automatically sign `.aab` files:

1. Base64 encode your keystore:
   ```bash
   base64 -w 0 ~/shelllite-upload-keystore.jks > keystore_base64.txt
   ```
2. In your GitHub repository settings (**Settings > Secrets and variables > Actions**), add:
   - `ANDROID_KEYSTORE_BASE64`: (content of `keystore_base64.txt`)
   - `ANDROID_KEYSTORE_PASSWORD`: Keystore password
   - `ANDROID_KEY_ALIAS`: Keystore alias (`shelllite-upload`)
   - `ANDROID_KEY_PASSWORD`: Key password

---

## 📞 Support & Maintenance Checklist

- [x] Privacy Policy published to `https://strandberg.dev/privacy/shelllite/` and integrated in-app under Settings.
- [ ] Keystore generated & backed up offsite.
- [ ] `android/key.properties` configured locally.
- [ ] `flutter build appbundle --release` compiles without errors.
- [x] App Icon (512x512) and Feature Graphic (1024x500) generated in `docs/store_assets/`.
- [x] High-resolution phone screenshots (1080x1920) generated in `docs/store_assets/`.
- [ ] Google Play App created (`com.bugmana.shell_lite`).
- [ ] Store graphics and screenshots uploaded to Google Play Console.
- [ ] Store descriptions and Privacy Policy URL (`https://strandberg.dev/privacy/shelllite/`) entered in Play Console.
- [ ] Mandatory questionnaires (Data Safety, Content Rating, Ads) completed using Section 4 declarations.
- [ ] Upload `.aab` to Internal Testing track for first verification.
