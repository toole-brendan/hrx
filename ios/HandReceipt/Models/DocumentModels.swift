import Foundation

// MARK: - Type Aliases
typealias User = LoginResponse.User

// MARK: - Document Models

public struct Document: Codable, Identifiable {
    public let id: Int
    public let type: String
    public let subtype: String?
    public let title: String
    public let senderUserId: Int
    public let recipientUserId: Int
    public let propertyId: Int?
    public let formData: String
    public let description: String?
    public let attachments: [String]?
    public let status: DocumentStatus
    public let sentAt: Date
    public let readAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(id: Int, type: String, subtype: String?, title: String, senderUserId: Int, recipientUserId: Int, propertyId: Int?, formData: String, description: String?, attachments: [String]?, status: DocumentStatus, sentAt: Date, readAt: Date?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.type = type
        self.subtype = subtype
        self.title = title
        self.senderUserId = senderUserId
        self.recipientUserId = recipientUserId
        self.propertyId = propertyId
        self.formData = formData
        self.description = description
        self.attachments = attachments
        self.status = status
        self.sentAt = sentAt
        self.readAt = readAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
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
    
    // Custom decoding to handle potential backend format issues
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        subtype = try container.decodeIfPresent(String.self, forKey: .subtype)
        title = try container.decode(String.self, forKey: .title)
        senderUserId = try container.decode(Int.self, forKey: .senderUserId)
        recipientUserId = try container.decode(Int.self, forKey: .recipientUserId)
        propertyId = try container.decodeIfPresent(Int.self, forKey: .propertyId)
        formData = try container.decode(String.self, forKey: .formData)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
        // Handle attachments - could be array, string, or null
        if let attachmentsArray = try? container.decodeIfPresent([String].self, forKey: .attachments) {
            attachments = attachmentsArray
        } else if let attachmentsString = try? container.decodeIfPresent(String.self, forKey: .attachments) {
            // If it's a JSON string, try to parse it
            if let data = attachmentsString.data(using: .utf8),
               let parsed = try? JSONDecoder().decode([String].self, from: data) {
                attachments = parsed
            } else if attachmentsString.isEmpty || attachmentsString == "[]" {
                attachments = []
            } else {
                attachments = nil
            }
        } else {
            attachments = nil
        }
        
        status = try container.decode(DocumentStatus.self, forKey: .status)
        sentAt = try container.decode(Date.self, forKey: .sentAt)
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

public enum DocumentStatus: String, Codable, CaseIterable {
    case unread = "unread"
    case read = "read"
    case archived = "archived"
    
    public var displayName: String {
        switch self {
        case .unread: return "Unread"
        case .read: return "Read"
        case .archived: return "Archived"
        }
    }
}

public enum DocumentType: String, Codable, CaseIterable {
    case maintenanceForm = "maintenance_form"
    case transferForm = "transfer_form"
    
    public var displayName: String {
        switch self {
        case .maintenanceForm: return "Maintenance Form"
        case .transferForm: return "Transfer Form"
        }
    }
}

// MARK: - Maintenance Form Models

public struct MaintenanceFormData: Codable {
    public let formType: FormType
    public let equipmentName: String
    public let serialNumber: String
    public let nsn: String
    public let location: String
    public let description: String
    public let faultDescription: String
    public let requestDate: Date
    public let formFields: [String: String] // Simplified to avoid Any type issues
    
    public init(formType: FormType, equipmentName: String, serialNumber: String, nsn: String, location: String, description: String, faultDescription: String, requestDate: Date, formFields: [String: String]) {
        self.formType = formType
        self.equipmentName = equipmentName
        self.serialNumber = serialNumber
        self.nsn = nsn
        self.location = location
        self.description = description
        self.faultDescription = faultDescription
        self.requestDate = requestDate
        self.formFields = formFields
    }
    
    public enum FormType: String, Codable, CaseIterable {
        case da2404 = "DA2404"
        case da5988e = "DA5988E"
        
        public var displayName: String {
            switch self {
            case .da2404: return "DA Form 2404 - Equipment Inspection"
            case .da5988e: return "DA Form 5988-E - Equipment Maintenance"
            }
        }
        
        public var description: String {
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

public struct CreateMaintenanceFormRequest: Codable {
    public let propertyId: Int
    public let recipientUserId: Int
    public let formType: String
    public let description: String
    public let faultDescription: String?
    public let attachments: [String]?
    
    public init(propertyId: Int, recipientUserId: Int, formType: String, description: String, faultDescription: String? = nil, attachments: [String]? = nil) {
        self.propertyId = propertyId
        self.recipientUserId = recipientUserId
        self.formType = formType
        self.description = description
        self.faultDescription = faultDescription
        self.attachments = attachments
    }
    
    enum CodingKeys: String, CodingKey {
        case propertyId
        case recipientUserId
        case formType
        case description
        case faultDescription
        case attachments
    }
}

public struct DocumentsResponse: Codable {
    public let documents: [Document]
    public let count: Int
    public let unreadCount: Int
    
    public init(documents: [Document], count: Int, unreadCount: Int) {
        self.documents = documents
        self.count = count
        self.unreadCount = unreadCount
    }
    
    enum CodingKeys: String, CodingKey {
        case documents
        case count
        case unreadCount = "unread_count"
    }
}

public struct DocumentResponse: Codable {
    public let document: Document
    
    public init(document: Document) {
        self.document = document
    }
}

public struct SendMaintenanceFormResponse: Codable {
    public let document: Document
    public let message: String
    
    public init(document: Document, message: String) {
        self.document = document
        self.message = message
    }
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
    public var formDataDecoded: MaintenanceFormData? {
        guard let data = formData.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MaintenanceFormData.self, from: data)
    }
    
    public var attachmentsArray: [String] {
        return attachments ?? []
    }
    
    public var isUnread: Bool {
        return status == .unread
    }
    
    public var formattedSentDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: sentAt)
    }
    
    public var shortFormattedSentDate: String {
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
    public var icon: String {
        switch self {
        case .da2404: return "doc.text"
        case .da5988e: return "wrench.and.screwdriver"
        }
    }
} 