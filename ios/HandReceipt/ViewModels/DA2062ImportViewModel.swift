import Foundation
import SwiftUI
import Combine
import UIKit

// MARK: - Enhanced ViewModel with Progress Tracking

@MainActor
class DA2062ImportViewModel: ObservableObject {
    @Published var progress = ImportProgress(totalItems: 0)
    @Published var isImporting = false
    @Published var showingSummary = false
    
    private let apiService: APIServiceProtocol
    private let nsnService: NSNService
    private let ocrService = DA2062OCRService()
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
        self.nsnService = NSNService(apiService: apiService)
    }
    
    // MARK: - Main Processing Method
    
    func processDA2062WithProgress(image: UIImage) async {
        // Initialize progress
        progress = ImportProgress(totalItems: 0)
        isImporting = true
        
        // Phase 1: Scanning
        updateProgress(phase: .scanning, currentItem: "Processing image...")
        
        // Phase 2: Extracting
        updateProgress(phase: .extracting, currentItem: "Running OCR...")
        
        do {
            let extractedText = try await performOCR(on: image)
            
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
            
            // Phase 6: Creating records
            updateProgress(phase: .creating, currentItem: "Creating property records...")
            await createPropertyRecords(enrichedItems)
            
            // Complete
            updateProgress(phase: .complete, currentItem: "Import completed successfully!")
            showingSummary = true
            
        } catch {
            handleImportError(error)
        }
    }
    
    // MARK: - OCR Processing
    
    private func performOCR(on image: UIImage) async throws -> DA2062Form {
        return try await withCheckedThrowingContinuation { continuation in
            ocrService.processImage(image) { result in
                switch result {
                case .success(let form):
                    continuation.resume(returning: form)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Parsing
    
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
        // Check if description contains LIN marker with capture group
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
        // Remove LIN marker if present
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
                    // NSN lookup failed, continue with parsed data
                    print("NSN lookup failed for \(nsn): \(error)")
                }
            }
            
            enrichedItems.append(enriched)
            
            // Small delay for UI updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        return enrichedItems
    }
    
    // MARK: - Record Creation
    
    private func createPropertyRecords(_ items: [EnrichedItem]) async {
        var successCount = 0
        
        for (index, item) in items.enumerated() {
            updateProgress(
                phase: .creating,
                currentItem: item.officialName ?? item.validated.parsed.description,
                processedItems: index
            )
            
            do {
                let propertyInput = buildProperty(from: item)
                _ = try await apiService.createProperty(propertyInput)
                successCount += 1
            } catch {
                addError(ImportError(
                    itemName: item.validated.parsed.description,
                    error: "Failed to create record: \(error.localizedDescription)",
                    recoverable: false
                ))
            }
            
            // Small delay for UI updates
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        // Update final processed count
        progress.processedItems = items.count
        
        // Log summary
        print("Import complete: \(successCount) of \(items.count) items created successfully")
    }
    
    private func buildProperty(from item: EnrichedItem) -> CreatePropertyInput {
        return CreatePropertyInput(
            name: item.officialName ?? item.validated.parsed.description,
            serialNumber: item.validated.parsed.serialNumber ?? generateSerialNumber(),
            description: item.validated.parsed.description,
            currentStatus: "Active",
            propertyModelId: nil,
            assignedToUserId: nil,
            nsn: item.validated.parsed.nsn,
            lin: item.validated.parsed.lin
        )
    }
    
    private func generateSerialNumber() -> String {
        // Generate a temporary serial number
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 1000...9999)
        return "TEMP-\(timestamp)-\(random)"
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
    
    // MARK: - Summary Data
    
    var importSummary: (total: Int, successful: Int) {
        let total = progress.totalItems
        let failed = progress.errors.filter { !$0.recoverable }.count
        let successful = total - failed
        return (total, successful)
    }
} 