import Foundation
import Orders

extension OrderJSON.SchemaVersion: Decodable {}
extension OrderJSON.OrderType: Decodable {}
extension OrderJSON.OrderStatus: Decodable {}

struct TestOrder: OrderJSON.Properties, Decodable {
    let schemaVersion = OrderJSON.SchemaVersion.v1
    let orderTypeIdentifier = "order.com.example.swift-wallet"
    let orderIdentifier = UUID().uuidString
    let orderType = OrderJSON.OrderType.ecommerce
    let orderNumber = "HM090772020864"
    let createdAt = Date.now.ISO8601Format()
    let updatedAt = Date.now.ISO8601Format()
    let status = OrderJSON.OrderStatus.open
    let merchant = MerchantData()
    let orderManagementURL = "https://www.example.com/"
    let authenticationToken = UUID().uuidString

    private let webServiceURL = "https://www.example.com/api/orders/"

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case orderTypeIdentifier, orderIdentifier, orderType, orderNumber
        case createdAt, updatedAt
        case status, merchant
        case orderManagementURL, authenticationToken, webServiceURL
    }

    struct MerchantData: OrderJSON.Merchant, Decodable {
        let merchantIdentifier = "com.example.pet-store"
        let displayName = "Pet Store"
        let url = "https://www.example.com/"
        let logo = "pet_store_logo.png"

        enum CodingKeys: String, CodingKey {
            case merchantIdentifier, displayName, url, logo
        }
    }
}
