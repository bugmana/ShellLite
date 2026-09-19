# Security Audit Handover

This document outlines the scope, methodology, and agent team composition for performing a security audit of ShellLite. The assessment covers source code vulnerability analysis, cryptographic verification, credential storage security, network transport validation, and secret leakage detection across the iOS, Android, and Web implementations.

---

## Objectives

1. Identify vulnerabilities, insecure defaults, and command injection risks in the application source code.
2. Verify cryptographic safety in key generation, parsing, and memory handling.
3. Validate hardware-backed local credential encryption on mobile and assess browser storage security on Web.
4. Audit network socket handling, WebSocket bridging, and host validation.
5. Scan repository history, build scripts, and CI/CD pipelines for secret leakage.

---

## Security Team Composition

The team is structured into specialized analyst roles. Each agent operates with targeted scope and defined verification responsibilities.

```text
+-------------------------------------------------------------------------+
|                       Security Lead Coordinator                         |
|           (Triage, CVSS Scoring, Report Synthesis & Prioritization)     |
+-------------------------------------------------------------------------+
       |                  |                    |                    |
+--------------+  +---------------+  +--------------------+  +------------+
| Cryptography |  | Data Storage  |  | Network Transport  |  | Injection  |
| & Keys       |  | & Secrets     |  | & Protocol         |  | & Sanitize |
+--------------+  +---------------+  +--------------------+  +------------+
```

### 1. Cryptography and Key Management Analyst
- **Scope**:
  - [`SSHKeyGeneratorService`](file:///home/aron/projects/ShellLite/lib/services/key_generator_service.dart): Audit PineNaCl Ed25519 key pair generation, entropy generation using `Random.secure()`, OpenSSH wire format serialization, and SHA256 fingerprint calculations.
  - [`SSHKeyParser`](file:///home/aron/projects/ShellLite/lib/services/key_parser.dart): Audit OpenSSH and PEM private key parsing, encryption detection (`isEncrypted`), passphrase decryption flows, and exception handling.
- **Verification Deliverables**:
  - Verification that private key bytes are not leaked through logging or error strings.
  - Assessment of memory clearing and key lifecycle management in memory.
  - Verification of PKCS#8, OpenSSH v1, and PEM format parsing boundaries.

### 2. Credential Storage and Data-at-Rest Analyst
- **Scope**:
  - [`StorageService`](file:///home/aron/projects/ShellLite/lib/services/storage_service.dart): Review [`FlutterSecureStorage`](file:///home/aron/projects/ShellLite/lib/services/storage_service.dart#L14) configuration for iOS Keychain (`first_unlock_this_device`) and Android KeyStore (`AES_GCM_NoPadding` with RSA-OAEP wrapping).
  - Web credential handling: Assess risks of base64 storage in `SharedPreferences` on Web environments and propose mitigations.
  - Credential lifecycle: Audit profile deletion flows in [`ServerStore.deleteProfile`](file:///home/aron/projects/ShellLite/lib/providers/server_store.dart#L86) to verify that private keys and passwords are permanently purged.
- **Verification Deliverables**:
  - Verification of hardware-backed encryption enforcement on iOS and Android.
  - Identification of credential residue in memory caches (`_inMemoryCredentials`).
  - Threat assessment of browser-based credential storage.

### 3. Network Transport and Protocol Analyst
- **Scope**:
  - [`SSHSocketFactory`](file:///home/aron/projects/ShellLite/lib/services/ssh_socket_factory.dart): Audit socket connection logic across native direct TCP and Web WebSocket bridge.
  - [`WebSocketSSHSocket`](file:///home/aron/projects/ShellLite/lib/services/web_ssh_socket.dart): Verify WebSocket frame encoding, error propagation, and stream closure hygiene.
  - [`SSHService`](file:///home/aron/projects/ShellLite/lib/services/ssh_service.dart): Review connection timeouts, keep-alive intervals, and session authentication flows.
  - [`TelemetryService`](file:///home/aron/projects/ShellLite/lib/services/telemetry_service.dart): Validate isolated background SSH connections and connection pooling.
- **Verification Deliverables**:
  - Verification of TLS enforcement (`wss://`) for Web connections.
  - Assessment of host key verification policies in `dartssh2` client initialization.
  - Denial of Service resilience regarding stream fragmentation and packet buffering.

### 4. Input Sanitization and Command Execution Analyst
- **Scope**:
  - [`FileTransferService`](file:///home/aron/projects/ShellLite/lib/services/file_transfer_service.dart#L207): Review remote directory resolution (`resolveCurrentDirectory`) and command construction for file uploads via standard input execution (`cat > '$escapedPath'`).
  - [`SSHService`](file:///home/aron/projects/ShellLite/lib/services/ssh_service.dart#L162): Audit tmux session name sanitization (`_tmuxSanitizeRegex`) and startup command execution.
  - [`TelemetryService`](file:///home/aron/projects/ShellLite/lib/services/telemetry_service.dart#L71): Audit system telemetry command execution strings.
  - [`ServerFormScreen`](file:///home/aron/projects/ShellLite/lib/screens/server_form_screen.dart#L262): Audit regular expression for clipboard SSH command parsing.
- **Verification Deliverables**:
  - Identification of path traversal vulnerabilities during file uploads.
  - Verification of shell escaping against command injection through crafted filenames or tmux session names.
  - Analysis of clipboard regex parsing against ReDoS (Regular Expression Denial of Service).

### 5. Repository and CI/CD Security Auditor
- **Scope**:
  - Scan entire repository history for committed credentials, test keys, certificates, or tokens.
  - [`.github/workflows/`](file:///home/aron/projects/ShellLite/.github/workflows): Audit GitHub Actions workflows (`build-android.yml`, `build-ios.yml`, `release.yml`, `ci.yml`) for untrusted input injection, secret exposure, and dependency pinning.
  - Dependency verification: Review third-party dependencies in [`pubspec.yaml`](file:///home/aron/projects/ShellLite/pubspec.yaml) for known CVEs or unmaintained packages.
- **Verification Deliverables**:
  - Secret scanning report across git history and untracked files.
  - GitHub Actions supply chain and permissions security audit.
  - Software Bill of Materials (SBOM) dependency vulnerability audit.

### 6. Security Lead Coordinator
- **Responsibilities**:
  - Coordinate task allocation and status updates across analyst subagents.
  - Validate and reproduce reported findings to filter false positives.
  - Score verified findings using CVSS v3.1 and classify under OWASP Mobile Top 10.
  - Compile final remediation report with patch recommendations.

---

## Execution Methodology

1. **Static Analysis & Code Inspection**:
   - Deep inspection of source files in `lib/services/`, `lib/models/`, `lib/providers/`, and `lib/screens/`.
   - Run static analysis:
     ```bash
     flutter analyze --fatal-infos
     ```
2. **Secret & History Scanning**:
   - Scan git tree and commit log for sensitive tokens, unencrypted private keys, and keystore passwords.
3. **Architecture Threat Modeling**:
   - Map trust boundaries between client device, local storage, network transport, reverse proxy, and target SSH server.
4. **Report Compilation**:
   - Synthesize findings into structured findings tables: Finding ID, Severity, Affected Component, Description, Impact, and Remediation.

---

## Agent Invocation Reference

To launch this team in the Antigravity environment, use the `/teamwork-preview` command to initialize the subagent workspace and spawn the team members based on the roles defined above.
