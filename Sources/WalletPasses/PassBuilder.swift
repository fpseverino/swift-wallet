import CryptoExtras
@_spi(CMS) import X509
import ZipArchive

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A tool that generates pass content bundles.
///
/// > Warning: You can only sign passes with the same pass type identifier of the certificates used to initialize the ``PassBuilder``.
public struct PassBuilder: Sendable {
    private let pemWWDRCertificate: String
    private let pemCertificate: String
    private let pemPrivateKey: String
    private let pemPrivateKeyPassword: String?

    private let encoder = JSONEncoder()

    private static let manifestFileName = "manifest.json"
    private static let signatureFileName = "signature"

    /// Creates a new ``PassBuilder``.
    ///
    /// > Tip: Obtaining the three certificates files could be a bit tricky. See <doc:Certificates> to get some guidance.
    ///
    /// - Parameters:
    ///   - pemWWDRCertificate: Apple's WWDR.pem certificate in PEM format.
    ///   - pemCertificate: The PEM Certificate for signing passes.
    ///   - pemPrivateKey: The PEM Certificate's private key for signing passes.
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

    /// Generates a signature for a given personalization token.
    ///
    /// See <doc:PersonalizablePasses> for more information.
    ///
    /// - Parameter data: The personalization token data to sign.
    ///
    /// - Returns: The generated signature as `Data`.
    public func signature(for data: Data) throws -> Data {
        let privateKey: _RSA.Signing.PrivateKey =
            if let pemPrivateKeyPassword {
                try .init(encryptedPEMRepresentation: self.pemPrivateKey) { $0(pemPrivateKeyPassword.utf8) }
            } else {
                try .init(pemRepresentation: self.pemPrivateKey)
            }
        let signature = try CMS.sign(
            data,
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

    /// Generates the pass content bundle for a given pass.
    ///
    /// - Parameters:
    ///   - pass: The pass to generate the content for.
    ///   - sourceFilesDirectoryPath: The path to the source files directory.
    ///   - personalization: The personalization information for the pass. See <doc:PersonalizablePasses> for more information.
    ///
    /// - Returns: The generated pass content as `Data`.
    public func build(
        pass: some PassJSON.Properties,
        sourceFilesDirectoryPath: String,
        personalization: PersonalizationJSON? = nil
    ) throws -> Data {
        let filesDirectory = URL(filePath: sourceFilesDirectoryPath, directoryHint: .isDirectory)
        guard (try? filesDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false else {
            throw WalletPassesError.noSourceFiles
        }

        var archiveFiles: [String: Data] = [:]
        var manifestJSON: [String: String] = [:]

        let passJSON = try self.encoder.encode(pass)
        archiveFiles["pass.json"] = passJSON
        manifestJSON["pass.json"] = passJSON.manifestHash

        if let personalization {
            let personalizationJSONData = try self.encoder.encode(personalization)
            archiveFiles["personalization.json"] = personalizationJSONData
            manifestJSON["personalization.json"] = personalizationJSONData.manifestHash
        }

        let sourceFilesPaths = try FileManager.default.subpathsOfDirectory(atPath: filesDirectory.path())

        if personalization != nil {
            guard
                sourceFilesPaths.contains("personalizationLogo.png")
                    || sourceFilesPaths.contains("personalizationLogo@1x.png")
                    || sourceFilesPaths.contains("personalizationLogo@2x.png")
                    || sourceFilesPaths.contains("personalizationLogo@3x.png")
            else {
                throw WalletPassesError.noPersonalizationLogo
            }
        }

        guard
            sourceFilesPaths.contains("icon.png")
                || sourceFilesPaths.contains("icon@1x.png")
                || sourceFilesPaths.contains("icon@2x.png")
                || sourceFilesPaths.contains("icon@3x.png")
        else {
            throw WalletPassesError.noIcon
        }

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
        Insecure.SHA1.hash(data: self).map { "0\(String($0, radix: 16))".suffix(2) }.joined()
    }
}
