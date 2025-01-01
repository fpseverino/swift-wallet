/// Errors that can be thrown by Apple Wallet orders.
public struct WalletOrdersError: Error, Sendable, Equatable {
    /// The type of the errors that can be thrown by Apple Wallet orders.
    public struct ErrorType: Sendable, Hashable, CustomStringConvertible, Equatable {
        enum Base: String, Sendable, Equatable {
            case noSourceFiles
            case noOrderJSONFile
            case noOpenSSLExecutable
        }

        let base: Base

        private init(_ base: Base) {
            self.base = base
        }

        /// The path for the source files is not a directory.
        public static let noSourceFiles = Self(.noSourceFiles)
        /// The `order.json` file is missing.
        public static let noOrderJSONFile = Self(.noOrderJSONFile)
        /// The `openssl` executable is missing.
        public static let noOpenSSLExecutable = Self(.noOpenSSLExecutable)

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

        static func == (lhs: WalletOrdersError.Backing, rhs: WalletOrdersError.Backing) -> Bool {
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

    /// The `order.json` file is missing.
    public static let noOrderJSONFile = Self(errorType: .noOrderJSONFile)

    /// The `openssl` executable is missing.
    public static let noOpenSSLExecutable = Self(errorType: .noOpenSSLExecutable)

    public static func == (lhs: WalletOrdersError, rhs: WalletOrdersError) -> Bool {
        lhs.backing == rhs.backing
    }
}

extension WalletOrdersError: CustomStringConvertible {
    /// A textual representation of this error.
    public var description: String {
        "WalletOrdersError(errorType: \(self.errorType))"
    }
}
