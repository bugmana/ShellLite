import XCTest
@testable import ShellLiteCore

final class ShellLiteTests: XCTestCase {

    // MARK: - ServerProfile (model + Codable) ─────────────────────────────

    func testServerProfileDefaultPort() {
        let p = ServerProfile(
            displayName: "Dev Box",
            host: "192.168.1.10",
            username: "root",
            authMethod: .password(credentialTag: "tag-1")
        )
        XCTAssertEqual(p.port, 22)
    }

    func testServerProfileCustomPort() {
        let p = ServerProfile(
            displayName: "Custom Port",
            host: "example.com",
            port: 2222,
            username: "admin",
            authMethod: .password(credentialTag: "tag-2")
        )
        XCTAssertEqual(p.port, 2222)
    }

    func testServerProfilePasswordCodableRoundTrip() throws {
        let original = ServerProfile(
            displayName: "Web Server",
            host: "10.0.0.1",
            port: 22,
            username: "ubuntu",
            authMethod: .password(credentialTag: "cred-abc")
        )
        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServerProfile.self, from: data)
        XCTAssertEqual(original, decoded)
        // Verify the auth method round-tripped correctly.
        if case .password(let tag) = decoded.authMethod {
            XCTAssertEqual(tag, "cred-abc")
        } else {
            XCTFail("Expected .password authMethod after round-trip")
        }
    }

    func testServerProfileSSHKeyCodableRoundTrip() throws {
        let original = ServerProfile(
            displayName: "Bastion",
            host: "bastion.internal",
            port: 22,
            username: "ops",
            authMethod: .sshKey(privateKeyTag: "key-xyz")
        )
        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServerProfile.self, from: data)
        XCTAssertEqual(original, decoded)
        if case .sshKey(let tag) = decoded.authMethod {
            XCTAssertEqual(tag, "key-xyz")
        } else {
            XCTFail("Expected .sshKey authMethod after round-trip")
        }
    }

    func testServerProfileHashableEquality() {
        let p1 = ServerProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            displayName: "A",
            host: "a.com",
            username: "u",
            authMethod: .password(credentialTag: "t1")
        )
        let p2 = ServerProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            displayName: "A",
            host: "a.com",
            username: "u",
            authMethod: .password(credentialTag: "t1")
        )
        XCTAssertEqual(p1, p2)
        XCTAssertEqual(p1.hashValue, p2.hashValue)
    }

    func testServerProfileUniqueIDs() {
        let p1 = ServerProfile(displayName: "A", host: "a", username: "u", authMethod: .password(credentialTag: "t"))
        let p2 = ServerProfile(displayName: "A", host: "a", username: "u", authMethod: .password(credentialTag: "t"))
        XCTAssertNotEqual(p1.id, p2.id)
    }

    func testServerProfileInitialCommandDefaultsToNil() {
        let p = ServerProfile(
            displayName: "Test", host: "localhost",
            username: "root", authMethod: .password(credentialTag: "x")
        )
        XCTAssertNil(p.initialCommand)
    }

    func testServerProfileInitialCommandCodableRoundTrip() throws {
        let original = ServerProfile(
            displayName: "Test", host: "localhost",
            username: "root", authMethod: .password(credentialTag: "x"),
            initialCommand: "tmux attach || tmux new"
        )
        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServerProfile.self, from: data)
        XCTAssertEqual(decoded.initialCommand, "tmux attach || tmux new")
    }

    // MARK: - KeychainManager (Linux in-memory) ───────────────────────────

    func testKeychainSaveAndRetrieve() throws {
        try KeychainManager.shared.save(password: "s3cr3t", for: "test-retrieve")
        let result = try KeychainManager.shared.retrieve(for: "test-retrieve")
        XCTAssertEqual(result, "s3cr3t")
        KeychainManager.shared.delete(tag: "test-retrieve")
    }

    func testKeychainOverwrite() throws {
        try KeychainManager.shared.save(password: "first",  for: "test-overwrite")
        try KeychainManager.shared.save(password: "second", for: "test-overwrite")
        let result = try KeychainManager.shared.retrieve(for: "test-overwrite")
        XCTAssertEqual(result, "second")
        KeychainManager.shared.delete(tag: "test-overwrite")
    }

    func testKeychainNotFound() {
        XCTAssertThrowsError(try KeychainManager.shared.retrieve(for: "nonexistent-tag"))
    }

    func testKeychainDeleteRemovesEntry() throws {
        try KeychainManager.shared.save(password: "to-delete", for: "test-delete")
        KeychainManager.shared.delete(tag: "test-delete")
        XCTAssertThrowsError(try KeychainManager.shared.retrieve(for: "test-delete"))
    }

    func testKeychainDeleteIsIdempotent() {
        KeychainManager.shared.delete(tag: "never-existed")
        // Should not throw or crash.
    }

    func testKeychainDataRoundTrip() throws {
        let bytes = Data([0x01, 0x02, 0xAB, 0xFF])
        try KeychainManager.shared.saveData(bytes, for: "test-data")
        let result = try KeychainManager.shared.retrieveData(for: "test-data")
        XCTAssertEqual(result, bytes)
        KeychainManager.shared.delete(tag: "test-data")
    }

    // MARK: - SSH Key Parser ───────────────────────────────────────────────

    /// A real unencrypted Ed25519 test key generated specifically for unit tests.
    /// ⚠️ NEVER use this key for any actual server — it exists for testing only.
    private let testEd25519PEM = """
    -----BEGIN OPENSSH PRIVATE KEY-----
    b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
    QyNTUxOQAAACBPXQGAbXHSgfDJV7lkQyU1/hMOlIPvUH4WuwDtPzudkAAAAIhs52H5bOdh
    +QAAAAtzc2gtZWQyNTUxOQAAACBPXQGAbXHSgfDJV7lkQyU1/hMOlIPvUH4WuwDtPzudkA
    AAAECorqSPSmXNhJGOv2v5e0tkhVv+2pxMExFBgGbVT1xMEE9dAYBtcdKB8MlXuWRDJTX+
    Ew6Ug+9Qfha7AO0/O52QAAAABHRlc3QB
    -----END OPENSSH PRIVATE KEY-----
    """

    func testSSHKeyParserRejectsGarbage() {
        XCTAssertThrowsError(try parseOpenSSHPrivateKey("not a key"))
    }

    func testSSHKeyParserRejectsRSAHeader() {
        let fake = """
        -----BEGIN RSA PRIVATE KEY-----
        AAAA
        -----END RSA PRIVATE KEY-----
        """
        XCTAssertThrowsError(try parseOpenSSHPrivateKey(fake)) { error in
            // Should fail on magic header
            if case SSHKeyError.invalidBase64 = error { return }
            if case SSHKeyError.invalidMagic  = error { return }
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSSHKeyParserEncryptedKeyThrows() {
        // Simulate an encrypted key by crafting a minimal binary that
        // passes the magic check but has cipher != "none".
        var data = Data()
        // Magic
        data.append(contentsOf: "openssh-key-v1".utf8)
        data.append(0x00) // null terminator
        // cipher = "aes256-ctr"
        appendOpenSSHString("aes256-ctr", to: &data)
        // kdf = "bcrypt"
        appendOpenSSHString("bcrypt", to: &data)
        // kdf options (empty)
        appendOpenSSHUInt32(0, to: &data)
        // num keys
        appendOpenSSHUInt32(1, to: &data)

        let b64 = data.base64EncodedString()
        let pem = "-----BEGIN OPENSSH PRIVATE KEY-----\n\(b64)\n-----END OPENSSH PRIVATE KEY-----"

        XCTAssertThrowsError(try parseOpenSSHPrivateKey(pem)) { error in
            XCTAssertTrue(error is SSHKeyError)
            if case SSHKeyError.encryptedKey = error { return }
            XCTFail("Expected .encryptedKey, got \(error)")
        }
    }

    // MARK: - ECDSA Key Parser ───────────────────────────────────────────────

    /// Real unencrypted ECDSA P-256 test key (generated for testing only).
    /// ⚠️ NEVER use this key for any actual server — it exists for testing only.
    private let testECDSAP256PEM = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAaAAAABNlY2RzYS
        1zaGEyLW5pc3RwMjU2AAAACG5pc3RwMjU2AAAAQQS+fpetpDWB6T5HyZqzW4D7UxOL+dr7
        pejwWAfQ4nwIm0XsfcTG1Mxa3HhyQcOenHv2w/ILGlwVki0RyHZpI28IAAAAoKb2/d2m9v
        3dAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBL5+l62kNYHpPkfJ
        mrNbgPtTE4v52vul6PBYB9DifAibRex9xMbUzFrceHJBw56ce/bD8gsaXBWSLRHIdmkjbw
        gAAAAgQqEPWJ1HsRw5du+HWalcIf9T2vd/zQotfqgw6/ysm9YAAAAEdGVzdAECAwQ=
        -----END OPENSSH PRIVATE KEY-----
        """

    /// Real unencrypted ECDSA P-384 test key (generated for testing only).
    /// ⚠️ NEVER use this key for any actual server — it exists for testing only.
    private let testECDSAP384PEM = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAiAAAABNlY2RzYS
        1zaGEyLW5pc3RwMzg0AAAACG5pc3RwMzg0AAAAYQS2q9lBtjUzLoZnsxDKotVHUDFExG77
        GviR+D9+9+1TNDPMAk9QYvM0Fzy+mT4SelIY+f3mPiLDTmCCJV7cvG3SISjpV61NOsyfwg
        rhiFoOFNq5A003KcoTa1mssc+BIksAAADQCoXn/AqF5/wAAAATZWNkc2Etc2hhMi1uaXN0
        cDM4NAAAAAhuaXN0cDM4NAAAAGEEtqvZQbY1My6GZ7MQyqLVR1AxRMRu+xr4kfg/fvftUz
        QzzAJPUGLzNBc8vpk+EnpSGPn95j4iw05ggiVe3Lxt0iEo6VetTTrMn8IK4YhaDhTauQNN
        NynKE2tZrLHPgSJLAAAAME1Ch1Lbmlxei0gM6x5VXAlO/oXDZ+JHmR0Sqt4u/W6GdBFUMq
        2qbjMtLF2RE+9hnwAAAAR0ZXN0AQIDBA==
        -----END OPENSSH PRIVATE KEY-----
        """

    /// Real unencrypted ECDSA P-521 test key (generated for testing only).
    /// ⚠️ NEVER use this key for any actual server — it exists for testing only.
    private let testECDSAP521PEM = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAArAAAABNlY2RzYS
        1zaGEyLW5pc3RwNTIxAAAACG5pc3RwNTIxAAAAhQQA6TJoPBwoHb/NGzgJRdAHyGraUpNh
        k+tpaR3QTOqNbm/NurStWg+5LLF2qSnH9TJRPDW734VW3oWahL+cHxgkYD8A2U+Gmk0Hc/
        kQTpRu9fIdIOCuM8t1/Yx31erb55dyF35p5UxdG/ZFxXgAiPg5YGiTuaLbDVYbOok41z9H
        9L38qcsAAAEIO0GqaztBqmsAAAATZWNkc2Etc2hhMi1uaXN0cDUyMQAAAAhuaXN0cDUyMQ
        AAAIUEAOkyaDwcKB2/zRs4CUXQB8hq2lKTYZPraWkd0EzqjW5vzbq0rVoPuSyxdqkpx/Uy
        UTw1u9+FVt6FmoS/nB8YJGA/ANlPhppNB3P5EE6UbvXyHSDgrjPLdf2Md9Xq2+eXchd+ae
        VMXRv2RcV4AIj4OWBok7mi2w1WGzqJONc/R/S9/KnLAAAAQgH45YZl4Oj+1yQd8zLCBzAY
        o2B15B0RxJnIHWGKjewNGM86n43Q5PM7ff0lSSeiOZhJRk7bhz5TExhl+hEKJNDaRwAAAA
        R0ZXN0AQIDBAUG
        -----END OPENSSH PRIVATE KEY-----
        """

    func testSSHKeyParserAcceptsECDSAP256() throws {
        // Successful parse (no throw) proves the P-256 path was invoked.
        // The key is usable for signing — the publicKey accessor verifies that.
        let key = try parseOpenSSHPrivateKey(testECDSAP256PEM)
        _ = key.publicKey   // accessing publicKey exercises the backing key enum
    }

    func testSSHKeyParserAcceptsECDSAP384() throws {
        let key = try parseOpenSSHPrivateKey(testECDSAP384PEM)
        _ = key.publicKey
    }

    func testSSHKeyParserAcceptsECDSAP521() throws {
        let key = try parseOpenSSHPrivateKey(testECDSAP521PEM)
        _ = key.publicKey
    }

    func testSSHKeyParserRejectsRSA() {
        // RSA keys use "ssh-rsa" as the inner key-type string — unsupported.
        // Craft a minimal openssh binary with ssh-rsa key type.
        var data = Data()
        data.append(contentsOf: "openssh-key-v1".utf8)
        data.append(0x00)                           // null terminator
        appendOpenSSHString("none", to: &data)      // cipher
        appendOpenSSHString("none", to: &data)      // kdf
        appendOpenSSHUInt32(0, to: &data)           // kdf options length (empty blob)
        appendOpenSSHUInt32(1, to: &data)           // num keys
        // public key blob (minimal placeholder)
        appendOpenSSHUInt32(4, to: &data)           // pubkey blob length
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        // private blob
        var priv = Data()
        appendOpenSSHUInt32(0xDEAD_BEEF, to: &priv) // check1
        appendOpenSSHUInt32(0xDEAD_BEEF, to: &priv) // check2 (match)
        appendOpenSSHString("ssh-rsa", to: &priv)   // key type → triggers unsupportedKeyType
        // Wrap private blob
        appendOpenSSHUInt32(UInt32(priv.count), to: &data)
        data.append(priv)

        let pem = "-----BEGIN OPENSSH PRIVATE KEY-----\n"
            + data.base64EncodedString()
            + "\n-----END OPENSSH PRIVATE KEY-----"

        XCTAssertThrowsError(try parseOpenSSHPrivateKey(pem)) { error in
            if case SSHKeyError.unsupportedKeyType(let t) = error {
                XCTAssertEqual(t, "ssh-rsa")
            } else {
                XCTFail("Expected .unsupportedKeyType(\"ssh-rsa\"), got \(error)")
            }
        }
    }

    func testDeprecatedEd25519ParserNameStillWorks() throws {
        // The old name must remain callable as a deprecated alias.
        // Use the P-256 PEM — the alias just forwards to parseOpenSSHPrivateKey.
        let key = try parseOpenSSHEd25519Key(testECDSAP256PEM)  // swiftlint:disable:this
        _ = key.publicKey
    }

    // MARK: - Helpers for binary construction

    private func appendOpenSSHUInt32(_ value: UInt32, to data: inout Data) {
        var v = value.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
    }

    private func appendOpenSSHString(_ string: String, to data: inout Data) {
        let bytes = Array(string.utf8)
        appendOpenSSHUInt32(UInt32(bytes.count), to: &data)
        data.append(contentsOf: bytes)
    }
}
