import Foundation

// Represents an item from the reference database (models endpoint)
public struct ReferenceProperty: Identifiable, Decodable {
    public let id: Int
    public let name: String
    public let nsn: String
    public let description: String?
    public let manufacturer: String?
    public let category: String?
    public let unitOfIssue: String?
    public let unitPrice: Double?
    public let imageUrl: String?
    public let specifications: [String: String]?
    
    // Add custom decoder if API field names differ
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case nsn
        case description
        case manufacturer
        case category
        case unitOfIssue = "unit_of_issue"
        case unitPrice = "unit_price"
        case imageUrl = "image_url"
        case specifications
    }

    // Provide a default empty item for previews or placeholders
    static let example = ReferenceProperty(
        id: 0,
        name: "Example Item",
        nsn: "1234-00-123-4567",
        description: "This is a sample description for the example item.",
        manufacturer: "Example Corp",
        category: "Equipment",
        unitOfIssue: nil,
        unitPrice: nil,
        imageUrl: nil,
        specifications: nil
    )
}

// Extension to provide computed properties
extension ReferenceProperty {
    public var formattedNSN: String {
        // Format NSN as XXXX-XX-XXX-XXXX
        let digits = nsn.replacingOccurrences(of: "-", with: "")
        guard digits.count == 13 else { return nsn }
        
        let part1 = String(digits.prefix(4))
        let part2 = String(digits.dropFirst(4).prefix(2))
        let part3 = String(digits.dropFirst(6).prefix(3))
        let part4 = String(digits.dropFirst(9))
        
        return "\(part1)-\(part2)-\(part3)-\(part4)"
    }
}

// Wrapper for API response that contains array of reference items
public struct ReferencePropertysResponse: Decodable {
    public let models: [ReferenceProperty]
} 