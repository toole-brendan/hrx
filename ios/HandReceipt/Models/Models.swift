import Foundation

// ... existing Property model ...

// --- Transfer Models --- 

struct UserSummary: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let rank: String?
    let lastName: String?
}

enum TransferStatus: String, Codable, CaseIterable {
    case PENDING
    case APPROVED
    case REJECTED
    case CANCELLED
    // Add an unknown case for future-proofing or unexpected values
    case UNKNOWN
}

// Response wrapper for the transfers endpoint
struct TransfersResponse: Codable {
    let transfers: [Transfer]
}

struct Transfer: Codable, Identifiable, Hashable {
    let id: Int
    let propertyId: Int
    let propertySerialNumber: String // Included for display
    let propertyName: String? // Included for display
    let fromUserId: Int
    let toUserId: Int
    let status: TransferStatus
    let requestTimestamp: Date
    let approvalTimestamp: Date?
    let fromUser: UserSummary? // Optionally populated
    let toUser: UserSummary? // Optionally populated
    let notes: String? // Added notes property
    
    // Add memberwise initializer for direct creation (e.g., in mocks)
    init(id: Int, propertyId: Int, propertySerialNumber: String, propertyName: String?, fromUserId: Int, toUserId: Int, status: TransferStatus, requestTimestamp: Date, approvalTimestamp: Date?, fromUser: UserSummary?, toUser: UserSummary?, notes: String?) {
        self.id = id
        self.propertyId = propertyId
        self.propertySerialNumber = propertySerialNumber
        self.propertyName = propertyName
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.status = status
        self.requestTimestamp = requestTimestamp
        self.approvalTimestamp = approvalTimestamp
        self.fromUser = fromUser
        self.toUser = toUser
        self.notes = notes // Initialize notes
    }
    
    // Custom initializer if backend status string needs mapping
    // Or handle in JSONDecoder configuration
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        propertyId = try container.decode(Int.self, forKey: .propertyId)
        propertySerialNumber = try container.decode(String.self, forKey: .propertySerialNumber)
        propertyName = try container.decodeIfPresent(String.self, forKey: .propertyName)
        fromUserId = try container.decode(Int.self, forKey: .fromUserId)
        toUserId = try container.decode(Int.self, forKey: .toUserId)
        // Decode status safely, defaulting to UNKNOWN
        status = (try? container.decode(TransferStatus.self, forKey: .status)) ?? .UNKNOWN
        requestTimestamp = try container.decode(Date.self, forKey: .requestTimestamp)
        approvalTimestamp = try container.decodeIfPresent(Date.self, forKey: .approvalTimestamp)
        fromUser = try container.decodeIfPresent(UserSummary.self, forKey: .fromUser)
        toUser = try container.decodeIfPresent(UserSummary.self, forKey: .toUser)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) // Decode notes
    }
    
    // Add CodingKeys if property names differ from JSON keys (optional here if they match)
     private enum CodingKeys: String, CodingKey {
         case id, propertyId, propertySerialNumber, propertyName, fromUserId, toUserId, status, requestTimestamp, approvalTimestamp, fromUser, toUser, notes // Added notes key
     }
}

// Model for initiating a transfer request
struct TransferRequest: Codable {
    let propertyId: Int
    let targetUserId: Int
}

// Model for approving/rejecting a transfer (if needed)
// struct TransferActionRequest: Codable {
//    let decision: String // e.g., "APPROVE"
// } 