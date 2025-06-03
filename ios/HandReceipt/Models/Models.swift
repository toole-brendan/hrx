import Foundation

// ... existing Property model ...

// --- Transfer Models --- 

public struct UserSummary: Codable, Identifiable, Hashable {
    public let id: Int
    public let username: String
    public let rank: String?
    public let lastName: String?
    
    public init(id: Int, username: String, rank: String? = nil, lastName: String? = nil) {
        self.id = id
        self.username = username
        self.rank = rank
        self.lastName = lastName
    }
}

public enum TransferStatus: String, Codable, CaseIterable {
    case pending
    case completed
    case rejected
    case cancelled
    // Legacy uppercase support
    case PENDING
    case APPROVED
    case REJECTED
    case CANCELLED
    // Add an unknown case for future-proofing or unexpected values
    case UNKNOWN
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
    
    // Relationship fields - excluded from Codable to avoid infinite size
    public let fromUser: UserSummary? // Optionally populated
    public let toUser: UserSummary? // Optionally populated
    
    enum CodingKeys: String, CodingKey {
        case id, propertyId, propertySerialNumber, propertyName
        case fromUserId, toUserId, status, requestDate, resolvedDate
        case notes, createdAt, updatedAt
        // Note: fromUser and toUser are excluded from coding
    }
    
    // Computed property for status enum
    public var transferStatus: TransferStatus {
        return TransferStatus(rawValue: status) ?? TransferStatus(rawValue: status.uppercased()) ?? .UNKNOWN
    }
    
    // Add memberwise initializer for direct creation (e.g., in mocks)
    public init(id: Int, propertyId: Int, propertySerialNumber: String?, propertyName: String?, fromUserId: Int, toUserId: Int, status: String, requestDate: Date, resolvedDate: Date?, notes: String?, createdAt: Date? = nil, updatedAt: Date? = nil, fromUser: UserSummary? = nil, toUser: UserSummary? = nil) {
        self.id = id
        self.propertyId = propertyId
        self.propertySerialNumber = propertySerialNumber
        self.propertyName = propertyName
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.status = status
        self.requestDate = requestDate
        self.resolvedDate = resolvedDate
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.fromUser = fromUser
        self.toUser = toUser
    }
    
    // Remove custom decoder since we're matching the API fields now
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
        return status == "PENDING"
    }
    
    /// Check if transfer can be cancelled
    public var canBeCancelled: Bool {
        return status == "PENDING"
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
    public let completedTransfers: Int
    public let rejectedTransfers: Int
    
    public var acceptanceRate: Double {
        guard totalTransfers > 0 else { return 0 }
        return Double(completedTransfers) / Double(totalTransfers - pendingTransfers)
    }
} 