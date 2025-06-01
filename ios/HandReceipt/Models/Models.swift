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
    public let fromUser: UserSummary? // Optionally populated
    public let toUser: UserSummary? // Optionally populated
    public let notes: String? // Added notes property
    public let createdAt: Date?
    public let updatedAt: Date?
    
    // Computed property for status enum
    public var transferStatus: TransferStatus {
        return TransferStatus(rawValue: status) ?? TransferStatus(rawValue: status.uppercased()) ?? .UNKNOWN
    }
    
    // Add memberwise initializer for direct creation (e.g., in mocks)
    public init(id: Int, propertyId: Int, propertySerialNumber: String?, propertyName: String?, fromUserId: Int, toUserId: Int, status: String, requestDate: Date, resolvedDate: Date?, fromUser: UserSummary?, toUser: UserSummary?, notes: String?, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.propertyId = propertyId
        self.propertySerialNumber = propertySerialNumber
        self.propertyName = propertyName
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.status = status
        self.requestDate = requestDate
        self.resolvedDate = resolvedDate
        self.fromUser = fromUser
        self.toUser = toUser
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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

// Model for transfer offers
public struct TransferOffer: Codable, Identifiable {
    public let id: Int
    public let property: Property?
    public let offeror: UserSummary?
    public let offeredTo: UserSummary?
    public let notes: String?
    public let expiresAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?
    
    public init(id: Int, property: Property?, offeror: UserSummary?, offeredTo: UserSummary?, notes: String?, expiresAt: Date?, createdAt: Date?, updatedAt: Date?) {
        self.id = id
        self.property = property
        self.offeror = offeror
        self.offeredTo = offeredTo
        self.notes = notes
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 