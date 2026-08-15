import Foundation

// MARK: - Auth Method

/// How ShellLite authenticates with an SSH server.
public enum AuthMethod: Codable, Hashable, Sendable {
    /// Password stored in the Keychain under `credentialTag`.
    case password(credentialTag: String)
    /// OpenSSH private key (Ed25519 / RSA) stored in the Keychain under `privateKeyTag`.
    case sshKey(privateKeyTag: String)
}

// MARK: - Server Profile

/// Represents a saved SSH server connection profile.
public struct ServerProfile: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var displayName: String
    public var host: String
    public var port: UInt16
    public var username: String
    /// How to authenticate — `.password` or `.sshKey`.
    public var authMethod: AuthMethod
    /// Optional command to execute immediately after the session connects.
    /// When `nil` (or empty), the terminal just shows the interactive prompt.
    public var initialCommand: String?

    public init(
        id: UUID = UUID(),
        displayName: String,
        host: String,
        port: UInt16 = 22,
        username: String,
        authMethod: AuthMethod,
        initialCommand: String? = nil
    ) {
        self.id             = id
        self.displayName    = displayName
        self.host           = host
        self.port           = port
        self.username       = username
        self.authMethod     = authMethod
        self.initialCommand = initialCommand
    }
}
