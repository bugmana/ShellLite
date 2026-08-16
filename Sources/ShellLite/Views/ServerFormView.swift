#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import ShellLiteCore

// MARK: - Auth Method Picker State

private enum AuthChoice: String, CaseIterable, Identifiable {
    case password = "Password"
    case sshKey   = "SSH Key"
    var id: String { rawValue }
}

// MARK: - ServerFormView

/// Sheet presented by `ServerListView` for adding a new server profile.
public struct ServerFormView: View {

    // MARK: Dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(ServerStore.self) private var store

    // MARK: Form State
    @State private var displayName = ""
    @State private var host        = ""
    @State private var portText    = "22"
    @State private var username    = ""
    @State private var authChoice  = AuthChoice.password

    // Password auth
    @State private var password    = ""

    // SSH key auth
    @State private var sshKeyPEM   = ""
    @State private var keyError: String? = nil

    // Initial command (optional)
    @State private var initialCommand = ""

    // MARK: Validation

    private var port: UInt16? { UInt16(portText) }

    private var isValid: Bool {
        guard !displayName.isEmpty, !host.isEmpty, !username.isEmpty, port != nil else { return false }
        switch authChoice {
        case .password: return !password.isEmpty
        case .sshKey:   return !sshKeyPEM.isEmpty
        }
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                // ── Connection ──────────────────────────
                Section("Connection") {
                    TextField("Display Name", text: $displayName)
                        .autocorrectionDisabled()
                    TextField("Host / IP Address", text: $host)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Port", text: $portText)
                        .keyboardType(.numberPad)
                    TextField("Username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                // ── Auth Method ──────────────────────────
                Section {
                    Picker("Method", selection: $authChoice) {
                        ForEach(AuthChoice.allCases) { choice in
                            Text(choice.rawValue).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

                    if authChoice == .password {
                        SecureField("Password", text: $password)
                    } else {
                        // SSH Key paste area
                        VStack(alignment: .leading, spacing: 6) {
                            TextEditor(text: $sshKeyPEM)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 120, maxHeight: 200)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: sshKeyPEM) { _, _ in keyError = nil }

                            Text("Paste an unencrypted OpenSSH private key (Ed25519, ECDSA P-256/384/521).\nMust begin with:\n-----BEGIN OPENSSH PRIVATE KEY-----")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let err = keyError {
                                Label(err, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    if authChoice == .password {
                        Text("Password stored in the iOS Keychain with kSecAttrAccessibleAfterFirstUnlock.")
                    } else {
                        Text("Private key stored securely in the iOS Keychain. Only Ed25519 unencrypted keys are currently supported.")
                    }
                }

                // ── Startup (optional) ───────────────────────────────────────
                Section {
                    TextField(
                        "Initial command (optional)",
                        text: $initialCommand,
                        axis: .vertical
                    )
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .lineLimit(1...4)
                } header: {
                    Text("Startup")
                } footer: {
                    Text("Runs automatically when the session opens. Leave blank for an interactive prompt.")
                }
            }
            .navigationTitle("Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { attemptSave() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Save

    private func attemptSave() {
        guard let port else { return }
        let credentialTag = UUID().uuidString

        switch authChoice {
        case .password:
            do {
                try KeychainManager.shared.save(password: password, for: credentialTag)
            } catch {
                return  // in production show an alert
            }
            let profile = ServerProfile(
                displayName: displayName,
                host: host,
                port: port,
                username: username,
                authMethod: .password(credentialTag: credentialTag),
                initialCommand: initialCommand.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
            store.add(profile)
            dismiss()

        case .sshKey:
            do {
                _ = try parseOpenSSHPrivateKey(sshKeyPEM)
            } catch {
                keyError = keyErrorMessage(error)
                return
            }
            do {
                try KeychainManager.shared.save(password: sshKeyPEM, for: credentialTag)
            } catch {
                keyError = "Failed to save key to Keychain."
                return
            }
            let profile = ServerProfile(
                displayName: displayName,
                host: host,
                port: port,
                username: username,
                authMethod: .sshKey(privateKeyTag: credentialTag),
                initialCommand: initialCommand.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
            store.add(profile)
            dismiss()
        }
    }

    private func keyErrorMessage(_ error: Error) -> String {
        switch error {
        case SSHKeyError.encryptedKey:
            return "Passphrase-protected keys are not yet supported. Remove the passphrase with: ssh-keygen -p -f <key>"
        case SSHKeyError.unsupportedKeyType(let t):
            return "Unsupported key type '\(t)'. Supported types: Ed25519, ECDSA P-256/384/521."
        case SSHKeyError.invalidECKey:
            return "The ECDSA private key bytes are invalid or corrupted."
        case SSHKeyError.invalidBase64, SSHKeyError.invalidMagic:
            return "Invalid key format. Make sure to paste the full key including the -----BEGIN----- header."
        default:
            return "Could not parse key: \(error)"
        }
    }
}

// MARK: - Helpers

private extension String {
    /// Returns `nil` if the string is empty, otherwise returns `self`.
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
#endif
