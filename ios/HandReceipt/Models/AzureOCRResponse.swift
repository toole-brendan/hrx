// AzureOCRResponse.swift
// Azure OCR Response Models for DA 2062 processing

import Foundation

// MARK: - Azure OCR Response Models

struct AzureOCRResponse: Codable {
    let success: Bool
    let formInfo: FormInfo
    let items: [AzureOCRItem]?
    let metadata: AzureOCRMetadata
    let nextSteps: NextSteps
    let totalItems: Int
    
    struct FormInfo: Codable {
        let confidence: Double
        let dodaac: String
        let formNumber: String
        let unitName: String
        
        enum CodingKeys: String, CodingKey {
            case confidence
            case dodaac
            case formNumber = "form_number"
            case unitName = "unit_name"
        }
    }
    
    struct NextSteps: Codable {
        let itemsNeedingReview: Int
        let message: String
        let suggestedAction: String
        let verificationNeeded: Bool
        
        enum CodingKeys: String, CodingKey {
            case itemsNeedingReview = "items_needing_review"
            case message
            case suggestedAction = "suggested_action"
            case verificationNeeded = "verification_needed"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case success
        case formInfo = "form_info"
        case items
        case metadata
        case nextSteps = "next_steps"
        case totalItems = "total_items"
    }
}

struct AzureOCRItem: Codable {
    let name: String
    let description: String
    let serialNumber: String
    let nsn: String
    let quantity: Int
    let unit: String
    let category: String
    let sourceRef: String
    let importMetadata: AzureImportMetadata
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case serialNumber = "serial_number"
        case nsn
        case quantity
        case unit
        case category
        case sourceRef = "source_ref"
        case importMetadata = "import_metadata"
    }
}

struct AzureImportMetadata: Codable {
    let source: String
    let importDate: Date
    let formNumber: String
    let scanConfidence: Double  // Changed from just "confidence"
    let itemConfidence: Double  // Added this field
    let serialSource: String
    let originalQuantity: Int
    let requiresVerification: Bool
    let verificationReasons: [String]
    let sourceDocumentURL: String
    
    // Computed property for backward compatibility
    var confidence: Double {
        return max(scanConfidence, itemConfidence)
    }
    
    enum CodingKeys: String, CodingKey {
        case source
        case importDate = "import_date"
        case formNumber = "form_number"
        case scanConfidence = "scan_confidence"  // Match backend field name
        case itemConfidence = "item_confidence"   // Match backend field name
        case serialSource = "serial_source"
        case originalQuantity = "original_quantity"
        case requiresVerification = "requires_verification"
        case verificationReasons = "verification_reasons"
        case sourceDocumentURL = "source_document_url"
    }
}

struct AzureOCRMetadata: Codable {
    let totalLines: Int
    let processedAt: String
    let sourceImageUrl: String
    let ocrConfidence: Double
    let requiresVerification: Bool
    
    enum CodingKeys: String, CodingKey {
        case totalLines
        case processedAt
        case sourceImageUrl
        case ocrConfidence
        case requiresVerification
    }
}

// MARK: - Updated BatchImportMetadata to match

public struct BatchImportMetadata: Codable {
    let confidence: Double  // Single confidence value for batch import
    let requiresVerification: Bool
    let verificationReasons: [String]
    let sourceDocumentUrl: String?
    let originalQuantity: Int?
    let quantityIndex: Int?
    
    // Add initializer that can work with Azure metadata
    init(from azureMetadata: AzureImportMetadata) {
        self.confidence = azureMetadata.confidence // Uses computed property
        self.requiresVerification = azureMetadata.requiresVerification
        self.verificationReasons = azureMetadata.verificationReasons
        self.sourceDocumentUrl = azureMetadata.sourceDocumentURL
        self.originalQuantity = azureMetadata.originalQuantity
        self.quantityIndex = nil
    }
    
    // Standard initializer
    init(confidence: Double, requiresVerification: Bool, verificationReasons: [String], 
         sourceDocumentUrl: String?, originalQuantity: Int?, quantityIndex: Int?) {
        self.confidence = confidence
        self.requiresVerification = requiresVerification
        self.verificationReasons = verificationReasons
        self.sourceDocumentUrl = sourceDocumentUrl
        self.originalQuantity = originalQuantity
        self.quantityIndex = quantityIndex
    }
    
    enum CodingKeys: String, CodingKey {
        case confidence
        case requiresVerification = "requires_verification"
        case verificationReasons = "verification_reasons"
        case sourceDocumentUrl = "source_document_url"
        case originalQuantity = "original_quantity"
        case quantityIndex = "quantity_index"
    }
} 