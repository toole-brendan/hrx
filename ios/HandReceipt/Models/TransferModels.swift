import Foundation

// MARK: - Transfer Models

/// Request body for serial number transfer
public struct SerialTransferRequest: Codable {
    public let serialNumber: String
    public let notes: String?
    
    private enum CodingKeys: String, CodingKey {
        case serialNumber = "serial_number"
        case notes
    }
}

/// Transfer offer model
public struct TransferOffer: Codable, Identifiable {
    public let id: Int
    public let createdBy: Int
    public let propertyIds: [Int]
    public let recipientIds: [Int]
    public let status: String
    public let notes: String?
    public let createdAt: Date
    public let expiresAt: Date?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case createdBy = "created_by"
        case propertyIds = "property_ids"
        case recipientIds = "recipient_ids"
        case status
        case notes
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

/// Request body for creating transfer offer
public struct TransferOfferRequest: Codable {
    public let propertyIds: [Int]
    public let recipientIds: [Int]
    public let notes: String?
    
    private enum CodingKeys: String, CodingKey {
        case propertyIds = "property_ids"
        case recipientIds = "recipient_ids"
        case notes
    }
}

/// Response wrapper for transfer offers
public struct TransferOffersResponse: Codable {
    public let offers: [TransferOffer]
}

/// Empty request body for endpoints that don't require parameters
public struct EmptyRequest: Codable {} 