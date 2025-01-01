/// Errors that can be thrown by Apple Wallet passes.
public struct WalletPassesError: Error, Sendable, Equatable {
    /// The type of the errors that can be thrown by Apple Wallet passes.
    public struct ErrorType: Sendable, Hashable, CustomStringConvertible, Equatable {
        enum Base: String, Sendable, Equatable {
            case noSourceFiles
            case noIcon
            case noPersonalizationLogo
            case noOpenSSLExecutable
            case invalidNumberOfPasses
        }

        let base: Base

        private init(_ base: Base) {
            self.base = base
        }

        /// The path for the source files is not a directory.
        public static let noSourceFiles = Self(.noSourceFiles)
        /// The `icon@XX.png` file is missing.
        public static let noIcon = Self(.noIcon)
        /// The `personalizationLogo@XX.png` file is missing.
        public static let noPersonalizationLogo = Self(.noPersonalizationLogo)
        /// The `openssl` executable is missing.
        public static let noOpenSSLExecutable = Self(.noOpenSSLExecutable)
        /// The number of passes to bundle is invalid.
        public static let invalidNumberOfPasses = Self(.invalidNumberOfPasses)

        /// A textual representation of this error.
        public var description: String {
            base.rawValue
        }
    }

    private struct Backing: Sendable, Equatable {
        fileprivate let errorType: ErrorType

        init(errorType: ErrorType) {
            self.errorType = errorType
        }

        static func == (lhs: WalletPassesError.Backing, rhs: WalletPassesError.Backing) -> Bool {
            lhs.errorType == rhs.errorType
        }
    }

    private var backing: Backing

    /// The type of this error.
    public var errorType: ErrorType { backing.errorType }

    private init(errorType: ErrorType) {
        self.backing = .init(errorType: errorType)
    }

    /// The path for the source files is not a directory.
    public static let noSourceFiles = Self(errorType: .noSourceFiles)

    /// The `icon@XX.png` file is missing.
    public static let noIcon = Self(errorType: .noIcon)

    /// The `personalizationLogo@XX.png` file is missing.
    public static let noPersonalizationLogo = Self(errorType: .noPersonalizationLogo)

    /// The `openssl` executable is missing.
    public static let noOpenSSLExecutable = Self(errorType: .noOpenSSLExecutable)

    /// The number of passes to bundle is invalid.
    public static let invalidNumberOfPasses = Self(errorType: .invalidNumberOfPasses)

    public static func == (lhs: WalletPassesError, rhs: WalletPassesError) -> Bool {
        lhs.backing == rhs.backing
    }
}

extension WalletPassesError: CustomStringConvertible {
    /// A textual representation of this error.
    public var description: String {
        "WalletPassesError(errorType: \(self.errorType))"
    }
}
