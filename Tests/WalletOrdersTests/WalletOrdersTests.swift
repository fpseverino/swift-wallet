import Foundation
import Testing
import WalletOrders

@Suite("WalletOrders Tests")
struct WalletOrdersTests {
    @Test("Build Order")
    func build() throws {
        let builder = OrderBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey
        )

        let bundle = try builder.build(
            order: TestOrder(),
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletOrdersTests/SourceFiles"
        )

        #expect(bundle != nil)
    }

    @Test("Build Order with Encrypted Key")
    func buildEncrypted() throws {
        let builder = OrderBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.encryptedPemCertificate,
            pemPrivateKey: TestCertificate.encryptedPemPrivateKey,
            pemPrivateKeyPassword: "password"
        )

        let bundle = try builder.build(
            order: TestOrder(),
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletOrdersTests/SourceFiles"
        )

        #expect(bundle != nil)
    }

    @Test("Build Pass without Source Files")
    func buildWithoutSourceFiles() throws {
        let builder = OrderBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey
        )

        #expect(throws: WalletOrdersError.noSourceFiles) {
            try builder.build(
                order: TestOrder(),
                sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletOrdersTests/NoSourceFiles"
            )
        }
    }

    @Test("Build Pass without OpenSSL")
    func buildWithoutOpenSSL() throws {
        let builder = OrderBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.encryptedPemCertificate,
            pemPrivateKey: TestCertificate.encryptedPemPrivateKey,
            pemPrivateKeyPassword: "password",
            openSSLPath: "/usr/bin/no-openssl"
        )

        #expect(throws: WalletOrdersError.noOpenSSLExecutable) {
            try builder.build(
                order: TestOrder(),
                sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletOrdersTests/SourceFiles"
            )
        }
    }
}
