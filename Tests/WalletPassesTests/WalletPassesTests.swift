import Foundation
import Testing
import WalletPasses

@Suite("WalletPasses Tests")
struct WalletPassesTests {
    @Test("Build Pass")
    func build() throws {
        let builder = PassBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey
        )

        let bundle = try builder.build(
            pass: TestPass(),
            sourceFilesDirectoryPath: NSString(#filePath).deletingLastPathComponent + "/SourceFiles"
        )

        #expect(bundle != nil)
    }

    #if os(macOS) || os(Linux)
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
                sourceFilesDirectoryPath: NSString(#filePath).deletingLastPathComponent + "/SourceFiles"
            )

            #expect(bundle != nil)
        }
    #endif

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
            sourceFilesDirectoryPath: NSString(#filePath).deletingLastPathComponent + "/SourceFiles",
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

        #expect(throws: WalletPassesError.noSourceFiles) {
            try builder.build(
                pass: TestPass(),
                sourceFilesDirectoryPath: NSString(#filePath).deletingLastPathComponent + "/NoSourceFiles"
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

        #expect(throws: WalletPassesError.noOpenSSLExecutable) {
            try builder.build(
                pass: TestPass(),
                sourceFilesDirectoryPath: NSString(#filePath).deletingLastPathComponent + "/SourceFiles"
            )
        }
    }
}
