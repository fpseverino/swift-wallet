import Foundation
import Testing

@testable import Passes

@Suite("Passes Tests")
struct PassesTests {
    @Test("Build Pass")
    func build() throws {
        let builder = PassBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey
        )

        let bundle = try builder.build(
            pass: TestPass(),
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/PassesTests/SourceFiles"
        )

        #expect(bundle != nil)
    }

    @Test("Build Pass with Encrypted Key")
    func buildEncrypted() throws {
        let builder = PassBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.encryptedPemCertificate,
            pemPrivateKey: TestCertificate.encryptedPemPrivateKey,
            pemPrivateKeyPassword: "password"
        )

        let bundle = try builder.build(
            pass: TestPass(),
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/PassesTests/SourceFiles"
        )

        #expect(bundle != nil)
    }

    @Test("Build Pass with Personalization")
    func buildPersonalized() throws {
        let builder = PassBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey
        )

        let testPersonalization = PersonalizationJSON(
            requiredPersonalizationFields: [
                .name,
                .emailAddress,
            ],
            description: "Test Personalization"
        )

        let bundle = try builder.build(
            pass: TestPass(),
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/PassesTests/SourceFiles",
            personalization: testPersonalization
        )

        #expect(bundle != nil)
    }

    @Test("Build Pass without Source Files")
    func buildWithoutSourceFiles() throws {
        let builder = PassBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey
        )

        #expect(throws: PassesError.noSourceFiles) {
            try builder.build(
                pass: TestPass(),
                sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/PassesTests/NoSourceFiles"
            )
        }
    }

    @Test("Build Pass without OpenSSL")
    func buildWithoutOpenSSL() throws {
        let builder = PassBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.encryptedPemCertificate,
            pemPrivateKey: TestCertificate.encryptedPemPrivateKey,
            pemPrivateKeyPassword: "password",
            openSSLPath: "/usr/bin/no-openssl"
        )

        #expect(throws: PassesError.noOpenSSLExecutable) {
            try builder.build(
                pass: TestPass(),
                sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/PassesTests/SourceFiles"
            )
        }
    }
}
