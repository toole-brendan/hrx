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

/// Transfer offer model - updated to match backend structure
public struct TransferOffer: Codable, Identifiable {
    public let id: Int
    public let propertyId: Int
    public let offeringUserId: Int
    public let offerStatus: String
    public let notes: String?
    public let expiresAt: Date?
    public let createdAt: Date
    public let acceptedByUserId: Int?
    public let acceptedAt: Date?
    public let property: Property?
    public let offeringUser: LoginResponse.User?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case propertyId
        case offeringUserId
        case offerStatus
        case notes
        case expiresAt
        case createdAt
        case acceptedByUserId
        case acceptedAt
        case property
        case offeringUser
    }
}

// MARK: - TransferOffer Extensions
extension TransferOffer {
    /// Computed property to get the offering user's display name
    public var offeringUserDisplayName: String {
        guard let user = offeringUser else { return "Unknown User" }
        let name = user.name
        let lastName = name.components(separatedBy: " ").last ?? name
        return "\(user.rank) \(lastName)"
    }
    
    /// Check if the offer is still active and not expired
    public var isActive: Bool {
        guard offerStatus.lowercased() == "active" else { return false }
        if let expiresAt = expiresAt {
            return Date() < expiresAt
        }
        return true
    }
    
    /// Get relative expiration string
    public var expirationString: String? {
        guard let expiresAt = expiresAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: expiresAt, relativeTo: Date())
    }
}

/// Request body for creating transfer offer
public struct TransferOfferRequest: Codable {
    public let propertyId: Int
    public let recipientIds: [Int]
    public let notes: String?
    public let expiresInDays: Int?
    
    private enum CodingKeys: String, CodingKey {
        case propertyId
        case recipientIds
        case notes
        case expiresInDays
    }
}

/// Response wrapper for transfer offers
public struct TransferOffersResponse: Codable {
    public let offers: [TransferOffer]
}

/// Empty request body for endpoints that don't require parameters
public struct EmptyRequest: Codable {} 