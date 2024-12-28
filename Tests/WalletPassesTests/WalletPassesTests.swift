import Crypto
import Foundation
import Testing
import WalletPasses
import Zip

@Suite("WalletPasses Tests")
struct WalletPassesTests {
    let decoder = JSONDecoder()
    let pass = TestPass()

    init() {
        Zip.addCustomFileExtension("pkpass")
    }

    @Test("Build Pass")
    func build() throws {
        let builder = PassBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey
        )

        let bundle = try builder.build(
            pass: pass,
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletPassesTests/SourceFiles"
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
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletPassesTests/SourceFiles"
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
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletPassesTests/SourceFiles",
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
                sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletPassesTests/NoSourceFiles"
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
                pass: pass,
                sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletPassesTests/SourceFiles"
            )
        }
    }

    private func testRoundTripped(_ bundle: Data, with personalization: PersonalizationJSON? = nil) throws {
        let passURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pkpass")
        try bundle.write(to: passURL)
        let passFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try Zip.unzipFile(passURL, destination: passFolder)

        #expect(FileManager.default.fileExists(atPath: passFolder.path.appending("/signature")))

        #expect(FileManager.default.fileExists(atPath: passFolder.path.appending("/logo.png")))
        #expect(FileManager.default.fileExists(atPath: passFolder.path.appending("/personalizationLogo.png")))
        #expect(FileManager.default.fileExists(atPath: passFolder.path.appending("/it-IT.lproj/logo.png")))
        #expect(FileManager.default.fileExists(atPath: passFolder.path.appending("/it-IT.lproj/personalizationLogo.png")))

        #expect(FileManager.default.fileExists(atPath: passFolder.path.appending("/pass.json")))
        let passData = try String(contentsOfFile: passFolder.path.appending("/pass.json")).data(using: .utf8)!
        let roundTrippedPass = try decoder.decode(TestPass.self, from: passData)
        #expect(roundTrippedPass.authenticationToken == pass.authenticationToken)
        #expect(roundTrippedPass.serialNumber == pass.serialNumber)
        #expect(roundTrippedPass.description == pass.description)

        if let personalization {
            let personalizationJSONData = try String(contentsOfFile: passFolder.path.appending("/personalization.json")).data(using: .utf8)
            let personalizationJSON = try decoder.decode(PersonalizationJSON.self, from: personalizationJSONData!)
            #expect(personalizationJSON.description == personalization.description)
        }

        let manifestJSONData = try String(contentsOfFile: passFolder.path.appending("/manifest.json")).data(using: .utf8)!
        let manifestJSON = try decoder.decode([String: String].self, from: manifestJSONData)
        let iconData = try Data(contentsOf: passFolder.appendingPathComponent("/icon.png"))
        #expect(manifestJSON["icon.png"] == Insecure.SHA1.hash(data: iconData).map { "0\(String($0, radix: 16))".suffix(2) }.joined())
        #expect(manifestJSON["logo.png"] != nil)
        #expect(manifestJSON["personalizationLogo.png"] != nil)
        #expect(manifestJSON["it-IT.lproj/logo.png"] != nil)
        #expect(manifestJSON["it-IT.lproj/personalizationLogo.png"] != nil)
    }
}
