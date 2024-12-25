import Foundation
import Orders

struct TestOrder: OrderJSON.Properties {
    var schemaVersion = OrderJSON.SchemaVersion.v1
    var orderTypeIdentifier = "order.com.example.swift-wallet"
    var orderIdentifier = UUID().uuidString
    var orderType = OrderJSON.OrderType.ecommerce
    var orderNumber = "HM090772020864"
    var createdAt = Date.now.ISO8601Format()
    var updatedAt = Date.now.ISO8601Format()
    var status = OrderJSON.OrderStatus.open
    var merchant = MerchantData()
    var orderManagementURL = "https://www.example.com/"
    var authenticationToken = UUID().uuidString
    var webServiceURL = "https://www.example.com/api/orders/"

    struct MerchantData: OrderJSON.Merchant {
        var merchantIdentifier = "com.example.pet-store"
        var displayName = "Pet Store"
        var url = "https://www.example.com/"
        var logo = "pet_store_logo.png"
    }
}
