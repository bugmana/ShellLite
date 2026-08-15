import Foundation
import Crypto
@preconcurrency import NIOSSH
import NIOCore
import NIOPosix

// MARK: - Auth

/// How to authenticate with the SSH server.
public enum SSHAuth: Sendable {
    case password(username: String, password: String)
    case sshKey(username: String, privateKey: NIOSSHPrivateKey)
}

// MARK: - Session Actor

/// Thread-safe SSH session actor backed by SwiftNIO-SSH 0.15.0.
public actor SSHSession {

    private var channel: Channel?
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    /// The SSH exec child channel currently running a command (nil between commands).
    private var activeChildChannel: Channel?

    public init() {}

    /// Opens an SSH connection to `host:port` using `auth`.
    public func connect(host: String, port: UInt16, auth: SSHAuth) async throws {
        let authDelegate: any NIOSSHClientUserAuthenticationDelegate & Sendable
        switch auth {
        case .password(let username, let password):
            authDelegate = PasswordAuthDelegate(username: username, password: password)
        case .sshKey(let username, let privateKey):
            authDelegate = KeyAuthDelegate(username: username, privateKey: privateKey)
        }

        let serverAuthDelegate = AcceptAllHostKeysDelegate()
        let bootstrap = ClientBootstrap(group: group)
        let channel = try await bootstrap
            .channelInitializer { channel in
                let config = SSHClientConfiguration(
                    userAuthDelegate: authDelegate,
                    serverAuthDelegate: serverAuthDelegate
                )
                return channel.pipeline.addHandlers([
                    NIOSSHHandler(
                        role: .client(config),
                        allocator: channel.allocator,
                        inboundChildChannelInitializer: nil
                    )
                ])
            }
            .connect(host: host, port: Int(port))
            .get()
        self.channel = channel
    }

    /// Executes a shell command and returns an `AsyncThrowingStream` of output lines.
    public func execute(_ command: String) async throws -> AsyncThrowingStream<String, Error> {
        guard let channel else { throw SSHError.notConnected }

        // Capture the actor reference so NIO callbacks (off-actor) can hop back.
        let actorRef = self

        return AsyncThrowingStream { continuation in
            channel.eventLoop.execute {
                channel.pipeline.handler(type: NIOSSHHandler.self).flatMap { sshHandler in
                    let promise = channel.eventLoop.makePromise(of: Channel.self)
                    sshHandler.createChannel(promise) { childChannel, _ -> EventLoopFuture<Void> in
                        childChannel.pipeline.addHandlers([
                            CommandHandler(
                                command: command,
                                continuation: continuation,
                                onFinish: { Task { await actorRef.clearActiveChildChannel() } }
                            )
                        ])
                    }
                    return promise.futureResult.map { ch in
                        Task { await actorRef.setActiveChildChannel(ch) }
                    }
                }.whenFailure { error in
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Closes the SSH session gracefully.
    public func disconnect() async {
        try? await channel?.close()
        channel = nil
    }

    deinit {
        try? group.syncShutdownGracefully()
    }

    /// Sends raw bytes to the currently-running command's stdin.
    /// Silently no-ops when no command channel is active.
    public func sendInput(_ bytes: Data) {
        guard let ch = activeChildChannel else { return }
        var buf = ch.allocator.buffer(capacity: bytes.count)
        buf.writeBytes(bytes)
        let data = SSHChannelData(type: .channel, data: .byteBuffer(buf))
        ch.writeAndFlush(data, promise: nil)
    }

    private func setActiveChildChannel(_ ch: Channel) { activeChildChannel = ch }
    private func clearActiveChildChannel()             { activeChildChannel = nil }
}

// MARK: - Auth Delegates

private final class PasswordAuthDelegate: NIOSSHClientUserAuthenticationDelegate, @unchecked Sendable {
    private let username: String
    private let password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        nextChallengePromise.succeed(
            .init(
                username: username,
                serviceName: "ssh-connection",
                offer: .password(.init(password: password))
            )
        )
    }
}

private final class KeyAuthDelegate: NIOSSHClientUserAuthenticationDelegate, @unchecked Sendable {
    private let username: String
    private let privateKey: NIOSSHPrivateKey

    init(username: String, privateKey: NIOSSHPrivateKey) {
        self.username = username
        self.privateKey = privateKey
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        nextChallengePromise.succeed(
            .init(
                username: username,
                serviceName: "ssh-connection",
                offer: .privateKey(.init(privateKey: privateKey))
            )
        )
    }
}

private final class AcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    func validateHostKey(
        hostKey: NIOSSHPublicKey,
        validationCompletePromise: EventLoopPromise<Void>
    ) {
        // ⚠️ Replace with fingerprint pinning before production use.
        validationCompletePromise.succeed()
    }
}

// MARK: - Channel Handler

private final class CommandHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn  = SSHChannelData
    typealias OutboundOut = SSHChannelData

    private let command: String
    private let continuation: AsyncThrowingStream<String, Error>.Continuation
    /// Called when the channel closes (success or error) so the session can clear
    /// its `activeChildChannel` reference.
    private let onFinish: (() -> Void)?

    init(
        command: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation,
        onFinish: (() -> Void)? = nil
    ) {
        self.command = command
        self.continuation = continuation
        self.onFinish = onFinish
    }

    func channelActive(context: ChannelHandlerContext) {
        context.triggerUserOutboundEvent(
            SSHChannelRequestEvent.ExecRequest(command: command, wantReply: true),
            promise: nil
        )
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)
        if case .byteBuffer(let buffer) = channelData.data,
           let string = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) {
            string.split(separator: "\n", omittingEmptySubsequences: false)
                .forEach { continuation.yield(String($0)) }
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        continuation.finish()
        onFinish?()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        continuation.finish(throwing: error)
        onFinish?()
    }
}

// MARK: - OpenSSH Private Key Parser

/// Parses an **unencrypted** OpenSSH private key in PEM format.
///
/// Supported key types:
/// - `ssh-ed25519` — generated with `ssh-keygen -t ed25519`
/// - `ecdsa-sha2-nistp256` — generated with `ssh-keygen -t ecdsa -b 256`
/// - `ecdsa-sha2-nistp384` — generated with `ssh-keygen -t ecdsa -b 384`
/// - `ecdsa-sha2-nistp521` — generated with `ssh-keygen -t ecdsa -b 521`
///
/// - Parameter pem: Full PEM string including `-----BEGIN OPENSSH PRIVATE KEY-----` headers.
/// - Returns: A `NIOSSHPrivateKey` ready for use in `SSHAuth.sshKey`.
/// - Throws: `SSHKeyError` if the key is malformed, encrypted, or an unsupported type.
public func parseOpenSSHPrivateKey(_ pem: String) throws -> NIOSSHPrivateKey {
    // Strip PEM headers and decode base64.
    let base64 = pem
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
        .joined()

    guard let data = Data(base64Encoded: base64) else {
        throw SSHKeyError.invalidBase64
    }

    return try parseOpenSSHBinary(data)
}

/// Backward-compatible alias for `parseOpenSSHPrivateKey`.
@available(*, deprecated, renamed: "parseOpenSSHPrivateKey")
public func parseOpenSSHEd25519Key(_ pem: String) throws -> NIOSSHPrivateKey {
    try parseOpenSSHPrivateKey(pem)
}

// MARK: OpenSSH Binary Format Parser

private func parseOpenSSHBinary(_ data: Data) throws -> NIOSSHPrivateKey {
    var r = BinaryReader(data)

    // Magic: "openssh-key-v1\0" (14 ASCII bytes + 1 null byte)
    guard let magic = try? r.readBytes(14),
          String(data: magic, encoding: .utf8) == "openssh-key-v1",
          (try? r.readBytes(1)) != nil          // null terminator
    else { throw SSHKeyError.invalidMagic }

    // Cipher name — must be "none" (unencrypted)
    let cipher = try r.readUTF8String()
    guard cipher == "none" else { throw SSHKeyError.encryptedKey }

    _ = try r.readUTF8String()  // kdf name
    _ = try r.readBlob()        // kdf options

    let numKeys = try r.readUInt32()
    guard numKeys == 1 else { throw SSHKeyError.unsupportedKeyCount(Int(numKeys)) }

    _ = try r.readBlob()        // public key blob (skip; present in private blob too)

    // Private key blob
    let privateBlob = try r.readBlob()
    var p = BinaryReader(privateBlob)

    let check1 = try p.readUInt32()
    let check2 = try p.readUInt32()
    guard check1 == check2 else { throw SSHKeyError.corruptedKey }

    let keyType = try p.readUTF8String()
    switch keyType {
    case "ssh-ed25519":
        return try parseEd25519PrivateBlob(&p)
    case "ecdsa-sha2-nistp256":
        return try parseECDSAPrivateBlob(&p, curve: .p256)
    case "ecdsa-sha2-nistp384":
        return try parseECDSAPrivateBlob(&p, curve: .p384)
    case "ecdsa-sha2-nistp521":
        return try parseECDSAPrivateBlob(&p, curve: .p521)
    default:
        throw SSHKeyError.unsupportedKeyType(keyType)
    }
}

// MARK: - Key-type-specific private blob parsers

private func parseEd25519PrivateBlob(_ p: inout BinaryReader) throws -> NIOSSHPrivateKey {
    _ = try p.readBlob()                    // public key (32 bytes) — skip
    // Private key blob: 64 bytes where [0..<32] is the private scalar.
    let privateKeyBlob = try p.readBlob()
    guard privateKeyBlob.count >= 32 else { throw SSHKeyError.truncated }
    let rawPrivate = privateKeyBlob.prefix(32)
    let ed25519Key = try Curve25519.Signing.PrivateKey(rawRepresentation: rawPrivate)
    return NIOSSHPrivateKey(ed25519Key: ed25519Key)
}

private enum ECCurve { case p256, p384, p521 }

/// Parses the private blob section for ECDSA keys (P-256, P-384, P-521).
///
/// OpenSSH ECDSA private blob layout (after check1/check2 + keyType string):
///   [string curveName]     — e.g. "nistp256" (skip)
///   [blob   publicPoint]   — uncompressed EC point (skip)
///   [blob   privateScalar] — big-endian integer (32/48/66 bytes)
private func parseECDSAPrivateBlob(_ p: inout BinaryReader, curve: ECCurve) throws -> NIOSSHPrivateKey {
    _ = try p.readUTF8String()              // curve name ("nistp256" etc.) — skip
    _ = try p.readBlob()                    // uncompressed public EC point — skip
    let scalar = try p.readBlob()           // big-endian private scalar
    do {
        switch curve {
        case .p256:
            let key = try P256.Signing.PrivateKey(rawRepresentation: scalar)
            return NIOSSHPrivateKey(p256Key: key)
        case .p384:
            let key = try P384.Signing.PrivateKey(rawRepresentation: scalar)
            return NIOSSHPrivateKey(p384Key: key)
        case .p521:
            let key = try P521.Signing.PrivateKey(rawRepresentation: scalar)
            return NIOSSHPrivateKey(p521Key: key)
        }
    } catch let err as SSHKeyError {
        throw err
    } catch {
        throw SSHKeyError.invalidECKey
    }
}

// MARK: BinaryReader

private struct BinaryReader {
    private let data: Data
    private var offset: Int = 0

    init(_ data: Data) { self.data = data }

    mutating func readBytes(_ count: Int) throws -> Data {
        guard offset + count <= data.count else { throw SSHKeyError.truncated }
        defer { offset += count }
        // Wrap in Data() to normalize the slice to a zero-based index,
        // avoiding crashes from non-zero base offsets on Linux.
        return Data(data[offset ..< offset + count])
    }

    mutating func readUInt32() throws -> UInt32 {
        let bytes = try readBytes(4)
        // Use byte-by-byte construction to avoid alignment issues with Data slices.
        return bytes.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    /// Reads a length-prefixed binary blob.
    mutating func readBlob() throws -> Data {
        let length = Int(try readUInt32())
        return try readBytes(length)
    }

    /// Reads a length-prefixed blob interpreted as UTF-8 text.
    mutating func readUTF8String() throws -> String {
        let blob = try readBlob()
        guard let s = String(data: blob, encoding: .utf8) else {
            throw SSHKeyError.invalidEncoding
        }
        return s
    }
}

// MARK: - Errors

public enum SSHError: Error, Sendable {
    case notConnected
    case commandFailed(String)
}

public enum SSHKeyError: Error, Sendable {
    case invalidBase64
    case invalidMagic
    case encryptedKey           // passphrase-protected keys not yet supported
    case corruptedKey
    case truncated
    case invalidEncoding
    case unsupportedKeyType(String)
    case unsupportedKeyCount(Int)
    case invalidECKey           // ECDSA scalar bytes rejected by Swift Crypto
}
