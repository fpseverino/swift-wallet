import Foundation
import WalletPasses

struct TestPass: PassJSON.Properties, Decodable {
    var description = "Test Pass"
    var formatVersion = PassJSON.FormatVersion.v1
    var organizationName = "example"
    var passTypeIdentifier = "pass.com.example.swift-wallet"
    var serialNumber = UUID().uuidString
    var teamIdentifier = "K6512ZA2S5"
    var webServiceURL = "https://www.example.com/api/passes/"
    var authenticationToken = UUID().uuidString
    var logoText = "Vapor Community"
    var sharingProhibited = true
    var backgroundColor = "rgb(207, 77, 243)"
    var foregroundColor = "rgb(255, 255, 255)"

    var barcodes = [Barcode(message: "test")]
    struct Barcode: PassJSON.Barcodes, Decodable {
        var format = PassJSON.BarcodeFormat.qr
        var message: String
        var messageEncoding = "iso-8859-1"
    }

    var boardingPass = Boarding(transitType: .air)
    struct Boarding: PassJSON.BoardingPass, Decodable {
        let transitType: PassJSON.TransitType
        let headerFields: [PassField]
        let primaryFields: [PassField]
        let secondaryFields: [PassField]
        let auxiliaryFields: [PassField]
        let backFields: [PassField]

        struct PassField: PassJSON.PassFieldContent, Decodable {
            let key: String
            let label: String
            let value: String
        }

        init(transitType: PassJSON.TransitType) {
            self.headerFields = [.init(key: "header", label: "Header", value: "Header")]
            self.primaryFields = [.init(key: "primary", label: "Primary", value: "Primary")]
            self.secondaryFields = [.init(key: "secondary", label: "Secondary", value: "Secondary")]
            self.auxiliaryFields = [.init(key: "auxiliary", label: "Auxiliary", value: "Auxiliary")]
            self.backFields = [.init(key: "back", label: "Back", value: "Back")]
            self.transitType = transitType
        }
    }
}
