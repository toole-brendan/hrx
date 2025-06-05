// MARK: - Enhanced Models with Metadata

import Foundation

// Update DA2062Item model to include quantity confidence
struct DA2062Item: Codable {
    let lineNumber: Int
    let stockNumber: String? // NSN
    let itemDescription: String
    let quantity: Int
    let unitOfIssue: String?
    let serialNumber: String?
    let condition: String?
    let confidence: Double // OCR confidence for this item
    let quantityConfidence: Double // Specific confidence for quantity field
    let hasExplicitSerial: Bool // Whether serial was found in text or generated
}

// Property creation request with enhanced metadata
struct DA2062PropertyRequest: Codable {
    let name: String
    let description: String
    let serialNumber: String?
    let nsn: String?
    let quantity: Int
    let unit: String?
    let location: String?
    let category: String
    let da2062Reference: String?
    let importMetadata: ImportMetadata // New field
}

// Import metadata structure
public struct ImportMetadata: Codable {
    let source: String // "da2062_scan"
    let importDate: Date
    let formNumber: String?
    let unitName: String?
    let scanConfidence: Double
    let itemConfidence: Double
    let serialSource: SerialSource
    let originalQuantity: Int?
    let quantityIndex: Int? // If this is item 2 of 3
    let requiresVerification: Bool
    let verificationReasons: [String]
}

public enum SerialSource: String, Codable {
    case explicit = "explicit" // Found in document
    case generated = "generated" // Auto-generated placeholder
    case manual = "manual" // User entered during review
}

// Enhanced EditableDA2062Item for review UI
struct EditableDA2062Item: Identifiable {
    let id = UUID()
    var description: String
    var nsn: String
    var quantity: String
    var serialNumber: String
    var unit: String?
    let confidence: Double
    let quantityConfidence: Double
    var isSelected: Bool = true
    var hasExplicitSerial: Bool
    
    // Validation helpers
    var isValid: Bool {
        !description.isEmpty && Int(quantity) ?? 0 > 0
    }
    
    var needsVerification: Bool {
        confidence < 0.7 || 
        (!hasExplicitSerial && !serialNumber.isEmpty) ||
        (quantityConfidence < 0.8 && Int(quantity) ?? 1 > 1)
    }
    
    // Initialize from DA2062Item
    init(from item: DA2062Item) {
        self.description = item.itemDescription
        self.nsn = item.stockNumber ?? ""
        self.quantity = String(item.quantity)
        self.serialNumber = item.serialNumber ?? ""
        self.unit = item.unitOfIssue
        self.confidence = item.confidence
        self.quantityConfidence = item.quantityConfidence
        self.hasExplicitSerial = item.hasExplicitSerial
    }
    
    // Manual initialization for new items
    init(description: String = "", nsn: String = "", quantity: String = "1", 
         serialNumber: String = "", unit: String? = "EA", confidence: Double = 1.0,
         quantityConfidence: Double = 1.0, hasExplicitSerial: Bool = false) {
        self.description = description
        self.nsn = nsn
        self.quantity = quantity
        self.serialNumber = serialNumber
        self.unit = unit
        self.confidence = confidence
        self.quantityConfidence = quantityConfidence
        self.hasExplicitSerial = hasExplicitSerial
    }
}

// Enhanced DA2062Form with metadata
struct DA2062Form: Identifiable {
    let id = UUID()
    let unitName: String?
    let dodaac: String?
    let dateCreated: Date?
    let items: [DA2062Item]
    let formNumber: String?
    let confidence: Double
    
    init(unitName: String? = nil, dodaac: String? = nil, dateCreated: Date? = nil,
         items: [DA2062Item] = [], formNumber: String? = nil, confidence: Double = 0.0) {
        self.unitName = unitName
        self.dodaac = dodaac
        self.dateCreated = dateCreated
        self.items = items
        self.formNumber = formNumber
        self.confidence = confidence
    }
}

// Represents a recent scan for history
struct DA2062Scan: Identifiable {
    let id = UUID()
    let date: Date
    let pageCount: Int
    let itemCount: Int
    let confidence: Double
    let formNumber: String?
    let requiresVerification: Bool
    
    init(date: Date, pageCount: Int, itemCount: Int, confidence: Double,
         formNumber: String? = nil, requiresVerification: Bool = false) {
        self.date = date
        self.pageCount = pageCount
        self.itemCount = itemCount
        self.confidence = confidence
        self.formNumber = formNumber
        self.requiresVerification = requiresVerification
    }
}

// MARK: - Enhanced Processing Models for Import Pipeline

// Parsed item from OCR with enhanced metadata
struct ParsedDA2062Item {
    let lineNumber: Int
    let nsn: String?
    let lin: String?
    let description: String
    let quantity: Int
    let unitOfIssue: String
    let serialNumber: String?
    let confidence: Double
    let hasExplicitSerial: Bool
}

// Validated item with validation results
struct ValidatedItem {
    let parsed: ParsedDA2062Item
    let isValid: Bool
    let confidence: Double
}

// Enriched item with NSN lookup data
struct EnrichedItem {
    let validated: ValidatedItem
    var officialName: String?
    var manufacturer: String?
    var partNumber: String?
    
    init(validated: ValidatedItem) {
        self.validated = validated
    }
}

// Import progress tracking
struct ImportProgress {
    var currentPhase: ImportPhase = .scanning
    var currentItem: String = ""
    var totalItems: Int = 0
    var processedItems: Int = 0
    var errors: [ImportError] = []
}

// Import phases for progress tracking
enum ImportPhase {
    case scanning
    case extracting
    case parsing
    case validating
    case enriching
    case creating
    case complete
}

// Import error model
struct ImportError {
    let itemName: String
    let error: String
    let recoverable: Bool
} 