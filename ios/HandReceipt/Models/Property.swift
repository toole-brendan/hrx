import Foundation

// Represents the detailed information for a specific property item,
// likely fetched by serial number or ID.
// Adjust properties based on your actual backend API response for the
// /api/property/serial/:serialNumber endpoint.
public struct Property: Identifiable, Decodable {
    public let id: Int // Changed from UUID
    public let serialNumber: String
    public let nsn: String? // National Stock Number - Made OPTIONAL as backend doesn't return it
    public let lin: String? // Line Item Number
    public let name: String // Changed from itemName to match API response
    public let description: String?
    public let manufacturer: String?
    public let imageUrl: String?
    public let status: String? // Made optional
    public let currentStatus: String? // This is what the API returns for status
    public let assignedToUserId: Int? // Or String/UUID depending on user ID type
    public let location: String?
    public let lastInventoryDate: Date? // Requires Date decoding strategy
    public let acquisitionDate: Date?
    public let notes: String?
    public let maintenanceDueDate: Date?
    public let isSensitiveItem: Bool?
    
    // New fields from API
    public let propertyModelId: Int?
    public let lastVerifiedAt: Date?
    public let lastMaintenanceAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?
    
    // Import metadata fields
    public let sourceType: String?
    public let importMetadata: ImportMetadata?
    public var verified: Bool = false
    public var verifiedAt: Date?

    // Add other relevant fields: condition, value, calibration_due_date, etc.

    // Computed properties
    var needsMaintenance: Bool {
        // Check if maintenance is due based on status or date
        if let dueDate = maintenanceDueDate {
            return dueDate <= Date()
        }
        // Also check status
        return status?.lowercased().contains("maintenance") ?? false || 
               currentStatus?.lowercased().contains("maintenance") ?? false
    }
    
    var isSensitive: Bool {
        // Check if item is marked as sensitive or based on certain NSN/LIN patterns
        if let sensitive = isSensitiveItem {
            return sensitive
        }
        // Check common sensitive item indicators
        let sensitiveKeywords = ["weapon", "nvg", "optic", "laser", "crypto", "radio", "gps"]
        return sensitiveKeywords.contains { name.lowercased().contains($0) }
    }
    
    // Computed property to maintain compatibility with existing code expecting itemName
    var itemName: String {
        return name
    }

    // Example CodingKeys if API names differ (e.g., serial_number)
    /*
    enum CodingKeys: String, CodingKey {
        case id
        case serialNumber = "serial_number"
        case nsn
        case lin
        case itemName = "item_name"
        case description
        case manufacturer
        case imageUrl = "image_url"
        case status
        case currentStatus = "current_status"
        case assignedToUserId = "assigned_to_user_id"
        case location
        case lastInventoryDate = "last_inventory_date"
        case acquisitionDate = "acquisition_date"
        case notes
        case maintenanceDueDate = "maintenance_due_date"
        case isSensitiveItem = "is_sensitive_item"
    }
    */

    // Provide an example for previews or testing
    static let example = Property(
        id: 999, // Changed from UUID()
        serialNumber: "SN123456789",
        nsn: "1005-01-584-1079",
        lin: "E03045",
        name: "M4A1 Carbine",
        description: "Standard issue carbine, 5.56mm.",
        manufacturer: "Colt",
        imageUrl: nil,
        status: "Assigned",
        currentStatus: "active",
        assignedToUserId: 101,
        location: "Arms Room - Rack 3",
        lastInventoryDate: Date().addingTimeInterval(-86400 * 30), // 30 days ago
        acquisitionDate: Date().addingTimeInterval(-86400 * 365), // 1 year ago
        notes: "Slight scratch on handguard.",
        maintenanceDueDate: nil,
        isSensitiveItem: true,
        propertyModelId: nil,
        lastVerifiedAt: nil,
        lastMaintenanceAt: nil,
        createdAt: Date(),
        updatedAt: Date(),
        sourceType: nil,
        importMetadata: nil,
        verified: true,
        verifiedAt: Date()
    )
}

// MARK: - Equatable Conformance
extension Property: Equatable {
    public static func == (lhs: Property, rhs: Property) -> Bool {
        return lhs.id == rhs.id &&
               lhs.serialNumber == rhs.serialNumber &&
               lhs.nsn == rhs.nsn &&
               lhs.lin == rhs.lin &&
               lhs.name == rhs.name &&
               lhs.description == rhs.description &&
               lhs.manufacturer == rhs.manufacturer &&
               lhs.imageUrl == rhs.imageUrl &&
               lhs.status == rhs.status &&
               lhs.currentStatus == rhs.currentStatus &&
               lhs.assignedToUserId == rhs.assignedToUserId &&
               lhs.location == rhs.location &&
               lhs.lastInventoryDate == rhs.lastInventoryDate &&
               lhs.acquisitionDate == rhs.acquisitionDate &&
               lhs.notes == rhs.notes &&
               lhs.maintenanceDueDate == rhs.maintenanceDueDate &&
               lhs.isSensitiveItem == rhs.isSensitiveItem &&
               lhs.propertyModelId == rhs.propertyModelId &&
               lhs.lastVerifiedAt == rhs.lastVerifiedAt &&
               lhs.lastMaintenanceAt == rhs.lastMaintenanceAt &&
               lhs.createdAt == rhs.createdAt &&
               lhs.updatedAt == rhs.updatedAt &&
               lhs.sourceType == rhs.sourceType &&
               lhs.verified == rhs.verified &&
               lhs.verifiedAt == rhs.verifiedAt
        // Note: importMetadata comparison excluded as it may need custom comparison
    }
}

// MARK: - Properties List with Import Indicators

// Enhanced Property model to include import metadata
extension Property {
    var isImportedFromDA2062: Bool {
        return sourceType == "da2062_scan"
    }
    
    var needsVerification: Bool {
        return importMetadata?.requiresVerification ?? false
    }
    
    var verificationReasons: [String] {
        return importMetadata?.verificationReasons ?? []
    }
    
    var isGeneratedSerial: Bool {
        return importMetadata?.serialSource == .generated
    }
}

// Wrapper for responses that contain an array of properties
struct PropertyResponse: Decodable {
    let properties: [Property]
    
    // Map properties to items for compatibility
    var items: [Property] {
        return properties
    }
} 