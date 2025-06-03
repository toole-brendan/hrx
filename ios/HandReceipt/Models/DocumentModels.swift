import Foundation

// MARK: - Type Aliases
typealias User = LoginResponse.User

// MARK: - Document Models

struct Document: Codable, Identifiable {
    let id: Int
    let type: String
    let subtype: String?
    let title: String
    let senderUserId: Int
    let recipientUserId: Int
    let propertyId: Int?
    let formData: String
    let description: String?
    let attachments: String?
    let status: DocumentStatus
    let sentAt: Date
    let readAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case subtype
        case title
        case senderUserId
        case recipientUserId
        case propertyId
        case formData
        case description
        case attachments
        case status
        case sentAt
        case readAt
        case createdAt
        case updatedAt
    }
}

enum DocumentStatus: String, Codable, CaseIterable {
    case unread = "unread"
    case read = "read"
    case archived = "archived"
    
    var displayName: String {
        switch self {
        case .unread: return "Unread"
        case .read: return "Read"
        case .archived: return "Archived"
        }
    }
}

enum DocumentType: String, Codable, CaseIterable {
    case maintenanceForm = "maintenance_form"
    case transferForm = "transfer_form"
    
    var displayName: String {
        switch self {
        case .maintenanceForm: return "Maintenance Form"
        case .transferForm: return "Transfer Form"
        }
    }
}

// MARK: - Maintenance Form Models

struct MaintenanceFormData: Codable {
    let formType: FormType
    let equipmentName: String
    let serialNumber: String
    let nsn: String
    let location: String
    let description: String
    let faultDescription: String
    let requestDate: Date
    let formFields: [String: String] // Simplified to avoid Any type issues
    
    enum FormType: String, Codable, CaseIterable {
        case da2404 = "DA2404"
        case da5988e = "DA5988E"
        
        var displayName: String {
            switch self {
            case .da2404: return "DA Form 2404 - Equipment Inspection"
            case .da5988e: return "DA Form 5988-E - Equipment Maintenance"
            }
        }
        
        var description: String {
            switch self {
            case .da2404: return "Equipment Inspection and Maintenance Worksheet"
            case .da5988e: return "Equipment Maintenance Request"
            }
        }
    }
    
    // Custom coding for formFields since it contains Any values
    enum CodingKeys: String, CodingKey {
        case formType = "form_type"
        case equipmentName = "equipment_name"
        case serialNumber = "serial_number"
        case nsn
        case location
        case description
        case faultDescription = "fault_description"
        case requestDate = "request_date"
        case formFields = "form_fields"
    }
    
    // Manual Codable implementation removed since formFields is now [String: String]
}

// MARK: - Request/Response Models

struct CreateMaintenanceFormRequest: Codable {
    let propertyId: Int
    let recipientUserId: Int
    let formType: String
    let description: String
    let faultDescription: String?
    let attachments: [String]?
    
    enum CodingKeys: String, CodingKey {
        case propertyId
        case recipientUserId
        case formType
        case description
        case faultDescription
        case attachments
    }
}

struct DocumentsResponse: Codable {
    let documents: [Document]
    let count: Int
    let unreadCount: Int
    
    enum CodingKeys: String, CodingKey {
        case documents
        case count
        case unreadCount = "unread_count"
    }
}

struct DocumentResponse: Codable {
    let document: Document
}

struct SendMaintenanceFormResponse: Codable {
    let document: Document
    let message: String
}

// MARK: - Document Relationships (Non-Codable)

extension Document {
    // These properties are added as extensions to avoid Codable issues
    // They should be populated by the service layer after decoding
    
    private static var documentRelationships: [Int: DocumentRelationships] = [:]
    
    private struct DocumentRelationships {
        var sender: User?
        var recipient: User?
        var propertyData: PropertySummary?
    }
    
    // Simplified property summary to avoid circular references
    public struct PropertySummary {
        public let id: Int
        public let serialNumber: String
        public let name: String
        public let nsn: String?
        public let status: String?
        public let isSensitiveItem: Bool?
        public let location: String?
    }
    
    var sender: User? {
        get { Document.documentRelationships[id]?.sender }
        set { 
            if Document.documentRelationships[id] == nil {
                Document.documentRelationships[id] = DocumentRelationships()
            }
            Document.documentRelationships[id]?.sender = newValue
        }
    }
    
    var recipient: User? {
        get { Document.documentRelationships[id]?.recipient }
        set { 
            if Document.documentRelationships[id] == nil {
                Document.documentRelationships[id] = DocumentRelationships()
            }
            Document.documentRelationships[id]?.recipient = newValue
        }
    }
    
    var property: PropertySummary? {
        get { Document.documentRelationships[id]?.propertyData }
        set { 
            if Document.documentRelationships[id] == nil {
                Document.documentRelationships[id] = DocumentRelationships()
            }
            Document.documentRelationships[id]?.propertyData = newValue
        }
    }
    
    // Helper methods for managing relationship data
    public static func clearRelationshipData(for documentId: Int) {
        documentRelationships.removeValue(forKey: documentId)
    }
    
    public static func clearAllRelationshipData() {
        documentRelationships.removeAll()
    }
}

// MARK: - Extensions

extension Document {
    var formDataDecoded: MaintenanceFormData? {
        guard let data = formData.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MaintenanceFormData.self, from: data)
    }
    
    var attachmentsArray: [String] {
        guard let attachments = attachments,
              let data = attachments.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return array
    }
    
    var isUnread: Bool {
        return status == .unread
    }
    
    var formattedSentDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: sentAt)
    }
    
    var shortFormattedSentDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(sentAt, inSameDayAs: Date()) {
            formatter.timeStyle = .short
            return formatter.string(from: sentAt)
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
                  calendar.isDate(sentAt, inSameDayAs: yesterday) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: sentAt)
        }
    }
}

extension MaintenanceFormData.FormType {
    var icon: String {
        switch self {
        case .da2404: return "doc.text"
        case .da5988e: return "wrench.and.screwdriver"
        }
    }
} 