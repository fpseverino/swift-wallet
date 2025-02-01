import Crypto
import Foundation
import Testing
import WalletOrders
import ZipArchive

@Suite("WalletOrders Tests")
struct WalletOrdersTests {
    let decoder = JSONDecoder()
    let order = TestOrder()

    #if os(Windows)
        let openSSLPath = #"C:\Program Files (x86)\Git\usr\bin\openssl.exe"#
    #else
        let openSSLPath: String = "/usr/bin/openssl"
    #endif

    @Test("Build Order")
    func build() throws {
        let builder = OrderBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey,
            openSSLPath: openSSLPath
        )

        let bundle = try builder.build(
            order: order,
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletOrdersTests/SourceFiles"
        )

        try testRoundTripped(bundle)
    }

    @Test("Build Order with Encrypted Key")
    func buildEncrypted() throws {
        let builder = OrderBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.encryptedPemCertificate,
            pemPrivateKey: TestCertificate.encryptedPemPrivateKey,
            pemPrivateKeyPassword: "password",
            openSSLPath: openSSLPath
        )

        let bundle = try builder.build(
            order: order,
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletOrdersTests/SourceFiles"
        )

        try testRoundTripped(bundle)
    }

    @Test("Build Order without Source Files")
    func buildWithoutSourceFiles() throws {
        let builder = OrderBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey,
            openSSLPath: openSSLPath
        )

        #expect(throws: WalletOrdersError.noSourceFiles) {
            try builder.build(
                order: order,
                sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletOrdersTests/NoSourceFiles"
            )
        }
    }

    @Test("Build Order without OpenSSL")
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
                order: order,
                sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletOrdersTests/SourceFiles"
            )
        }
    }

    private func testRoundTripped(_ bundle: Data) throws {
        let reader = try ZipArchiveReader(buffer: bundle)
        let directory = try reader.readDirectory()

        #expect(directory.contains { $0.filename == "signature" })

        #expect(directory.contains { $0.filename == "pet_store_logo.png" })
        #expect(directory.contains { $0.filename == "it-IT.lproj/pet_store_logo.png" })

        let orderBytes = try reader.readFile(#require(directory.first { $0.filename == "order.json" }))
        let roundTrippedOrder = try decoder.decode(TestOrder.self, from: Data(orderBytes))
        #expect(roundTrippedOrder.authenticationToken == order.authenticationToken)
        #expect(roundTrippedOrder.orderIdentifier == order.orderIdentifier)

        let manifestJSONBytes = try reader.readFile(#require(directory.first { $0.filename == "manifest.json" }))
        let manifestJSON = try decoder.decode([String: String].self, from: Data(manifestJSONBytes))
        let iconBytes = try reader.readFile(#require(directory.first { $0.filename == "icon.png" }))
        #expect(manifestJSON["icon.png"] == SHA256.hash(data: iconBytes).map { "0\(String($0, radix: 16))".suffix(2) }.joined())
        #expect(manifestJSON["pet_store_logo.png"] != nil)
        #expect(manifestJSON["it-IT.lproj/pet_store_logo.png"] != nil)
    }
}
