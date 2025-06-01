import Foundation

// MARK: - Ledger Models

/// Ledger verification result
public struct LedgerVerification: Codable {
    public let isValid: Bool
    public let totalRecords: Int
    public let invalidRecords: [Int]
    public let verificationDate: Date
    
    private enum CodingKeys: String, CodingKey {
        case isValid = "is_valid"
        case totalRecords = "total_records"
        case invalidRecords = "invalid_records"
        case verificationDate = "verification_date"
    }
}

/// Ledger entry model
public struct LedgerEntry: Codable, Identifiable {
    public let id: Int
    public let entityType: String
    public let entityId: Int
    public let action: String
    public let hash: String
    public let previousHash: String?
    public let timestamp: Date
    
    private enum CodingKeys: String, CodingKey {
        case id
        case entityType = "entity_type"
        case entityId = "entity_id"
        case action
        case hash
        case previousHash = "previous_hash"
        case timestamp
    }
}

/// Response wrapper for ledger history
public struct LedgerHistoryResponse: Codable {
    public let entries: [LedgerEntry]
} 