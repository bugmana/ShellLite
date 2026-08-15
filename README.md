# ShellLite

> Swift Package that provides an SSH client library (`ShellLiteCore`) and a SwiftUI/UIKit iOS terminal app (`ShellLite`) for connecting to remote servers over SSH using password or public-key authentication.

## Core Tech Stack

* **Language/Runtime:** Swift 6.0 (strict concurrency)
* **Key Frameworks/Libraries:** SwiftNIO SSH 0.15.0 (`NIOSSH`), Swift Crypto 4.5.1 (`Crypto`), SwiftUI, UIKit
* **Storage/Infrastructure:** Apple Keychain (`Security.framework`) for credential storage; `UserDefaults` for server profile persistence; in-memory stub for Linux/test environments

## Architecture & Directory Layout

```text
ShellLite/
├── Package.swift                  # SPM manifest; defines two library products + one test target
├── Package.resolved               # Pinned dependency versions
├── Sources/
│   ├── ShellLiteCore/             # Platform-portable library (Linux-buildable)
│   │   ├── Models/
│   │   │   └── ServerProfile.swift        # Codable SSH connection profile (host, port, user, auth)
│   │   └── Services/
│   │       ├── SSHManager.swift           # SSHSession actor, OpenSSH key parser, auth delegates
│   │       └── KeychainManager.swift      # Security.framework wrapper; in-memory stub on Linux
│   └── ShellLite/                 # iOS/macOS UI layer (requires SwiftUI + UIKit)
│       ├── ShellLite.swift                # @main App entry point; ServerStore (@Observable)
│       └── Views/
│           ├── ServerListView.swift       # Root list of saved server profiles
│           ├── ServerFormView.swift       # Add/edit server profile form
│           ├── TerminalViewWrapper.swift  # UIViewControllerRepresentable bridge + TerminalViewController
│           └── KeyboardAccessoryBar.swift # Custom keyboard toolbar (tab, arrow keys, history)
└── Tests/
    └── ShellLiteTests/
        └── ShellLiteTests.swift           # Unit tests targeting ShellLiteCore
```

## Module Boundaries

| Module | Platforms | Exports |
|---|---|---|
| `ShellLiteCore` | iOS 18+, macOS 15+, Linux | `SSHSession`, `KeychainManager`, `ServerProfile`, `parseOpenSSHPrivateKey` |
| `ShellLite` | iOS 18+, macOS 15+ | `ShellLiteApp`, `ServerStore`, all SwiftUI/UIKit views |

## Key Data Flows

1. **Profile lifecycle** — `ServerStore` (`@Observable`) serialises `[ServerProfile]` as JSON to `UserDefaults`; credentials (passwords, PEM keys) are stored separately in the Keychain under a per-profile tag.
2. **SSH connection** — `TerminalViewController` creates an `SSHSession` actor, calls `connect(host:port:auth:)`, then calls `execute(_:)` per command, receiving output via `AsyncThrowingStream<String, Error>`.
3. **Key auth** — `parseOpenSSHPrivateKey(_:)` decodes unencrypted OpenSSH PEM format and returns an `NIOSSHPrivateKey` supporting Ed25519, ECDSA P-256/384/521.

## Build & Test

```bash
# Build all targets
swift build

# Run unit tests (Linux-compatible; uses in-memory Keychain stub)
swift test
```

## Platform Requirements

* iOS 18+ / macOS 15+ for the `ShellLite` UI target
* Swift 6.0 toolchain
* Encrypted SSH private keys are not supported; passphrase-protected keys throw `SSHKeyError.encryptedKey`
