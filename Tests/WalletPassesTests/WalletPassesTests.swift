import Crypto
import Testing
import WalletPasses
import ZipArchive

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("WalletPasses Tests")
struct WalletPassesTests {
    let decoder = JSONDecoder()
    let pass = TestPass()

    private static let sourceFilesDirectory: String =
        Bundle.module.path(forResource: "SourceFiles", ofType: nil)
        ?? "\(FileManager.default.currentDirectoryPath)/Tests/WalletPassesTests/SourceFiles"

    private static let emptySourceFilesDirectory: String =
        Bundle.module.path(forResource: "EmptyDir", ofType: nil, inDirectory: "SourceFiles")
        ?? "\(FileManager.default.currentDirectoryPath)/Tests/WalletPassesTests/SourceFiles/EmptyDir"

    @Test("Build Pass")
    func build() throws {
        let builder = PassBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey
        )

        let bundle = try builder.build(
            pass: pass,
            sourceFilesDirectoryPath: Self.sourceFilesDirectory
        )

        try testRoundTripped(bundle)
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
            pass: pass,
            sourceFilesDirectoryPath: Self.sourceFilesDirectory
        )

        try testRoundTripped(bundle)
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
            pass: pass,
            sourceFilesDirectoryPath: Self.sourceFilesDirectory,
            personalization: testPersonalization
        )

        try testRoundTripped(bundle, with: testPersonalization)
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
                pass: pass,
                sourceFilesDirectoryPath: Self.sourceFilesDirectory + "/../NoSourceFiles"
            )
        }
    }

    @Test("Build Pass without Icon")
    func buildWithoutIcon() throws {
        let builder = PassBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey
        )

        #expect(throws: WalletPassesError.noIcon) {
            try builder.build(
                pass: pass,
                sourceFilesDirectoryPath: Self.emptySourceFilesDirectory
            )
        }
    }

    @Test("Build Personalizable Pass without Personalization Logo")
    func buildPersonalizedWithoutLogo() throws {
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

        #expect(throws: WalletPassesError.noPersonalizationLogo) {
            try builder.build(
                pass: pass,
                sourceFilesDirectoryPath: Self.emptySourceFilesDirectory,
                personalization: testPersonalization
            )
        }
    }

    private func testRoundTripped(_ bundle: Data, with personalization: PersonalizationJSON? = nil) throws {
        let reader = try ZipArchiveReader(buffer: bundle)
        let directory = try reader.readDirectory()

        #expect(directory.contains { $0.filename == "signature" })

        #expect(directory.contains { $0.filename == "logo.png" })
        #expect(directory.contains { $0.filename == "personalizationLogo.png" })
        #expect(directory.contains { $0.filename == "it-IT.lproj/logo.png" })
        #expect(directory.contains { $0.filename == "it-IT.lproj/personalizationLogo.png" })

        let passBytes = try reader.readFile(#require(directory.first { $0.filename == "pass.json" }))
        let roundTrippedPass = try decoder.decode(TestPass.self, from: Data(passBytes))
        #expect(roundTrippedPass.authenticationToken == pass.authenticationToken)
        #expect(roundTrippedPass.serialNumber == pass.serialNumber)
        #expect(roundTrippedPass.description == pass.description)

        if let personalization {
            let personalizationJSONBytes = try reader.readFile(#require(directory.first { $0.filename == "personalization.json" }))
            let personalizationJSON = try decoder.decode(PersonalizationJSON.self, from: Data(personalizationJSONBytes))
            #expect(personalizationJSON.description == personalization.description)
        }

        let manifestJSONBytes = try reader.readFile(#require(directory.first { $0.filename == "manifest.json" }))
        let manifestJSON = try decoder.decode([String: String].self, from: Data(manifestJSONBytes))
        let iconBytes = try reader.readFile(#require(directory.first { $0.filename == "icon.png" }))
        #expect(manifestJSON["icon.png"] == Insecure.SHA1.hash(data: iconBytes).map { "0\(String($0, radix: 16))".suffix(2) }.joined())
        #expect(manifestJSON["logo.png"] != nil)
        #expect(manifestJSON["personalizationLogo.png"] != nil)
        #expect(manifestJSON["it-IT.lproj/logo.png"] != nil)
        #expect(manifestJSON["it-IT.lproj/personalizationLogo.png"] != nil)
    }
}
