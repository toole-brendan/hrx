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

// MARK: - TransferOffer Relationships Extension
// Handle relationships through extensions to avoid circular references

extension TransferOffer {
    // Static storage for relationship data to avoid infinite size issues
    private static var relationshipStorage: [Int: TransferOfferRelationships] = [:]
    
    private struct TransferOfferRelationships {
        var propertyData: PropertySummary?
        var offerorData: UserSummary?
        var offeredToData: UserSummary?
    }
    
    // Simplified data structures to avoid circular references
    public struct PropertySummary {
        public let id: Int
        public let serialNumber: String
        public let name: String
        public let nsn: String?
        public let status: String?
        public let isSensitiveItem: Bool?
    }
    
    public struct UserSummary {
        public let id: Int
        public let firstName: String
        public let lastName: String
        public let rank: String?
        public let unit: String?
        
        public var fullName: String {
            return "\(firstName) \(lastName)"
        }
        
        public var displayName: String {
            if let rank = rank {
                return "\(rank) \(lastName)"
            }
            return fullName
        }
    }
    
    // Computed properties for accessing relationship data
    public var property: PropertySummary? {
        get { TransferOffer.relationshipStorage[id]?.propertyData }
        set { 
            if TransferOffer.relationshipStorage[id] == nil {
                TransferOffer.relationshipStorage[id] = TransferOfferRelationships()
            }
            TransferOffer.relationshipStorage[id]?.propertyData = newValue
        }
    }
    
    public var offeror: UserSummary? {
        get { TransferOffer.relationshipStorage[id]?.offerorData }
        set { 
            if TransferOffer.relationshipStorage[id] == nil {
                TransferOffer.relationshipStorage[id] = TransferOfferRelationships()
            }
            TransferOffer.relationshipStorage[id]?.offerorData = newValue
        }
    }
    
    public var offeredTo: UserSummary? {
        get { TransferOffer.relationshipStorage[id]?.offeredToData }
        set { 
            if TransferOffer.relationshipStorage[id] == nil {
                TransferOffer.relationshipStorage[id] = TransferOfferRelationships()
            }
            TransferOffer.relationshipStorage[id]?.offeredToData = newValue
        }
    }
    
    // Helper method to clear relationship data when no longer needed
    public static func clearRelationshipData(for offerId: Int) {
        relationshipStorage.removeValue(forKey: offerId)
    }
    
    // Helper method to clear all relationship data
    public static func clearAllRelationshipData() {
        relationshipStorage.removeAll()
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