import Foundation

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
    
    // Relationships
    var sender: User?
    var recipient: User?
    var property: Property?
    
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
    let formFields: [String: Any]
    
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formType = try container.decode(FormType.self, forKey: .formType)
        equipmentName = try container.decode(String.self, forKey: .equipmentName)
        serialNumber = try container.decode(String.self, forKey: .serialNumber)
        nsn = try container.decode(String.self, forKey: .nsn)
        location = try container.decode(String.self, forKey: .location)
        description = try container.decode(String.self, forKey: .description)
        faultDescription = try container.decode(String.self, forKey: .faultDescription)
        requestDate = try container.decode(Date.self, forKey: .requestDate)
        
        // Decode formFields as a dictionary of Any values
        if let formFieldsData = try? container.decode([String: String].self, forKey: .formFields) {
            formFields = formFieldsData
        } else {
            formFields = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(formType, forKey: .formType)
        try container.encode(equipmentName, forKey: .equipmentName)
        try container.encode(serialNumber, forKey: .serialNumber)
        try container.encode(nsn, forKey: .nsn)
        try container.encode(location, forKey: .location)
        try container.encode(description, forKey: .description)
        try container.encode(faultDescription, forKey: .faultDescription)
        try container.encode(requestDate, forKey: .requestDate)
        
        // Encode formFields - simplified to just strings for now
        let stringFields = formFields.compactMapValues { $0 as? String }
        try container.encode(stringFields, forKey: .formFields)
    }
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
        if Calendar.current.isToday(sentAt) {
            formatter.timeStyle = .short
            return formatter.string(from: sentAt)
        } else if Calendar.current.isYesterday(sentAt) {
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