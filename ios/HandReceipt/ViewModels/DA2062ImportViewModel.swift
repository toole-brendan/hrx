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
    
    private let apiService: APIServiceProtocol
    private let nsnService: NSNService
    private let localOCRService = DA2062OCRService()
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
        self.nsnService = NSNService(apiService: apiService)
    }
    
    // MARK: - Main Processing Method with Azure OCR Option
    
    func processDA2062WithProgress(image: UIImage) async {
        // Initialize progress
        progress = ImportProgress(totalItems: 0)
        isImporting = true
        
        do {
            if useAzureOCR {
                await processWithAzureOCR(image: image)
            } else {
                await processWithLocalOCR(image: image)
            }
        } catch {
            handleImportError(error)
        }
    }
    
    // MARK: - Azure OCR Processing Path
    
    private func processWithAzureOCR(image: UIImage) async {
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
            
            // Import using batch API with ledger logging
            updateProgress(phase: .creating, currentItem: "Creating property records with ledger logging...")
            let batchResponse = try await apiService.importDA2062Items(
                items: batchItems, 
                source: "azure_ocr_ios", 
                sourceReference: azureResponse.formInfo.formNumber
            )
            
            // Update progress with results
            updateProgress(phase: .complete, currentItem: "Import completed! \(batchResponse.createdCount) items created")
            progress.processedItems = batchResponse.createdCount
            
            showingSummary = true
            
        } catch {
            handleImportError(error)
        }
    }
    
    // MARK: - Local OCR Processing Path (Fallback)
    
    private func processWithLocalOCR(image: UIImage) async {
        // Phase 1: Scanning
        updateProgress(phase: .scanning, currentItem: "Processing image...")
        
        // Phase 2: Extracting
        updateProgress(phase: .extracting, currentItem: "Running local OCR...")
        
        do {
            let extractedText = try await performLocalOCR(on: image)
            
            // Phase 3: Parsing
            updateProgress(phase: .parsing, currentItem: "Identifying items...")
            let parsedItems = parseDA2062Text(extractedText)
            
            // Update total items count
            progress.totalItems = parsedItems.count
            
            // Phase 4: Validating
            updateProgress(phase: .validating, currentItem: "Validating data...")
            let validatedItems = await validateItems(parsedItems)
            
            // Phase 5: Enriching (NSN lookup)
            updateProgress(phase: .enriching, currentItem: "Looking up item details...")
            let enrichedItems = await enrichItems(validatedItems)
            
            // Phase 6: Creating records with enhanced metadata
            updateProgress(phase: .creating, currentItem: "Creating property records with ledger logging...")
            await createPropertyRecordsEnhanced(enrichedItems)
            
            // Complete
            updateProgress(phase: .complete, currentItem: "Import completed successfully!")
            showingSummary = true
            
        } catch {
            handleImportError(error)
        }
    }
    
    // MARK: - Local OCR Method
    
    private func performLocalOCR(on image: UIImage) async throws -> DA2062Form {
        return try await withCheckedThrowingContinuation { continuation in
            localOCRService.processImage(image) { result in
                switch result {
                case .success(let form):
                    continuation.resume(returning: form)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Azure Response Conversion
    
    private func convertAzureResponseToBatch(_ azureResponse: AzureOCRResponse) -> [DA2062BatchItem] {
        return azureResponse.items.map { azureItem in
            DA2062BatchItem(
                name: azureItem.name,
                description: azureItem.description,
                serialNumber: azureItem.serialNumber,
                nsn: azureItem.nsn,
                quantity: azureItem.quantity,
                unit: azureItem.unit,
                category: "Equipment", // Default category
                importMetadata: BatchImportMetadata(
                    confidence: azureItem.importMetadata.confidence,
                    requiresVerification: azureItem.importMetadata.requiresVerification,
                    verificationReasons: azureItem.importMetadata.verificationReasons,
                    sourceDocumentUrl: azureItem.importMetadata.sourceDocumentUrl,
                    originalQuantity: azureItem.quantity,
                    quantityIndex: nil
                )
            )
        }
    }
    
    // MARK: - Local OCR Data Parsing
    
    private func parseDA2062Text(_ form: DA2062Form) -> [ParsedDA2062Item] {
        return form.items.map { item in
            ParsedDA2062Item(
                lineNumber: item.lineNumber,
                nsn: item.stockNumber,
                lin: extractLINFromDescription(item.itemDescription),
                description: cleanDescription(item.itemDescription),
                quantity: item.quantity,
                unitOfIssue: item.unitOfIssue ?? "EA",
                serialNumber: item.serialNumber,
                confidence: item.confidence
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
    
    // MARK: - Validation
    
    private func validateItems(_ items: [ParsedDA2062Item]) async -> [ValidatedItem] {
        var validatedItems: [ValidatedItem] = []
        
        for (index, item) in items.enumerated() {
            updateProgress(
                phase: .validating,
                currentItem: item.description,
                processedItems: index
            )
            
            // Validate NSN format
            let nsnValid = item.nsn?.range(of: "^\\d{4}-\\d{2}-\\d{3}-\\d{4}$", options: .regularExpression) != nil
            
            // Validate required fields
            let hasRequiredFields = !item.description.isEmpty
            
            if !nsnValid && item.nsn != nil {
                addError(ImportError(
                    itemName: item.description,
                    error: "Invalid NSN format",
                    recoverable: true
                ))
            }
            
            let validated = ValidatedItem(
                parsed: item,
                isValid: hasRequiredFields,
                confidence: item.confidence
            )
            
            validatedItems.append(validated)
            
            // Small delay for UI updates
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        return validatedItems
    }
    
    // MARK: - Enrichment
    
    private func enrichItems(_ items: [ValidatedItem]) async -> [EnrichedItem] {
        var enrichedItems: [EnrichedItem] = []
        
        for (index, item) in items.enumerated() {
            updateProgress(
                phase: .enriching,
                currentItem: item.parsed.description,
                processedItems: index
            )
            
            var enriched = EnrichedItem(validated: item)
            
            // Try NSN lookup if available
            if let nsn = item.parsed.nsn {
                do {
                    let nsnDetails = try await nsnService.lookupNSN(nsn)
                    enriched.officialName = nsnDetails.nomenclature
                    enriched.manufacturer = nsnDetails.manufacturer
                    enriched.partNumber = nsnDetails.partNumber
                } catch {
                    print("NSN lookup failed for \(nsn): \(error)")
                }
            }
            
            enrichedItems.append(enriched)
            
            // Small delay for UI updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        return enrichedItems
    }
    
    // MARK: - Enhanced Property Creation for Local OCR
    
    private func createPropertyRecordsEnhanced(_ items: [EnrichedItem]) async {
        var successCount = 0
        var batchItems: [DA2062BatchItem] = []
        
        // Convert enriched items to batch format
        for (index, item) in items.enumerated() {
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
        do {
            let batchResponse = try await apiService.importDA2062Items(
                items: batchItems,
                source: "local_ocr_ios",
                sourceReference: "DA2062-Local-\(Int(Date().timeIntervalSince1970))"
            )
            
            successCount = batchResponse.createdCount
            progress.processedItems = successCount
            
            // Log any errors
            if let errors = batchResponse.errors {
                for error in errors {
                    addError(ImportError(
                        itemName: "Batch Import",
                        error: error,
                        recoverable: false
                    ))
                }
            }
            
        } catch {
            addError(ImportError(
                itemName: "Batch Import",
                error: "Failed to import items: \(error.localizedDescription)",
                recoverable: false
            ))
        }
        
        print("Import complete: \(successCount) of \(items.count) items created successfully")
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
        DispatchQueue.main.async {
            self.progress.currentPhase = phase
            self.progress.currentItem = currentItem
            if let processed = processedItems {
                self.progress.processedItems = processed
            }
        }
    }
    
    private func addError(_ error: ImportError) {
        DispatchQueue.main.async {
            self.progress.errors.append(error)
        }
    }
    
    private func handleImportError(_ error: Error) {
        DispatchQueue.main.async {
            self.isImporting = false
            self.addError(ImportError(
                itemName: "Import Process",
                error: error.localizedDescription,
                recoverable: false
            ))
        }
    }
    
    // MARK: - User Actions
    
    func cancelImport() {
        isImporting = false
        // TODO: Implement cancellation logic
    }
    
    func completeImport() {
        isImporting = false
        showingSummary = false
        // Navigate back or refresh properties list
    }
    
    func toggleOCRMode() {
        useAzureOCR.toggle()
    }
    
    // MARK: - Summary Data
    
    var importSummary: (total: Int, successful: Int) {
        let total = progress.totalItems
        let failed = progress.errors.filter { !$0.recoverable }.count
        let successful = total - failed
        return (total, successful)
    }
} 