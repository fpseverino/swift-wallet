import Crypto
import Foundation
@_spi(CMS) import X509
import Zip

/// A builder for generating pass content bundles.
public struct PassBuilder: Sendable {
    private let pemWWDRCertificate: String
    private let pemCertificate: String
    private let pemPrivateKey: String
    private let pemPrivateKeyPassword: String?
    private let openSSLURL: URL

    private let encoder = JSONEncoder()

    /// Creates a new ``PassBuilder``.
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

    private func manifest(for directory: URL) throws -> Data {
        var manifest: [String: String] = [:]

        let paths = try FileManager.default.subpathsOfDirectory(atPath: directory.path)
        for relativePath in paths {
            let file = URL(fileURLWithPath: relativePath, relativeTo: directory)
            guard !file.hasDirectoryPath else {
                continue
            }

            let hash = try Insecure.SHA1.hash(data: Data(contentsOf: file))
            manifest[relativePath] = hash.map { "0\(String($0, radix: 16))".suffix(2) }.joined()
        }

        return try encoder.encode(manifest)
    }

    private func signature(for manifest: Data) throws -> Data {
        // Swift Crypto doesn't support encrypted PEM private keys, so we have to use OpenSSL for that.
        if let pemPrivateKeyPassword {
            guard FileManager.default.fileExists(atPath: self.openSSLURL.path) else {
                throw PassesError.noOpenSSLExecutable
            }

            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }

            try manifest.write(to: dir.appendingPathComponent("manifest.json"))
            try self.pemWWDRCertificate.write(to: dir.appendingPathComponent("wwdr.pem"), atomically: true, encoding: .utf8)
            try self.pemCertificate.write(to: dir.appendingPathComponent("certificate.pem"), atomically: true, encoding: .utf8)
            try self.pemPrivateKey.write(to: dir.appendingPathComponent("private.pem"), atomically: true, encoding: .utf8)

            let process = Process()
            process.currentDirectoryURL = dir
            process.executableURL = self.openSSLURL
            process.arguments = [
                "smime", "-binary", "-sign",
                "-certfile", dir.appendingPathComponent("wwdr.pem").path,
                "-signer", dir.appendingPathComponent("certificate.pem").path,
                "-inkey", dir.appendingPathComponent("private.pem").path,
                "-in", dir.appendingPathComponent("manifest.json").path,
                "-out", dir.appendingPathComponent("signature").path,
                "-outform", "DER",
                "-passin", "pass:\(pemPrivateKeyPassword)",
            ]
            try process.run()
            process.waitUntilExit()

            return try Data(contentsOf: dir.appendingPathComponent("signature"))
        } else {
            let signature = try CMS.sign(
                manifest,
                signatureAlgorithm: .sha256WithRSAEncryption,
                additionalIntermediateCertificates: [
                    Certificate(pemEncoded: self.pemWWDRCertificate)
                ],
                certificate: Certificate(pemEncoded: self.pemCertificate),
                privateKey: .init(pemEncoded: self.pemPrivateKey),
                signingTime: Date()
            )
            return Data(signature)
        }
    }

    /// Generates the pass content bundle for a given pass.
    ///
    /// - Parameters:
    ///   - pass: The pass to generate the content for.
    ///   - sourceFilesDirectoryPath: The path to the source files directory.
    ///   - personalization: The personalization information for the pass.
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
            throw PassesError.noSourceFiles
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.copyItem(at: filesDirectory, to: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var files: [ArchiveFile] = []

        let passJSON = try self.encoder.encode(pass)
        try passJSON.write(to: tempDir.appendingPathComponent("pass.json"))
        files.append(ArchiveFile(filename: "pass.json", data: passJSON))

        // Pass Personalization
        if let personalization {
            let personalizationJSONData = try self.encoder.encode(personalization)
            try personalizationJSONData.write(to: tempDir.appendingPathComponent("personalization.json"))
            files.append(ArchiveFile(filename: "personalization.json", data: personalizationJSONData))
        }

        let manifest = try self.manifest(for: tempDir)
        files.append(ArchiveFile(filename: "manifest.json", data: manifest))
        try files.append(ArchiveFile(filename: "signature", data: self.signature(for: manifest)))

        let paths = try FileManager.default.subpathsOfDirectory(atPath: filesDirectory.path)
        for relativePath in paths {
            let file = URL(fileURLWithPath: relativePath, relativeTo: tempDir)
            guard !file.hasDirectoryPath else {
                continue
            }

            try files.append(ArchiveFile(filename: relativePath, data: Data(contentsOf: file)))
        }

        let zipFile = tempDir.appendingPathComponent("\(UUID().uuidString).pkpass")
        try Zip.zipData(archiveFiles: files, zipFilePath: zipFile)
        return try Data(contentsOf: zipFile)
    }
}
