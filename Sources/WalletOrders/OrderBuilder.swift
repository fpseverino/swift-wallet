import Crypto
import Foundation
@_spi(CMS) import X509
import ZipArchive

/// A tool that generates order content bundles.
///
/// > Warning: You can only sign orders with the same order type identifier of the certificates used to initialize the ``OrderBuilder``.
public struct OrderBuilder: Sendable {
    private let pemWWDRCertificate: String
    private let pemCertificate: String
    private let pemPrivateKey: String
    private let pemPrivateKeyPassword: String?
    private let openSSLURL: URL

    private let encoder = JSONEncoder()

    private static let manifestFileName = "manifest.json"
    private static let signatureFileName = "signature"

    /// Creates a new ``OrderBuilder``.
    ///
    /// > Tip: Obtaining the three certificates files could be a bit tricky. See <doc:Certificates> to get some guidance.
    ///
    /// - Parameters:
    ///   - pemWWDRCertificate: Apple's WWDR.pem certificate in PEM format.
    ///   - pemCertificate: The PEM Certificate for signing orders.
    ///   - pemPrivateKey: The PEM Certificate's private key for signing orders.
    ///   - pemPrivateKeyPassword: The password to the private key. If the key is not encrypted it must be `nil`. Defaults to `nil`.
    ///   - openSSLPath: The location of the `openssl` command as a file path.
    public init(
        pemWWDRCertificate: String,
        pemCertificate: String,
        pemPrivateKey: String,
        pemPrivateKeyPassword: String? = nil,
        openSSLPath: String = "/usr/bin/openssl"
    ) {
        self.pemWWDRCertificate = pemWWDRCertificate
        self.pemCertificate = pemCertificate
        self.pemPrivateKey = pemPrivateKey
        self.pemPrivateKeyPassword = pemPrivateKeyPassword
        self.openSSLURL = URL(filePath: openSSLPath)
    }

    private func signature(for manifest: Data) throws -> Data {
        // Swift Crypto doesn't support encrypted PEM private keys, so we have to use OpenSSL for that.
        if let pemPrivateKeyPassword {
            guard FileManager.default.fileExists(atPath: self.openSSLURL.path()) else {
                throw WalletOrdersError.noOpenSSLExecutable
            }

            let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let manifestURL = tempDir.appending(path: Self.manifestFileName)
            let wwdrURL = tempDir.appending(path: "wwdr.pem")
            let certificateURL = tempDir.appending(path: "certificate.pem")
            let privateKeyURL = tempDir.appending(path: "private.pem")
            let signatureURL = tempDir.appending(path: Self.signatureFileName)

            try manifest.write(to: manifestURL)
            try self.pemWWDRCertificate.write(to: wwdrURL, atomically: true, encoding: .utf8)
            try self.pemCertificate.write(to: certificateURL, atomically: true, encoding: .utf8)
            try self.pemPrivateKey.write(to: privateKeyURL, atomically: true, encoding: .utf8)

            let process = Process()
            process.currentDirectoryURL = tempDir
            process.executableURL = self.openSSLURL
            process.arguments = [
                "smime", "-binary", "-sign",
                "-certfile", wwdrURL.path(),
                "-signer", certificateURL.path(),
                "-inkey", privateKeyURL.path(),
                "-in", manifestURL.path(),
                "-out", signatureURL.path(),
                "-outform", "DER",
                "-passin", "pass:\(pemPrivateKeyPassword)",
            ]
            try process.run()
            process.waitUntilExit()

            return try Data(contentsOf: signatureURL)
        } else {
            let signature = try CMS.sign(
                manifest,
                signatureAlgorithm: .sha256WithRSAEncryption,
                additionalIntermediateCertificates: [
                    Certificate(pemEncoded: self.pemWWDRCertificate)
                ],
                certificate: Certificate(pemEncoded: self.pemCertificate),
                privateKey: .init(pemEncoded: self.pemPrivateKey),
                signingTime: Date.now
            )
            return Data(signature)
        }
    }

    /// Generates the order content bundle for a given order.
    ///
    /// - Parameters:
    ///   - order: The order to generate the content for.
    ///   - sourceFilesDirectoryPath: The path to the source files directory.
    ///
    /// - Returns: The generated order content as `Data`.
    public func build(
        order: some OrderJSON.Properties,
        sourceFilesDirectoryPath: String
    ) throws -> Data {
        let filesDirectory = URL(filePath: sourceFilesDirectoryPath, directoryHint: .isDirectory)
        guard (try? filesDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false else {
            throw WalletOrdersError.noSourceFiles
        }

        var archiveFiles: [String: Data] = [:]
        var manifestJSON: [String: String] = [:]

        let orderJSON = try self.encoder.encode(order)
        archiveFiles["order.json"] = orderJSON
        manifestJSON["order.json"] = orderJSON.manifestHash

        let sourceFilesPaths = try FileManager.default.subpathsOfDirectory(atPath: filesDirectory.path())
        for relativePath in sourceFilesPaths {
            let fileURL = URL(filePath: relativePath, directoryHint: .checkFileSystem, relativeTo: filesDirectory)
            guard !fileURL.hasDirectoryPath else { continue }
            if fileURL.lastPathComponent == ".gitkeep" || fileURL.lastPathComponent == ".DS_Store" { continue }

            let fileData = try Data(contentsOf: fileURL)
            archiveFiles[relativePath] = fileData
            manifestJSON[relativePath] = fileData.manifestHash
        }

        let manifestData = try self.encoder.encode(manifestJSON)
        archiveFiles[Self.manifestFileName] = manifestData
        try archiveFiles[Self.signatureFileName] = self.signature(for: manifestData)

        let writer = ZipArchiveWriter()
        for (filename, contents) in archiveFiles {
            try writer.writeFile(filename: filename, contents: Array(contents))
        }
        return try Data(writer.finalizeBuffer())
    }
}

extension Data {
    fileprivate var manifestHash: String {
        SHA256.hash(data: self).map { "0\(String($0, radix: 16))".suffix(2) }.joined()
    }
}
