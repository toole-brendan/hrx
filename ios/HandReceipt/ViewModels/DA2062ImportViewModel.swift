//ios/HandReceipt/ViewModels/DA2062ImportViewModel.swift

import Foundation
import SwiftUI
import Combine
import UIKit

// MARK: - Enhanced ViewModel with Azure OCR and Batch Import

@MainActor
class DA2062ImportViewModel: ObservableObject {
    @Published var progress = ImportProgress(totalItems: 0)
    @Published var isImporting = false
    @Published var showingSummary = false
    @Published var useAzureOCR = true // Preference for Azure vs local OCR
    @Published var partialSuccessInfo: PartialSuccessInfo?
    
    private let apiService: APIServiceProtocol
    private let nsnService: NSNService
    private let localOCRService = DA2062OCRService()
    private var cancellables = Set<AnyCancellable>()
    private var currentImportTask: Task<Void, Never>?
    
    init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
        self.nsnService = NSNService(apiService: apiService)
    }
    
    // MARK: - Main Processing Method with Enhanced Error Handling
    
    @MainActor
    func processDA2062WithProgress(image: UIImage) async {
        // Cancel any existing import
        currentImportTask?.cancel()
        
        // Initialize progress
        progress = ImportProgress(totalItems: 0)
        partialSuccessInfo = nil
        isImporting = true
        
        currentImportTask = Task {
            if useAzureOCR {
                do {
                    try await processWithAzureOCREnhanced(image: image)
                } catch {
                    if !Task.isCancelled {
                        handleImportError(error)
                    }
                }
            } else {
                do {
                    try await processWithLocalOCREnhanced(image: image)
                } catch {
                    if !Task.isCancelled {
                        handleImportError(error)
                    }
                }
            }
        }
    }
    
    // MARK: - Process Confirmed Items (from Review Sheet)
    
    @MainActor
    func processConfirmedItems(_ editableItems: [EditableDA2062Item]) async {
        // Cancel any existing import
        currentImportTask?.cancel()
        
        // Initialize progress
        progress = ImportProgress(totalItems: editableItems.count)
        partialSuccessInfo = nil
        isImporting = true
        
        currentImportTask = Task {
            do {
                updateProgress(phase: .creating, currentItem: "Preparing confirmed items for import...")
                
                // Convert editable items to batch format
                let batchItems = convertEditableItemsToBatch(editableItems)
                
                // Import using batch API
                try await performBatchImportWithErrorHandling(
                    batchItems: batchItems,
                    source: "reviewed_items_ios",
                    sourceReference: "DA2062-Reviewed-\(Int(Date().timeIntervalSince1970))"
                )
                
            } catch {
                if !Task.isCancelled {
                    handleImportError(error)
                }
            }
        }
    }
    
    // MARK: - Convert Editable Items to Batch Format
    
    private func convertEditableItemsToBatch(_ editableItems: [EditableDA2062Item]) -> [DA2062BatchItem] {
        return editableItems.filter { $0.isSelected && $0.isValid }.map { item in
            DA2062BatchItem(
                name: item.description,
                description: buildEnhancedDescription(for: item),
                serialNumber: item.serialNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                nsn: item.nsn.isEmpty ? nil : item.nsn,
                quantity: Int(item.quantity) ?? 1,
                unit: item.unit ?? "EA",
                category: categorizeItem(item.description),
                importMetadata: BatchImportMetadata(
                    confidence: item.confidence,
                    requiresVerification: item.needsVerification,
                    verificationReasons: getVerificationReasonsForEditableItem(item),
                    sourceDocumentUrl: nil,
                    originalQuantity: (Int(item.quantity) ?? 1) > 1 ? Int(item.quantity) : nil,
                    quantityIndex: nil
                )
            )
        }
    }
    
    private func buildEnhancedDescription(for item: EditableDA2062Item) -> String {
        var parts: [String] = []
        
        if !item.nsn.isEmpty {
            parts.append("NSN: \(item.nsn)")
        }
        
        if !item.serialNumber.isEmpty && item.hasExplicitSerial {
            parts.append("S/N: \(item.serialNumber)")
        }
        
        parts.append("Imported from DA-2062")
        parts.append("Import Date: \(Date().formatted(date: .abbreviated, time: .omitted))")
        
        return parts.joined(separator: " | ")
    }
    
    private func categorizeItem(_ description: String) -> String {
        let desc = description.uppercased()
        
        if desc.contains("WEAPON") || desc.contains("RIFLE") || desc.contains("PISTOL") || desc.contains("CARBINE") {
            return "Weapons"
        } else if desc.contains("OPTIC") || desc.contains("SIGHT") || desc.contains("SCOPE") {
            return "Optics"
        } else if desc.contains("RADIO") || desc.contains("SINCGARS") || desc.contains("ASIP") {
            return "Communications"
        } else if desc.contains("VEST") || desc.contains("IOTV") || desc.contains("PLATE") {
            return "Body Armor"
        } else if desc.contains("HELMET") || desc.contains("ACH") {
            return "Protective Gear"
        } else if desc.contains("NVGS") || desc.contains("NIGHT VISION") {
            return "Night Vision"
        } else {
            return "Equipment"
        }
    }
    
    private func getVerificationReasonsForEditableItem(_ item: EditableDA2062Item) -> [String] {
        var reasons: [String] = []
        
        if item.confidence < 0.7 {
            reasons.append("Low OCR confidence (\(Int(item.confidence * 100))%)")
        }
        
        if !item.hasExplicitSerial && !item.serialNumber.isEmpty {
            reasons.append("Serial number was auto-generated")
        }
        
        if item.quantityConfidence < 0.8 && Int(item.quantity) ?? 1 > 1 {
            reasons.append("Quantity field had low confidence")
        }
        
        if item.nsn.isEmpty {
            reasons.append("No NSN detected")
        }
        
        return reasons
    }
    
    // MARK: - Enhanced Azure OCR Processing with Fallback
    
    private func processWithAzureOCREnhanced(image: UIImage) async throws {
        updateProgress(phase: .scanning, currentItem: "Uploading to Azure OCR...")
        
        do {
            // Convert image to data
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw ImportError(itemName: "Image", error: "Failed to convert image to data", recoverable: false)
            }
            
            // Upload for Azure OCR processing
            let fileName = "da2062_scan_\(Int(Date().timeIntervalSince1970)).jpg"
            updateProgress(phase: .extracting, currentItem: "Processing with Azure Computer Vision...")
            
            let azureResponse = try await apiService.uploadDA2062Form(pdfData: imageData, fileName: fileName)
            
            // Convert Azure response to batch import format
            updateProgress(phase: .parsing, currentItem: "Converting OCR results...")
            let batchItems = convertAzureResponseToBatch(azureResponse)
            
            progress.totalItems = batchItems.count
            
            // Import using batch API with enhanced error handling
            try await performBatchImportWithErrorHandling(
                batchItems: batchItems,
                source: "azure_ocr_ios",
                sourceReference: azureResponse.formInfo.formNumber
            )
            
        } catch {
            // Check if we should fallback to local OCR
            if useAzureOCR && !Task.isCancelled {
                updateProgress(phase: .extracting, currentItem: "Azure OCR failed, falling back to local processing...")
                await fallbackToLocalOCR(image: image)
            } else {
                handleImportError(error)
            }
        }
    }
    
    // MARK: - Enhanced Local OCR Processing
    
    private func processWithLocalOCREnhanced(image: UIImage) async throws {
        // Phase 1: Scanning
        updateProgress(phase: .scanning, currentItem: "Processing image...")
        
        // Phase 2: Extracting with enhanced Vision processing
        updateProgress(phase: .extracting, currentItem: "Running enhanced local OCR...")
        
        do {
            let extractedForm = try await performEnhancedLocalOCR(on: image)
            
            // Phase 3: Parsing
            updateProgress(phase: .parsing, currentItem: "Identifying items...")
            let parsedItems = parseDA2062TextEnhanced(extractedForm)
            
            // Update total items count
            progress.totalItems = parsedItems.count
            
            // Phase 4: Validating
            updateProgress(phase: .validating, currentItem: "Validating data...")
            let validatedItems = await validateItemsEnhanced(parsedItems)
            
            // Phase 5: Enriching (NSN lookup)
            updateProgress(phase: .enriching, currentItem: "Looking up item details...")
            let enrichedItems = await enrichItems(validatedItems)
            
            // Phase 6: Creating records with enhanced metadata
            updateProgress(phase: .creating, currentItem: "Creating property records with ledger logging...")
            try await createPropertyRecordsEnhanced(enrichedItems)
            
            // Complete
            updateProgress(phase: .complete, currentItem: "Import completed successfully!")
            showingSummary = true
            
        } catch {
            if !Task.isCancelled {
                handleImportError(error)
            }
        }
    }
    
    // MARK: - Fallback to Local OCR
    
    private func fallbackToLocalOCR(image: UIImage) async {
        do {
            updateProgress(phase: .extracting, currentItem: "Processing with local Vision Framework...")
            
            let extractedForm = try await performEnhancedLocalOCR(on: image)
            let parsedItems = parseDA2062TextEnhanced(extractedForm)
            
            progress.totalItems = parsedItems.count
            
            updateProgress(phase: .validating, currentItem: "Validating fallback data...")
            let validatedItems = await validateItemsEnhanced(parsedItems)
            
            updateProgress(phase: .enriching, currentItem: "Enriching fallback items...")
            let enrichedItems = await enrichItems(validatedItems)
            
            updateProgress(phase: .creating, currentItem: "Creating records from fallback processing...")
            try await createPropertyRecordsEnhanced(enrichedItems)
            
            updateProgress(phase: .complete, currentItem: "Fallback import completed!")
            showingSummary = true
            
        } catch {
            if !Task.isCancelled {
                handleImportError(error)
            }
        }
    }
    
    // MARK: - Enhanced Local OCR Method
    
    private func performEnhancedLocalOCR(on image: UIImage) async throws -> DA2062Form {
        return try await withCheckedThrowingContinuation { continuation in
            localOCRService.processImage(image) { result in
                switch result {
                case .success(let form):
                    // Enhance the form with additional processing if needed
                    let enhancedForm = self.enhanceLocalOCRForm(form)
                    continuation.resume(returning: enhancedForm)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func enhanceLocalOCRForm(_ form: DA2062Form) -> DA2062Form {
        // Apply additional processing to improve local OCR results
        let enhancedItems = form.items.map { item in
            DA2062Item(
                lineNumber: item.lineNumber,
                stockNumber: validateAndCleanNSN(item.stockNumber),
                itemDescription: cleanAndEnhanceDescription(item.itemDescription),
                quantity: item.quantity,
                unitOfIssue: item.unitOfIssue,
                serialNumber: validateSerialNumber(item.serialNumber),
                condition: item.condition,
                confidence: item.confidence,
                quantityConfidence: item.quantityConfidence,
                hasExplicitSerial: item.hasExplicitSerial
            )
        }
        
        return DA2062Form(
            unitName: form.unitName,
            dodaac: form.dodaac,
            dateCreated: form.dateCreated,
            items: enhancedItems,
            formNumber: form.formNumber,
            confidence: form.confidence
        )
    }
    
    private func validateAndCleanNSN(_ nsn: String?) -> String? {
        guard let nsn = nsn else { return nil }
        
        // Clean and validate NSN format
        let cleaned = nsn.replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression)
        
        // Check if it matches NSN pattern (4-2-3-4)
        if cleaned.range(of: "^\\d{4}-\\d{2}-\\d{3}-\\d{4}$", options: .regularExpression) != nil {
            return cleaned
        }
        
        return nil
    }
    
    private func cleanAndEnhanceDescription(_ description: String) -> String {
        var cleaned = description
        
        // Remove common OCR artifacts
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fix common military term OCR errors
        let corrections = [
            ("R1FLE", "RIFLE"),
            ("CARBINE", "CARBINE"),
            ("5.56MH", "5.56MM"),
            ("7.62MH", "7.62MM"),
            ("M4AI", "M4A1"),
            ("M16AI", "M16A1")
        ]
        
        for (wrong, right) in corrections {
            cleaned = cleaned.replacingOccurrences(of: wrong, with: right, options: .caseInsensitive)
        }
        
        return cleaned
    }
    
    private func validateSerialNumber(_ serialNumber: String?) -> String? {
        guard let serialNumber = serialNumber, !serialNumber.isEmpty else { return nil }
        
        // Basic serial number validation and cleaning
        let cleaned = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must be at least 4 characters and contain alphanumeric characters
        if cleaned.count >= 4 && cleaned.range(of: "[A-Za-z0-9]", options: .regularExpression) != nil {
            return cleaned.uppercased()
        }
        
        return nil
    }
    
    // MARK: - Enhanced Batch Import with Error Handling
    
    private func performBatchImportWithErrorHandling(
        batchItems: [DA2062BatchItem],
        source: String,
        sourceReference: String?
    ) async throws {
        updateProgress(phase: .creating, currentItem: "Creating property records with ledger logging...")
        
        do {
            let batchResponse = try await apiService.importDA2062Items(
                items: batchItems,
                source: source,
                sourceReference: sourceReference
            )
            
            // Handle different success scenarios
            if batchResponse.createdCount > 0 && batchResponse.failedCount > 0 {
                // Partial success - some items created, some failed
                partialSuccessInfo = PartialSuccessInfo(
                    totalAttempted: batchResponse.totalAttempted,
                    successfulCount: batchResponse.createdCount,
                    failedCount: batchResponse.failedCount,
                    errors: batchResponse.failedItems?.map { failedItem in
                        PartialSuccessError(
                            itemName: failedItem.item.name,
                            serialNumber: failedItem.item.serialNumber ?? "Unknown",
                            error: failedItem.error,
                            reason: failedItem.reason
                        )
                    } ?? []
                )
                updateProgress(phase: .complete, currentItem: "Partial import completed: \(batchResponse.createdCount) of \(batchResponse.totalAttempted) items created")
                
                // Log details for debugging
                debugPrint("✅ Partial success: \(batchResponse.createdCount) items created, \(batchResponse.failedCount) failed")
                if let failedItems = batchResponse.failedItems {
                    for failedItem in failedItems {
                        debugPrint("❌ Failed item: \(failedItem.item.name) - \(failedItem.error)")
                    }
                }
                
            } else if batchResponse.createdCount > 0 {
                // Complete success - all items created
                updateProgress(phase: .complete, currentItem: "Import completed! \(batchResponse.createdCount) items created")
                debugPrint("✅ Complete success: \(batchResponse.createdCount) items created")
                
            } else {
                // Complete failure - no items created
                var errorMessage = "No items were successfully imported"
                if let message = batchResponse.message {
                    errorMessage = message
                } else if let firstError = batchResponse.failedItems?.first {
                    errorMessage = firstError.error
                }
                
                debugPrint("❌ Complete failure: \(errorMessage)")
                throw ImportError(
                    itemName: "Batch Import",
                    error: errorMessage,
                    recoverable: true
                )
            }
            
            progress.processedItems = batchResponse.createdCount
            showingSummary = true
            
        } catch {
            // Handle API errors
            debugPrint("❌ Batch import API error: \(error)")
            throw error
        }
    }
    
    // MARK: - Enhanced Validation
    
    private func validateItemsEnhanced(_ items: [ParsedDA2062Item]) async -> [ValidatedItem] {
        var validatedItems: [ValidatedItem] = []
        
        for (index, item) in items.enumerated() {
            if Task.isCancelled { break }
            
            updateProgress(
                phase: .validating,
                currentItem: item.description,
                processedItems: index
            )
            
            // Enhanced validation logic
            let validationResult = performEnhancedValidation(item)
            
            if !validationResult.isValid {
                for error in validationResult.errors {
                    addError(ImportError(
                        itemName: item.description,
                        error: error,
                        recoverable: true
                    ))
                }
            }
            
            let validated = ValidatedItem(
                parsed: item,
                isValid: validationResult.isValid,
                confidence: item.confidence
            )
            
            validatedItems.append(validated)
            
            // Small delay for UI updates
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        return validatedItems
    }
    
    private func performEnhancedValidation(_ item: ParsedDA2062Item) -> ValidationResult {
        var errors: [String] = []
        var isValid = true
        
        // Check description
        if item.description.isEmpty {
            errors.append("Missing item description")
            isValid = false
        } else if item.description.count < 3 {
            errors.append("Description too short")
        }
        
        // Check NSN format if present
        if let nsn = item.nsn {
            if nsn.range(of: "^\\d{4}-\\d{2}-\\d{3}-\\d{4}$", options: .regularExpression) == nil {
                errors.append("Invalid NSN format (should be XXXX-XX-XXX-XXXX)")
            }
        }
        
        // Check quantity
        if item.quantity <= 0 {
            errors.append("Invalid quantity")
            isValid = false
        } else if item.quantity > 100 {
            errors.append("Unusually high quantity, please verify")
        }
        
        // Check confidence
        if item.confidence < 0.5 {
            errors.append("Low OCR confidence")
        }
        
        return ValidationResult(isValid: isValid, errors: errors)
    }
    
    // MARK: - Enhanced Cancellation Support
    
    @MainActor
    func cancelImport() {
        currentImportTask?.cancel()
        isImporting = false
        updateProgress(phase: .complete, currentItem: "Import cancelled by user")
    }
    
    func toggleOCRMode() {
        useAzureOCR.toggle()
    }
    
    // MARK: - Enhanced Summary Data
    
    var importSummary: (total: Int, successful: Int, failed: Int, hasPartialSuccess: Bool) {
        if let partialInfo = partialSuccessInfo {
            return (partialInfo.totalAttempted, partialInfo.successfulCount, partialInfo.failedCount, true)
        } else {
            let total = progress.totalItems
            let failed = progress.errors.filter { !$0.recoverable }.count
            let successful = total - failed
            return (total, successful, failed, false)
        }
    }
    
    var partialSuccessMessage: String? {
        guard let partialInfo = partialSuccessInfo else { return nil }
        
        return "Successfully imported \(partialInfo.successfulCount) of \(partialInfo.totalAttempted) items. \(partialInfo.failedCount) items failed due to errors."
    }
    
    // MARK: - Azure Response Conversion
    
    private func convertAzureResponseToBatch(_ azureResponse: AzureOCRResponse) -> [DA2062BatchItem] {
        return (azureResponse.items ?? []).compactMap { azureItem in
            // Skip items without valid data
            guard !azureItem.name.isEmpty else { return nil }
            
            // Create BatchImportMetadata from AzureImportMetadata
            let batchMetadata = BatchImportMetadata(from: azureItem.importMetadata)
            
            return DA2062BatchItem(
                name: azureItem.name,
                description: azureItem.description,
                serialNumber: azureItem.serialNumber,
                nsn: azureItem.nsn,
                quantity: azureItem.quantity,
                unit: (azureItem.unit?.isEmpty ?? true) ? "EA" : azureItem.unit,  // Default to EA if empty or nil
                category: (azureItem.category?.isEmpty ?? true) ? "Equipment" : azureItem.category,  // Default category
                importMetadata: batchMetadata
            )
        }
    }
    
    // MARK: - Local OCR Data Parsing
    
    private func parseDA2062TextEnhanced(_ form: DA2062Form) -> [ParsedDA2062Item] {
        return form.items.map { item in
            ParsedDA2062Item(
                lineNumber: item.lineNumber,
                nsn: item.stockNumber,
                lin: extractLINFromDescription(item.itemDescription),
                description: cleanDescription(item.itemDescription),
                quantity: item.quantity,
                unitOfIssue: item.unitOfIssue ?? "EA",
                serialNumber: item.serialNumber,
                confidence: item.confidence,
                hasExplicitSerial: item.hasExplicitSerial
            )
        }
    }
    
    private func extractLINFromDescription(_ description: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\\[LIN: ([A-Z][0-9A-Z]{5})\\]", options: []) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: description.utf16.count)
        
        if let match = regex.firstMatch(in: description, options: [], range: range) {
            let captureRange = match.range(at: 1)
            if captureRange.location != NSNotFound,
               let swiftRange = Range(captureRange, in: description) {
                return String(description[swiftRange])
            }
        }
        return nil
    }
    
    private func cleanDescription(_ description: String) -> String {
        return description.replacingOccurrences(of: "\\[LIN: [A-Z][0-9A-Z]{5}\\] ", with: "", options: .regularExpression)
    }
    
    // MARK: - Enrichment
    
    private func enrichItems(_ items: [ValidatedItem]) async -> [EnrichedItem] {
        var enrichedItems: [EnrichedItem] = []
        
        for (index, item) in items.enumerated() {
            if Task.isCancelled { break }
            
            updateProgress(
                phase: .enriching,
                currentItem: item.parsed.description,
                processedItems: index
            )
            
            var enriched = EnrichedItem(validated: item)
            
            // Try NSN lookup if available
            if let nsn = item.parsed.nsn {
                let lookupResult = await nsnService.lookupNSN(nsn)
                
                switch lookupResult {
                case .found(let nsnDetails):
                    enriched.officialName = nsnDetails.nomenclature
                    enriched.manufacturer = nsnDetails.manufacturer
                    enriched.partNumber = nsnDetails.partNumber
                    debugPrint("✅ NSN lookup successful for \(nsn): \(nsnDetails.nomenclature)")
                    
                case .notFound:
                    // Not an error - just use original data
                    debugPrint("ℹ️ NSN \(nsn) not found in database (this is normal for unlisted items)")
                    
                case .networkError(let error):
                    // Log but don't fail the import
                    debugPrint("⚠️ NSN lookup network error for \(nsn): \(error.localizedDescription)")
                }
            }
            
            enrichedItems.append(enriched)
            
            // Small delay for UI updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        return enrichedItems
    }
    
    // MARK: - Enhanced Property Creation for Local OCR
    
    private func createPropertyRecordsEnhanced(_ items: [EnrichedItem]) async throws {
        var batchItems: [DA2062BatchItem] = []
        
        // Convert enriched items to batch format
        for (index, item) in items.enumerated() {
            if Task.isCancelled { break }
            
            updateProgress(
                phase: .creating,
                currentItem: item.officialName ?? item.validated.parsed.description,
                processedItems: index
            )
            
            let batchItem = DA2062BatchItem(
                name: item.officialName ?? item.validated.parsed.description,
                description: item.validated.parsed.description,
                serialNumber: item.validated.parsed.serialNumber,
                nsn: item.validated.parsed.nsn,
                quantity: item.validated.parsed.quantity,
                unit: item.validated.parsed.unitOfIssue,
                category: "Equipment",
                importMetadata: BatchImportMetadata(
                    confidence: item.validated.confidence,
                    requiresVerification: item.validated.confidence < 0.7 || !item.validated.parsed.hasExplicitSerial,
                    verificationReasons: buildVerificationReasons(item),
                    sourceDocumentUrl: nil,
                    originalQuantity: item.validated.parsed.quantity,
                    quantityIndex: nil
                )
            )
            
            batchItems.append(batchItem)
        }
        
        // Use batch import API for better ledger logging
        try await performBatchImportWithErrorHandling(
            batchItems: batchItems,
            source: "local_ocr_ios",
            sourceReference: "DA2062-Local-\(Int(Date().timeIntervalSince1970))"
        )
    }
    
    private func buildVerificationReasons(_ item: EnrichedItem) -> [String] {
        var reasons: [String] = []
        
        if item.validated.confidence < 0.7 {
            reasons.append("Low OCR confidence")
        }
        
        if !item.validated.parsed.hasExplicitSerial {
            reasons.append("Generated serial number")
        }
        
        if item.validated.parsed.nsn == nil {
            reasons.append("Missing NSN")
        }
        
        if item.validated.parsed.quantity > 1 {
            reasons.append("Multiple quantity item")
        }
        
        return reasons
    }
    
    // MARK: - Progress Updates
    
    private func updateProgress(phase: ImportPhase, currentItem: String, processedItems: Int? = nil) {
        Task { @MainActor in
            self.progress.currentPhase = phase
            self.progress.currentItem = currentItem
            if let processed = processedItems {
                self.progress.processedItems = processed
            }
        }
    }
    
    private func addError(_ error: ImportError) {
        Task { @MainActor in
            self.progress.errors.append(error)
        }
    }
    
    @MainActor
    private func handleImportError(_ error: Error) {
        self.isImporting = false
        self.addError(ImportError(
            itemName: "Import Process",
            error: error.localizedDescription,
            recoverable: false
        ))
    }
    
    // MARK: - User Actions
    
    @MainActor
    func completeImport() {
        isImporting = false
        showingSummary = false
        partialSuccessInfo = nil
        // Navigate back or refresh properties list
    }
}

// MARK: - Supporting Types

struct PartialSuccessInfo {
    let totalAttempted: Int
    let successfulCount: Int
    let failedCount: Int
    let errors: [PartialSuccessError]
}

struct PartialSuccessError {
    let itemName: String
    let serialNumber: String
    let error: String
    let reason: String
}

struct ValidationResult {
    let isValid: Bool
    let errors: [String]
} 