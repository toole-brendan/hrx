import Foundation

// Represents the detailed information for a specific property item,
// likely fetched by serial number or ID.
// Adjust properties based on your actual backend API response for the
// /api/inventory/serial/:serialNumber endpoint.
struct Property: Identifiable, Decodable {
    let id: Int // Changed from UUID
    let serialNumber: String
    let nsn: String // National Stock Number (links to ReferenceItem potentially)
    let lin: String? // Line Item Number
    let itemName: String // Often derived from Reference DB via NSN
    let description: String?
    let manufacturer: String?
    let imageUrl: String?
    let status: String // e.g., "Operational", "Maintenance", "Assigned"
    let currentStatus: String? // Additional status field for operational state
    let assignedToUserId: Int? // Or String/UUID depending on user ID type
    let location: String?
    let lastInventoryDate: Date? // Requires Date decoding strategy
    let acquisitionDate: Date?
    let notes: String?
    let maintenanceDueDate: Date?
    let isSensitiveItem: Bool?

    // Add other relevant fields: condition, value, calibration_due_date, etc.

    // Computed properties
    var needsMaintenance: Bool {
        // Check if maintenance is due based on status or date
        if let dueDate = maintenanceDueDate {
            return dueDate <= Date()
        }
        // Also check status
        return status.lowercased().contains("maintenance") || 
               currentStatus?.lowercased().contains("maintenance") ?? false
    }
    
    var isSensitive: Bool {
        // Check if item is marked as sensitive or based on certain NSN/LIN patterns
        if let sensitive = isSensitiveItem {
            return sensitive
        }
        // Check common sensitive item indicators
        let sensitiveKeywords = ["weapon", "nvg", "optic", "laser", "crypto", "radio", "gps"]
        return sensitiveKeywords.contains { itemName.lowercased().contains($0) }
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
        itemName: "M4A1 Carbine",
        description: "Standard issue carbine, 5.56mm.",
        manufacturer: "Colt",
        imageUrl: nil,
        status: "Assigned",
        currentStatus: "operational",
        assignedToUserId: 101,
        location: "Arms Room - Rack 3",
        lastInventoryDate: Date().addingTimeInterval(-86400 * 30), // 30 days ago
        acquisitionDate: Date().addingTimeInterval(-86400 * 365), // 1 year ago
        notes: "Slight scratch on handguard.",
        maintenanceDueDate: nil,
        isSensitiveItem: true
    )
}

// Wrapper for responses that contain an array of properties
struct PropertyResponse: Decodable {
    let items: [Property]
} 