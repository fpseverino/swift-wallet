import CryptoExtras
public import Foundation
import SwiftASN1
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
    public init(
        pemWWDRCertificate: String,
        pemCertificate: String,
        pemPrivateKey: String,
        pemPrivateKeyPassword: String? = nil
    ) {
        self.pemWWDRCertificate = pemWWDRCertificate
        self.pemCertificate = pemCertificate
        self.pemPrivateKey = pemPrivateKey
        self.pemPrivateKeyPassword = pemPrivateKeyPassword
        self.encoder.dateEncodingStrategy = .iso8601
    }

    private func signature(for manifest: Data) throws -> Data {
        let privateKey: _RSA.Signing.PrivateKey =
            if let pemPrivateKeyPassword {
                try .init(encryptedPEMRepresentation: self.pemPrivateKey) { $0(pemPrivateKeyPassword.utf8) }
            } else {
                try .init(pemRepresentation: self.pemPrivateKey)
            }
        let signature = try CMS.sign(
            manifest,
            signatureAlgorithm: .sha256WithRSAEncryption,
            additionalIntermediateCertificates: [
                Certificate(pemEncoded: self.pemWWDRCertificate)
            ],
            certificate: Certificate(pemEncoded: self.pemCertificate),
            privateKey: .init(privateKey),
            signingTime: Date.now
        )
        return Data(signature)
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
