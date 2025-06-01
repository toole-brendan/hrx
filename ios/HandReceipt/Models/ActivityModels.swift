import Foundation

// MARK: - Activity Models

/// Activity model for audit trail
public struct Activity: Codable, Identifiable {
    public let id: Int
    public let userId: Int
    public let activityType: String
    public let description: String
    public let propertyId: Int?
    public let createdAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case description
        case propertyId = "property_id"
        case createdAt = "created_at"
    }
}

/// Request body for creating activity
public struct CreateActivityInput: Codable {
    public let activityType: String
    public let description: String
    public let propertyId: Int?
    
    private enum CodingKeys: String, CodingKey {
        case activityType = "activity_type"
        case description
        case propertyId = "property_id"
    }
}

/// Response wrapper for activities
public struct ActivitiesResponse: Codable {
    public let activities: [Activity]
} 