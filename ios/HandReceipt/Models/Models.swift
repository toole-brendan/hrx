import Foundation

// ... existing Property model ...

// --- Transfer Models --- 

public struct UserSummary: Codable, Identifiable, Hashable {
    public let id: Int
    public let username: String
    public let rank: String?
    public let lastName: String?
    public let firstName: String?
    public let unit: String?
    
    public init(id: Int, username: String, rank: String? = nil, lastName: String? = nil, firstName: String? = nil, unit: String? = nil) {
        self.id = id
        self.username = username
        self.rank = rank
        self.lastName = lastName
        self.firstName = firstName
        self.unit = unit
    }
    
    // Computed property for full name compatibility with User
    public var name: String {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        } else if let firstName = firstName {
            return firstName
        } else if let lastName = lastName {
            return lastName
        } else {
            return username
        }
    }
}

public enum TransferStatus: String, Codable, CaseIterable {
    case pending
    case accepted  // backend uses 'accepted' not 'completed'
    case rejected
    case cancelled
    case unknown
}

// Response wrapper for the transfers endpoint
public struct TransfersResponse: Codable {
    public let transfers: [Transfer]
    
    public init(transfers: [Transfer]) {
        self.transfers = transfers
    }
}

public struct Transfer: Codable, Identifiable, Hashable {
    public let id: Int
    public let propertyId: Int
    public let propertySerialNumber: String? // Made OPTIONAL - backend doesn't include this
    public let propertyName: String? // Made OPTIONAL - backend doesn't include this
    public let fromUserId: Int
    public let toUserId: Int
    public let status: String // Changed to String to handle lowercase status from API
    public let requestDate: Date // Changed from requestTimestamp
    public let resolvedDate: Date? // Changed from approvalTimestamp
    public let notes: String? // Added notes property
    public let createdAt: Date?
    public let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, propertyId, propertySerialNumber, propertyName
        case fromUserId, toUserId, status, requestDate, resolvedDate
        case notes, createdAt, updatedAt
    }
    
    // Computed property for status enum
    public var transferStatus: TransferStatus {
        return TransferStatus(rawValue: status.lowercased()) ?? .unknown
    }
}

// MARK: - Transfer Relationships Extension
// Handle user relationships through extensions to avoid circular references

extension Transfer {
    // Static storage for relationship data to avoid infinite size issues
    private static var relationshipStorage: [Int: TransferRelationships] = [:]
    
    private struct TransferRelationships {
        var fromUserData: UserSummary?
        var toUserData: UserSummary?
    }
    
    // Computed properties for accessing relationship data
    public var fromUser: UserSummary? {
        get { Transfer.relationshipStorage[id]?.fromUserData }
        set { 
            if Transfer.relationshipStorage[id] == nil {
                Transfer.relationshipStorage[id] = TransferRelationships()
            }
            Transfer.relationshipStorage[id]?.fromUserData = newValue
        }
    }
    
    public var toUser: UserSummary? {
        get { Transfer.relationshipStorage[id]?.toUserData }
        set { 
            if Transfer.relationshipStorage[id] == nil {
                Transfer.relationshipStorage[id] = TransferRelationships()
            }
            Transfer.relationshipStorage[id]?.toUserData = newValue
        }
    }
    
    // Helper methods for managing relationship data
    public static func clearRelationshipData(for transferId: Int) {
        relationshipStorage.removeValue(forKey: transferId)
    }
    
    public static func clearAllRelationshipData() {
        relationshipStorage.removeAll()
    }
}

// Model for initiating a transfer request
public struct TransferRequest: Codable {
    public let propertyId: Int
    public let targetUserId: Int
    
    public init(propertyId: Int, targetUserId: Int) {
        self.propertyId = propertyId
        self.targetUserId = targetUserId
    }
}

// MARK: - Extensions for Existing Models

// Update Property model if needed to include new fields
extension Property {
    /// Check if property is available for transfer
    public var isAvailableForTransfer: Bool {
        return currentStatus == "AVAILABLE" || currentStatus == "IN_USE"
    }
    
    /// Check if property requires maintenance
    public var requiresMaintenance: Bool {
        return currentStatus == "MAINTENANCE_REQUIRED"
    }
}

// Update Transfer model if needed
extension Transfer {
    /// Check if transfer is pending
    public var isPending: Bool {
        return status.lowercased() == "pending"
    }
    
    /// Check if transfer can be cancelled
    public var canBeCancelled: Bool {
        return status.lowercased() == "pending"
    }
}

// MARK: - View Model Helpers

/// Helper struct for grouping activities by date
public struct ActivityGroup {
    public let date: Date
    public let activities: [Activity]
    
    public var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

/// Helper struct for transfer statistics
public struct TransferStats {
    public let totalTransfers: Int
    public let pendingTransfers: Int
    public let acceptedTransfers: Int  // renamed from completedTransfers
    public let rejectedTransfers: Int
    
    public var acceptanceRate: Double {
        guard totalTransfers > 0 else { return 0 }
        return Double(acceptedTransfers) / Double(totalTransfers - pendingTransfers)
    }
} 