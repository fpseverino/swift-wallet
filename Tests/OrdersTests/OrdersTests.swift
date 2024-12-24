import Foundation
import Testing

@testable import Orders

@Suite("Orders Tests")
struct OrdersTests {
    @Test("Build Order")
    func build() throws {
        let builder = OrderBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey
        )

        let bundle = try builder.build(
            order: TestOrder(),
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/OrdersTests/SourceFiles"
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
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/OrdersTests/SourceFiles"
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

        #expect(throws: OrdersError.noSourceFiles) {
            try builder.build(
                order: TestOrder(),
                sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/OrdersTests/NoSourceFiles"
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

        #expect(throws: OrdersError.noOpenSSLExecutable) {
            try builder.build(
                order: TestOrder(),
                sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/OrdersTests/SourceFiles"
            )
        }
    }
}
