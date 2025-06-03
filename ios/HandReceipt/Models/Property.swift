import Foundation

// Represents the detailed information for a specific property item,
// likely fetched by serial number or ID.
// Adjust properties based on your actual backend API response for the
// /api/property/serial/:serialNumber endpoint.
public struct Property: Identifiable, Codable {
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
    
    // Component association fields
    public let isAttachable: Bool?
    public let attachmentPoints: [String]?
    public let compatibleWith: [String]?

    enum CodingKeys: String, CodingKey {
        case id, serialNumber, nsn, lin, name, description, manufacturer, imageUrl
        case status, currentStatus, assignedToUserId, location, lastInventoryDate
        case acquisitionDate, notes, maintenanceDueDate, isSensitiveItem
        case propertyModelId, lastVerifiedAt, lastMaintenanceAt, createdAt, updatedAt
        case sourceType, importMetadata, verified, verifiedAt
        case isAttachable, attachmentPoints, compatibleWith
    }

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
    
    // Component-related computed properties
    var canHaveComponents: Bool {
        return isAttachable == true && !(attachmentPoints?.isEmpty ?? true)
    }
    
    func isCompatibleWith(_ parent: Property) -> Bool {
        guard let compatibleWith = compatibleWith else { return true }
        
        return compatibleWith.contains { compatible in
            parent.name.lowercased().contains(compatible.lowercased()) ||
            parent.serialNumber.lowercased().contains(compatible.lowercased())
        }
    }

    // Duplicate CodingKeys removed to avoid compiler confusion

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
        verifiedAt: Date(),
        isAttachable: true,
        attachmentPoints: ["rail_top", "rail_side", "barrel", "grip", "stock"],
        compatibleWith: nil
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

// MARK: - PropertyComponent Model

// Represents an attachment relationship between properties
public struct PropertyComponent: Identifiable, Codable {
    public let id: Int
    public let parentPropertyId: Int
    public let componentPropertyId: Int
    public let attachedAt: Date
    public let attachedByUserId: Int
    public let notes: String?
    public let attachmentType: String
    public let position: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, parentPropertyId, componentPropertyId, attachedAt, attachedByUserId
        case notes, attachmentType, position, createdAt, updatedAt
    }
    
    // Example for previews
    static let example = PropertyComponent(
        id: 1,
        parentPropertyId: 999,
        componentPropertyId: 1001,
        attachedAt: Date(),
        attachedByUserId: 101,
        notes: "Attached for training exercise",
        attachmentType: "field",
        position: "rail_top",
        createdAt: Date(),
        updatedAt: Date()
    )
}

// MARK: - Property Relationships Extension
// Handle component relationships through extensions to avoid circular references

extension Property {
    // Static storage for relationship data to avoid infinite size issues
    private static var relationshipStorage: [Int: PropertyRelationships] = [:]
    
    private struct PropertyRelationships {
        var attachedComponentData: [ComponentSummary] = []
        var attachedToData: ComponentSummary?
    }
    
    // Simplified component summary to avoid circular references
    public struct ComponentSummary {
        public let id: Int
        public let parentPropertyId: Int
        public let componentPropertyId: Int
        public let attachmentType: String
        public let position: String?
        public let notes: String?
        public let attachedAt: Date
        
        // Component property summary
        public let componentName: String?
        public let componentSerialNumber: String?
        public let componentNSN: String?
    }
    
    // Computed properties for accessing relationship data
    public var attachedComponents: [ComponentSummary] {
        get { Property.relationshipStorage[id]?.attachedComponentData ?? [] }
        set { 
            if Property.relationshipStorage[id] == nil {
                Property.relationshipStorage[id] = PropertyRelationships()
            }
            Property.relationshipStorage[id]?.attachedComponentData = newValue
        }
    }
    
    public var attachedTo: ComponentSummary? {
        get { Property.relationshipStorage[id]?.attachedToData }
        set { 
            if Property.relationshipStorage[id] == nil {
                Property.relationshipStorage[id] = PropertyRelationships()
            }
            Property.relationshipStorage[id]?.attachedToData = newValue
        }
    }
    
    // Computed properties that were removed from the main struct
    var isComponent: Bool {
        return attachedTo != nil
    }
    
    var availablePositions: [String] {
        guard canHaveComponents else { return [] }
        
        let occupiedPositions = Set(attachedComponents.compactMap { $0.position })
        return attachmentPoints?.filter { !occupiedPositions.contains($0) } ?? []
    }
    
    // Helper methods for managing relationship data
    public static func clearRelationshipData(for propertyId: Int) {
        relationshipStorage.removeValue(forKey: propertyId)
    }
    
    public static func clearAllRelationshipData() {
        relationshipStorage.removeAll()
    }
} 