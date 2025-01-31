import Crypto
import Foundation
@_spi(CMS) import X509
import Zip

/// A tool that generates pass content bundles.
public struct PassBuilder: Sendable {
    private let pemWWDRCertificate: String
    private let pemCertificate: String
    private let pemPrivateKey: String
    private let pemPrivateKeyPassword: String?
    private let openSSLURL: URL

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
        self.openSSLURL = URL(fileURLWithPath: openSSLPath)
    }

    /// Generates a signature for a given personalization token.
    ///
    /// See <doc:PersonalizablePasses> for more information.
    ///
    /// - Parameter data: The personalization token data to sign.
    ///
    /// - Returns: The generated signature as `Data`.
    public func signature(for data: Data) throws -> Data {
        // Swift Crypto doesn't support encrypted PEM private keys, so we have to use OpenSSL for that.
        if let pemPrivateKeyPassword {
            guard FileManager.default.fileExists(atPath: self.openSSLURL.path) else {
                throw WalletPassesError.noOpenSSLExecutable
            }

            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let manifestURL = tempDir.appendingPathComponent(Self.manifestFileName)
            let wwdrURL = tempDir.appendingPathComponent("wwdr.pem")
            let certificateURL = tempDir.appendingPathComponent("certificate.pem")
            let privateKeyURL = tempDir.appendingPathComponent("private.pem")
            let signatureURL = tempDir.appendingPathComponent(Self.signatureFileName)

            try data.write(to: manifestURL)
            try self.pemWWDRCertificate.write(to: wwdrURL, atomically: true, encoding: .utf8)
            try self.pemCertificate.write(to: certificateURL, atomically: true, encoding: .utf8)
            try self.pemPrivateKey.write(to: privateKeyURL, atomically: true, encoding: .utf8)

            let process = Process()
            process.currentDirectoryURL = tempDir
            process.executableURL = self.openSSLURL
            process.arguments = [
                "smime", "-binary", "-sign",
                "-certfile", wwdrURL.path,
                "-signer", certificateURL.path,
                "-inkey", privateKeyURL.path,
                "-in", manifestURL.path,
                "-out", signatureURL.path,
                "-outform", "DER",
                "-passin", "pass:\(pemPrivateKeyPassword)",
            ]
            try process.run()
            process.waitUntilExit()

            return try Data(contentsOf: signatureURL)
        } else {
            let signature = try CMS.sign(
                data,
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
        let filesDirectory = URL(fileURLWithPath: sourceFilesDirectoryPath, isDirectory: true)
        guard
            (try? filesDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        else {
            throw WalletPassesError.noSourceFiles
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.copyItem(at: filesDirectory, to: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var archiveFiles: [ArchiveFile] = []

        let passJSON = try self.encoder.encode(pass)
        try passJSON.write(to: tempDir.appendingPathComponent("pass.json"))
        archiveFiles.append(ArchiveFile(filename: "pass.json", data: passJSON))

        // Pass Personalization
        if let personalization {
            let personalizationJSONData = try self.encoder.encode(personalization)
            try personalizationJSONData.write(to: tempDir.appendingPathComponent("personalization.json"))
            archiveFiles.append(ArchiveFile(filename: "personalization.json", data: personalizationJSONData))
        }

        let sourceFilesPaths = try FileManager.default.subpathsOfDirectory(atPath: tempDir.path)

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

        var manifestJSON: [String: String] = [:]

        for relativePath in sourceFilesPaths {
            let fileURL = URL(fileURLWithPath: relativePath, relativeTo: tempDir)

            guard !fileURL.hasDirectoryPath else {
                continue
            }

            guard !(fileURL.lastPathComponent == ".gitkeep" || fileURL.lastPathComponent == ".DS_Store") else {
                continue
            }

            let fileData = try Data(contentsOf: fileURL)

            archiveFiles.append(ArchiveFile(filename: relativePath, data: fileData))

            manifestJSON[relativePath] = Insecure.SHA1.hash(data: fileData).map { "0\(String($0, radix: 16))".suffix(2) }.joined()
        }

        let manifestData = try self.encoder.encode(manifestJSON)
        archiveFiles.append(ArchiveFile(filename: Self.manifestFileName, data: manifestData))
        try archiveFiles.append(ArchiveFile(filename: Self.signatureFileName, data: self.signature(for: manifestData)))

        let zipFile = tempDir.appendingPathComponent("\(UUID().uuidString).pkpass")
        try Zip.zipData(archiveFiles: archiveFiles, zipFilePath: zipFile)
        return try Data(contentsOf: zipFile)
    }
}
