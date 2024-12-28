import Crypto
import Foundation
import Testing
import WalletOrders
import Zip

@Suite("WalletOrders Tests")
struct WalletOrdersTests {
    let decoder = JSONDecoder()
    let order = TestOrder()

    init() {
        Zip.addCustomFileExtension("order")
    }

    @Test("Build Order")
    func build() throws {
        let builder = OrderBuilder(
            pemWWDRCertificate: TestCertificate.pemWWDRCertificate,
            pemCertificate: TestCertificate.pemCertificate,
            pemPrivateKey: TestCertificate.pemPrivateKey
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
            pemPrivateKeyPassword: "password"
        )

        let bundle = try builder.build(
            order: order,
            sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletOrdersTests/SourceFiles"
        )

        try testRoundTripped(bundle)
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
                order: order,
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
                order: order,
                sourceFilesDirectoryPath: "\(FileManager.default.currentDirectoryPath)/Tests/WalletOrdersTests/SourceFiles"
            )
        }
    }

    private func testRoundTripped(_ bundle: Data) throws {
        let orderURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).order")
        try bundle.write(to: orderURL)
        let orderFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try Zip.unzipFile(orderURL, destination: orderFolder)

        #expect(FileManager.default.fileExists(atPath: orderFolder.path.appending("/signature")))

        #expect(FileManager.default.fileExists(atPath: orderFolder.path.appending("/pet_store_logo.png")))
        #expect(FileManager.default.fileExists(atPath: orderFolder.path.appending("/it-IT.lproj/pet_store_logo.png")))

        #expect(FileManager.default.fileExists(atPath: orderFolder.path.appending("/order.json")))
        let orderData = try String(contentsOfFile: orderFolder.path.appending("/order.json")).data(using: .utf8)
        let roundTrippedOrder = try decoder.decode(TestOrder.self, from: orderData!)
        #expect(roundTrippedOrder.authenticationToken == order.authenticationToken)
        #expect(roundTrippedOrder.orderIdentifier == order.orderIdentifier)

        let manifestJSONData = try String(contentsOfFile: orderFolder.path.appending("/manifest.json")).data(using: .utf8)
        let manifestJSON = try decoder.decode([String: String].self, from: manifestJSONData!)
        let iconData = try Data(contentsOf: orderFolder.appendingPathComponent("/icon.png"))
        #expect(manifestJSON["icon.png"] == SHA256.hash(data: iconData).map { "0\(String($0, radix: 16))".suffix(2) }.joined())
        #expect(manifestJSON["pet_store_logo.png"] != nil)
        #expect(manifestJSON["it-IT.lproj/pet_store_logo.png"] != nil)
    }
}
