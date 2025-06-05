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
    
    // Public initializer for creating Property instances
    public init(
        id: Int,
        serialNumber: String,
        nsn: String? = nil,
        lin: String? = nil,
        name: String,
        description: String? = nil,
        manufacturer: String? = nil,
        imageUrl: String? = nil,
        status: String? = nil,
        currentStatus: String? = nil,
        assignedToUserId: Int? = nil,
        location: String? = nil,
        lastInventoryDate: Date? = nil,
        acquisitionDate: Date? = nil,
        notes: String? = nil,
        maintenanceDueDate: Date? = nil,
        isSensitiveItem: Bool? = nil,
        propertyModelId: Int? = nil,
        lastVerifiedAt: Date? = nil,
        lastMaintenanceAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        sourceType: String? = nil,
        importMetadata: ImportMetadata? = nil,
        verified: Bool = false,
        verifiedAt: Date? = nil,
        isAttachable: Bool? = nil,
        attachmentPoints: [String]? = nil,
        compatibleWith: [String]? = nil
    ) {
        self.id = id
        self.serialNumber = serialNumber
        self.nsn = nsn
        self.lin = lin
        self.name = name
        self.description = description
        self.manufacturer = manufacturer
        self.imageUrl = imageUrl
        self.status = status
        self.currentStatus = currentStatus
        self.assignedToUserId = assignedToUserId
        self.location = location
        self.lastInventoryDate = lastInventoryDate
        self.acquisitionDate = acquisitionDate
        self.notes = notes
        self.maintenanceDueDate = maintenanceDueDate
        self.isSensitiveItem = isSensitiveItem
        self.propertyModelId = propertyModelId
        self.lastVerifiedAt = lastVerifiedAt
        self.lastMaintenanceAt = lastMaintenanceAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceType = sourceType
        self.importMetadata = importMetadata
        self.verified = verified
        self.verifiedAt = verifiedAt
        self.isAttachable = isAttachable
        self.attachmentPoints = attachmentPoints
        self.compatibleWith = compatibleWith
    }
    
    // Custom decoder to handle JSON strings for arrays
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all the simple properties
        id = try container.decode(Int.self, forKey: .id)
        serialNumber = try container.decode(String.self, forKey: .serialNumber)
        nsn = try container.decodeIfPresent(String.self, forKey: .nsn)
        lin = try container.decodeIfPresent(String.self, forKey: .lin)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        currentStatus = try container.decodeIfPresent(String.self, forKey: .currentStatus)
        assignedToUserId = try container.decodeIfPresent(Int.self, forKey: .assignedToUserId)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        lastInventoryDate = try container.decodeIfPresent(Date.self, forKey: .lastInventoryDate)
        acquisitionDate = try container.decodeIfPresent(Date.self, forKey: .acquisitionDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        maintenanceDueDate = try container.decodeIfPresent(Date.self, forKey: .maintenanceDueDate)
        isSensitiveItem = try container.decodeIfPresent(Bool.self, forKey: .isSensitiveItem)
        propertyModelId = try container.decodeIfPresent(Int.self, forKey: .propertyModelId)
        lastVerifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastVerifiedAt)
        lastMaintenanceAt = try container.decodeIfPresent(Date.self, forKey: .lastMaintenanceAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        sourceType = try container.decodeIfPresent(String.self, forKey: .sourceType)
        
        // Custom decoding for importMetadata - handle both object and JSON string
        if let importMetadataString = try container.decodeIfPresent(String.self, forKey: .importMetadata) {
            // Backend sent as JSON string, parse it
            if let data = importMetadataString.data(using: .utf8),
               let parsedMetadata = try? JSONDecoder().decode(ImportMetadata.self, from: data) {
                importMetadata = parsedMetadata
            } else {
                importMetadata = nil
            }
        } else {
            // Try to decode as direct object (fallback)
            importMetadata = try container.decodeIfPresent(ImportMetadata.self, forKey: .importMetadata)
        }
        
        verified = try container.decodeIfPresent(Bool.self, forKey: .verified) ?? false
        verifiedAt = try container.decodeIfPresent(Date.self, forKey: .verifiedAt)
        isAttachable = try container.decodeIfPresent(Bool.self, forKey: .isAttachable)
        
        // Custom decoding for attachmentPoints - handle both array and JSON string
        if let attachmentPointsString = try container.decodeIfPresent(String.self, forKey: .attachmentPoints) {
            // Backend sent as JSON string, parse it
            if let data = attachmentPointsString.data(using: .utf8),
               let parsedArray = try? JSONSerialization.jsonObject(with: data) as? [String] {
                attachmentPoints = parsedArray
            } else {
                attachmentPoints = nil
            }
        } else {
            // Try to decode as direct array (fallback)
            attachmentPoints = try container.decodeIfPresent([String].self, forKey: .attachmentPoints)
        }
        
        // Custom decoding for compatibleWith - handle both array and JSON string
        if let compatibleWithString = try container.decodeIfPresent(String.self, forKey: .compatibleWith) {
            // Backend sent as JSON string, parse it
            if let data = compatibleWithString.data(using: .utf8),
               let parsedArray = try? JSONSerialization.jsonObject(with: data) as? [String] {
                compatibleWith = parsedArray
            } else {
                compatibleWith = nil
            }
        } else {
            // Try to decode as direct array (fallback)
            compatibleWith = try container.decodeIfPresent([String].self, forKey: .compatibleWith)
        }
    }
    
    // Custom encoder to match the decoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(serialNumber, forKey: .serialNumber)
        try container.encodeIfPresent(nsn, forKey: .nsn)
        try container.encodeIfPresent(lin, forKey: .lin)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(manufacturer, forKey: .manufacturer)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(currentStatus, forKey: .currentStatus)
        try container.encodeIfPresent(assignedToUserId, forKey: .assignedToUserId)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(lastInventoryDate, forKey: .lastInventoryDate)
        try container.encodeIfPresent(acquisitionDate, forKey: .acquisitionDate)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(maintenanceDueDate, forKey: .maintenanceDueDate)
        try container.encodeIfPresent(isSensitiveItem, forKey: .isSensitiveItem)
        try container.encodeIfPresent(propertyModelId, forKey: .propertyModelId)
        try container.encodeIfPresent(lastVerifiedAt, forKey: .lastVerifiedAt)
        try container.encodeIfPresent(lastMaintenanceAt, forKey: .lastMaintenanceAt)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(sourceType, forKey: .sourceType)
        
        // Custom encoding for importMetadata - encode as JSON string to match backend expectation
        if let importMetadata = importMetadata {
            if let jsonData = try? JSONEncoder().encode(importMetadata),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                try container.encode(jsonString, forKey: .importMetadata)
            }
        }
        
        try container.encode(verified, forKey: .verified)
        try container.encodeIfPresent(verifiedAt, forKey: .verifiedAt)
        try container.encodeIfPresent(isAttachable, forKey: .isAttachable)
        try container.encodeIfPresent(attachmentPoints, forKey: .attachmentPoints)
        try container.encodeIfPresent(compatibleWith, forKey: .compatibleWith)
    }

    // Add other relevant fields: condition, value, calibration_due_date, etc.

    // Computed properties
    public var needsMaintenance: Bool {
        // Check if maintenance is due based on status or date
        if let dueDate = maintenanceDueDate {
            return dueDate <= Date()
        }
        // Also check status
        return status?.lowercased().contains("maintenance") ?? false || 
               currentStatus?.lowercased().contains("maintenance") ?? false
    }
    
    public var isSensitive: Bool {
        // Check if item is marked as sensitive or based on certain NSN/LIN patterns
        if let sensitive = isSensitiveItem {
            return sensitive
        }
        // Check common sensitive item indicators
        let sensitiveKeywords = ["weapon", "nvg", "optic", "laser", "crypto", "radio", "gps"]
        return sensitiveKeywords.contains { name.lowercased().contains($0) }
    }
    
    // Computed property to maintain compatibility with existing code expecting itemName
    public var itemName: String {
        return name
    }
    
    // Component-related computed properties
    public var canHaveComponents: Bool {
        return isAttachable == true && !(attachmentPoints?.isEmpty ?? true)
    }
    
    public func isCompatibleWith(_ parent: Property) -> Bool {
        guard let compatibleWith = compatibleWith else { return true }
        
        return compatibleWith.contains { compatible in
            parent.name.lowercased().contains(compatible.lowercased()) ||
            parent.serialNumber.lowercased().contains(compatible.lowercased())
        }
    }

    // Duplicate CodingKeys removed to avoid compiler confusion

    // Provide an example for previews or testing
    static var example: Property {
        let jsonString = """
        {
            "id": 999,
            "serialNumber": "SN123456789",
            "nsn": "1005-01-584-1079",
            "lin": "E03045",
            "name": "M4A1 Carbine",
            "description": "Standard issue carbine, 5.56mm.",
            "manufacturer": "Colt",
            "imageUrl": null,
            "status": "Assigned",
            "currentStatus": "active",
            "assignedToUserId": 101,
            "location": "Arms Room - Rack 3",
            "lastInventoryDate": null,
            "acquisitionDate": null,
            "notes": "Slight scratch on handguard.",
            "maintenanceDueDate": null,
            "isSensitiveItem": true,
            "propertyModelId": null,
            "lastVerifiedAt": null,
            "lastMaintenanceAt": null,
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-01T00:00:00Z",
            "sourceType": null,
            "importMetadata": null,
            "verified": true,
            "verifiedAt": "2024-01-01T00:00:00Z",
            "isAttachable": true,
            "attachmentPoints": "[\\"rail_top\\", \\"rail_side\\", \\"barrel\\", \\"grip\\", \\"stock\\"]",
            "compatibleWith": null
        }
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // Use the same date decoding strategy as APIService
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        return try! decoder.decode(Property.self, from: data)
    }
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
    public var isImportedFromDA2062: Bool {
        return sourceType == "da2062_scan"
    }
    
    public var needsVerification: Bool {
        return importMetadata?.requiresVerification ?? false
    }
    
    public var verificationReasons: [String] {
        return importMetadata?.verificationReasons ?? []
    }
    
    public var isGeneratedSerial: Bool {
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
    public var isComponent: Bool {
        return attachedTo != nil
    }
    
    public var availablePositions: [String] {
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