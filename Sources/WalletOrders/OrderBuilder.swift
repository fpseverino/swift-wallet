import Crypto
import Foundation
@_spi(CMS) import X509
import Zip

/// A builder for generating order content bundles.
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
        self.openSSLURL = URL(fileURLWithPath: openSSLPath)
    }

    private static func sourceFiles(in directory: URL) throws -> [String: Data] {
        var files: [String: Data] = [:]

        let paths = try FileManager.default.subpathsOfDirectory(atPath: directory.path)

        for relativePath in paths {
            let file = URL(fileURLWithPath: relativePath, relativeTo: directory)
            guard !file.hasDirectoryPath else {
                continue
            }

            guard !(file.lastPathComponent == ".gitkeep" || file.lastPathComponent == ".DS_Store") else {
                continue
            }

            files[relativePath] = try Data(contentsOf: file)
        }

        return files
    }

    private func manifest(for sourceFiles: [String: Data]) throws -> Data {
        let manifest = sourceFiles.mapValues { data in
            SHA256.hash(data: data).map { "0\(String($0, radix: 16))".suffix(2) }.joined()
        }

        return try self.encoder.encode(manifest)
    }

    private func signature(for manifest: Data) throws -> Data {
        // Swift Crypto doesn't support encrypted PEM private keys, so we have to use OpenSSL for that.
        if let pemPrivateKeyPassword {
            guard FileManager.default.fileExists(atPath: self.openSSLURL.path) else {
                throw WalletOrdersError.noOpenSSLExecutable
            }

            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }

            try manifest.write(to: dir.appendingPathComponent(Self.manifestFileName))
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
                "-in", dir.appendingPathComponent(Self.manifestFileName).path,
                "-out", dir.appendingPathComponent(Self.signatureFileName).path,
                "-outform", "DER",
                "-passin", "pass:\(pemPrivateKeyPassword)",
            ]
            try process.run()
            process.waitUntilExit()

            return try Data(contentsOf: dir.appendingPathComponent(Self.signatureFileName))
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
        let filesDirectory = URL(fileURLWithPath: sourceFilesDirectoryPath, isDirectory: true)
        guard
            (try? filesDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        else {
            throw WalletOrdersError.noSourceFiles
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.copyItem(at: filesDirectory, to: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var archiveFiles: [ArchiveFile] = []

        let orderJSON = try self.encoder.encode(order)
        try orderJSON.write(to: tempDir.appendingPathComponent("order.json"))
        archiveFiles.append(ArchiveFile(filename: "order.json", data: orderJSON))

        let sourceFiles = try Self.sourceFiles(in: tempDir)

        let manifest = try self.manifest(for: sourceFiles)
        archiveFiles.append(ArchiveFile(filename: Self.manifestFileName, data: manifest))
        try archiveFiles.append(ArchiveFile(filename: Self.signatureFileName, data: self.signature(for: manifest)))

        for file in sourceFiles {
            archiveFiles.append(ArchiveFile(filename: file.key, data: file.value))
        }

        let zipFile = tempDir.appendingPathComponent("\(UUID().uuidString).order")
        try Zip.zipData(archiveFiles: archiveFiles, zipFilePath: zipFile)
        return try Data(contentsOf: zipFile)
    }
}
