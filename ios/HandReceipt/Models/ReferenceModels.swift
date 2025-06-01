import Foundation

// MARK: - Reference Database Models

/// Property type model
public struct PropertyType: Codable, Identifiable {
    public let id: Int
    public let name: String
    public let description: String?
}

/// Response wrapper for property types
public struct PropertyTypesResponse: Codable {
    public let types: [PropertyType]
}

// MARK: - Bulk Operation Models

/// Request body for bulk NSN lookup
public struct BulkNSNRequest: Codable {
    public let nsns: [String]
}

/// Response for bulk NSN lookup
public struct BulkNSNResponse: Codable {
    public let results: [NSNDetails]
} 