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

| Asset | Dimensions | Format | Notes |
| :--- | :--- | :--- | :--- |
| **App Icon** | 512 × 512 px | 32-bit PNG (with alpha) | Max 1 MB. Clean app logo. |
| **Feature Graphic** | 1024 × 500 px | JPEG or 24-bit PNG (no alpha) | Max 15 MB. Highlight brand/terminal interface. |
| **Phone Screenshots** | Min 2, max 8 | JPEG or 24-bit PNG | Min 320px, max 3840px (16:9 or 9:16 aspect recommended). |
| **7" & 10" Tablet Screenshots** | Optional but recommended | JPEG or 24-bit PNG | Shows responsive layout on tablets/foldables. |

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
• Biometric & Hardware Encryption: Server credentials and private keys are encrypted locally using Android KeyStore and protected with Biometric Authentication.
• Directional Navigation HUD: Touchscreen virtual joystick for effortless cursor positioning and command navigation.
• Customizable Quick Keyboard Bar: Rapid access to Tab, Ctrl+C, Ctrl+D, Esc, arrow keys, and custom macro keys.
• Live Server Telemetry: Background health monitor tracking CPU load, memory usage, disk utilization, and system uptime.
• Persistent Sessions: Seamless tmux session attach and reconnection resilience.

🔒 PRIVACY & SECURITY FIRST:
ShellLite operates strictly on-device. Your SSH keys, passwords, and server connections never touch third-party servers.
```

---

## 📝 4. Google Play Console Policy & Content Declarations

Google Play requires completion of several policy questionnaires before publishing:

### 1. Privacy Policy
* **Requirement**: Publicly accessible URL.
* **Recommended URL**: `https://strandberg.dev/privacy` (or a dedicated privacy section on `shell.strandberg.dev`).
* **Key Points**:
  - The app connects directly to SSH servers specified by the user.
  - No user analytics, telemetry, or personal identity data is collected or sold.
  - Credentials and private keys are stored locally using encrypted Android KeyStore.

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
| Section | Question | Answer |
| :--- | :--- | :--- |
| **Data Collection** | Does your app collect or share user data? | **No** (all credentials stay local on-device). |
| **Security Practices** | Is data encrypted in transit? | **Yes** (SSH encrypted communication). |
| **Data Deletion** | Can users delete their data? | **Yes** (deleting a server entry or uninstalling deletes all local secure storage). |

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

- [ ] Keystore generated & backed up offsite.
- [ ] `android/key.properties` configured locally.
- [ ] `flutter build appbundle --release` compiles without errors.
- [ ] Google Play App created (`com.bugmana.shell_lite`).
- [ ] App Icon (512x512) and Feature Graphic (1024x500) uploaded.
- [ ] Store descriptions and Privacy Policy linked.
- [ ] Mandatory questionnaires (Data Safety, Content Rating, Ads) completed.
- [ ] Upload `.aab` to Internal Testing track for first verification.
