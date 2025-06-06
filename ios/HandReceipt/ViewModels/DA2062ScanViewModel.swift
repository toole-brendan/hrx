//ios/HandReceipt/ViewModels/DA2062ScanViewModel.swift

import Foundation
import SwiftUI
import Combine
import PDFKit
import UIKit

class DA2062ScanViewModel: ObservableObject {
    @Published var currentForm: DA2062Form?
    @Published var recentScans: [DA2062Scan] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var processingProgress: Double = 0.0
    @Published var processingMessage: String = ""
    @Published var useAzureOCR = true  // Primary OCR method
    @Published var processingMethod: String = ""
    @Published var lastProcessedImage: UIImage?  // Add missing property
    
    private var cancellables = Set<AnyCancellable>()
    private let ocrService = DA2062OCRService()
    private let apiService = APIService.shared
    private var progressTimer: Timer?
    
    // MARK: - Enhanced Property Creation with Quantity Handling
    
    func createPropertiesFromParsedItems(_ items: [EditableDA2062Item]) -> [DA2062PropertyRequest] {
        var propertyRequests: [DA2062PropertyRequest] = []
        
        for item in items where item.isSelected {
            let quantity = Int(item.quantity) ?? 1
            
            if quantity > 1 && !item.hasExplicitSerial {
                // Create multiple entries for non-serialized items
                for index in 1...quantity {
                    let generatedSerial = generatePlaceholderSerial(
                        for: item,
                        index: index,
                        total: quantity
                    )
                    
                    let metadata = createImportMetadata(
                        for: item,
                        serialSource: .generated,
                        quantityIndex: index,
                        originalQuantity: quantity
                    )
                    
                    let request = DA2062PropertyRequest(
                        name: item.description,
                        description: buildEnhancedDescription(for: item, index: index, total: quantity),
                        serialNumber: generatedSerial,
                        nsn: item.nsn.isEmpty ? nil : item.nsn,
                        quantity: 1, // Each entry represents single item
                        unit: item.unit ?? "EA",
                        location: nil,
                        category: categorizeItem(item.description),
                        da2062Reference: currentForm?.id.uuidString,
                        importMetadata: metadata
                    )
                    
                    propertyRequests.append(request)
                }
            } else {
                // Single item or has explicit serial
                let metadata = createImportMetadata(
                    for: item,
                    serialSource: item.hasExplicitSerial ? .explicit : .manual,
                    quantityIndex: nil,
                    originalQuantity: quantity
                )
                
                let request = DA2062PropertyRequest(
                    name: item.description,
                    description: buildEnhancedDescription(for: item),
                    serialNumber: item.serialNumber.isEmpty ? 
                        generatePlaceholderSerial(for: item, index: 1, total: 1) : 
                        item.serialNumber,
                    nsn: item.nsn.isEmpty ? nil : item.nsn,
                    quantity: quantity,
                    unit: item.unit ?? "EA",
                    location: nil,
                    category: categorizeItem(item.description),
                    da2062Reference: currentForm?.id.uuidString,
                    importMetadata: metadata
                )
                
                propertyRequests.append(request)
            }
        }
        
        return propertyRequests
    }
    
    // Generate consistent placeholder serials
    private func generatePlaceholderSerial(for item: EditableDA2062Item, index: Int, total: Int) -> String {
        let timestamp = Date().timeIntervalSince1970
        let baseIdentifier: String
        
        if !item.nsn.isEmpty {
            // Use NSN as base if available
            baseIdentifier = item.nsn.replacingOccurrences(of: "-", with: "")
        } else {
            // Use first 8 chars of description (alphanumeric only)
            let cleanDesc = item.description
                .uppercased()
                .replacingOccurrences(of: " ", with: "")
                .filter { $0.isLetter || $0.isNumber }
            baseIdentifier = String(cleanDesc.prefix(8))
        }
        
        // Format: BASE-YYMMDD-XXofYY
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd"
        let dateStr = dateFormatter.string(from: Date())
        
        if total > 1 {
            return "GEN-\(baseIdentifier)-\(dateStr)-\(String(format: "%02d", index))of\(String(format: "%02d", total))"
        } else {
            return "GEN-\(baseIdentifier)-\(dateStr)-\(String(format: "%04d", Int(timestamp) % 10000))"
        }
    }
    
    // Create import metadata
    private func createImportMetadata(
        for item: EditableDA2062Item,
        serialSource: SerialSource,
        quantityIndex: Int?,
        originalQuantity: Int
    ) -> ImportMetadata {
        var verificationReasons: [String] = []
        
        // Determine if verification is needed
        if item.confidence < 0.7 {
            verificationReasons.append("Low OCR confidence (\(Int(item.confidence * 100))%)")
        }
        
        if serialSource == .generated {
            verificationReasons.append("Serial number was auto-generated")
        }
        
        if item.quantityConfidence < 0.8 && originalQuantity > 1 {
            verificationReasons.append("Quantity field had low confidence")
        }
        
        if item.nsn.isEmpty {
            verificationReasons.append("No NSN detected")
        }
        
        return ImportMetadata(
            source: "da2062_scan",
            importDate: Date(),
            formNumber: currentForm?.formNumber,
            unitName: currentForm?.unitName,
            scanConfidence: currentForm?.confidence ?? 0,
            itemConfidence: item.confidence,
            serialSource: serialSource,
            originalQuantity: originalQuantity > 1 ? originalQuantity : nil,
            quantityIndex: quantityIndex,
            requiresVerification: !verificationReasons.isEmpty,
            verificationReasons: verificationReasons
        )
    }
    
    // Enhanced description with metadata
    private func buildEnhancedDescription(for item: EditableDA2062Item, index: Int? = nil, total: Int? = nil) -> String {
        var parts: [String] = []
        
        if !item.nsn.isEmpty {
            parts.append("NSN: \(item.nsn)")
        }
        
        if !item.serialNumber.isEmpty && item.hasExplicitSerial {
            parts.append("S/N: \(item.serialNumber)")
        }
        
        if let index = index, let total = total, total > 1 {
            parts.append("Item \(index) of \(total)")
        }
        
        parts.append("Imported from DA-2062")
        
        if let formNumber = currentForm?.formNumber {
            parts.append("Form: \(formNumber)")
        }
        
        parts.append("Import Date: \(Date().formatted(date: .abbreviated, time: .omitted))")
        
        return parts.joined(separator: " | ")
    }
    
    // Categorize item based on description
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
    
    // MARK: - Existing Methods
    
    // Process extracted text from OCR
    func processExtractedText(_ text: String, pages: [UIImage], confidence: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        isProcessing = true
        errorMessage = nil
        
        // Parse the extracted text to create DA2062Form
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let form = try self?.parseDA2062Text(text)
                
                Task { @MainActor in
                    self?.currentForm = form
                    self?.isProcessing = false
                    
                    // Check if any items require verification
                    let requiresVerification = form?.items.contains { item in
                        item.confidence < 0.7 || item.quantityConfidence < 0.8 || !item.hasExplicitSerial
                    } ?? false
                    
                    // Add to recent scans
                    let scan = DA2062Scan(
                        date: Date(),
                        pageCount: pages.count,
                        itemCount: form?.items.count ?? 0,
                        confidence: confidence,
                        formNumber: form?.formNumber,
                        requiresVerification: requiresVerification
                    )
                    self?.recentScans.insert(scan, at: 0)
                    
                    // Keep only last 10 scans
                    if self?.recentScans.count ?? 0 > 10 {
                        self?.recentScans = Array(self?.recentScans.prefix(10) ?? [])
                    }
                    
                    completion(.success(()))
                }
            } catch {
                Task { @MainActor in
                    self?.isProcessing = false
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Process DA2062 with OCR service integration
    func processDA2062(image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        // Check device capability first
        guard ocrService.checkRecognitionCapability() else {
            completion(.failure(OCRError.recognitionLevelNotSupported))
            return
        }
        
        isProcessing = true
        processingProgress = 0.1
        processingMethod = "On-Device OCR"
        
        // Show appropriate messaging for accurate processing
        processingMessage = "Analyzing document with high accuracy..."
        
        // Accurate processing takes 2-5x longer than fast
        // Update progress incrementally
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                if self.processingProgress < 0.8 {
                    self.processingProgress += 0.1
                    
                    // Update message based on progress
                    switch self.processingProgress {
                    case 0..<0.3:
                        self.processingMessage = "Preparing document for analysis..."
                    case 0.3..<0.5:
                        self.processingMessage = "Detecting text regions..."
                    case 0.5..<0.7:
                        self.processingMessage = "Recognizing military terminology..."
                    case 0.7..<0.9:
                        self.processingMessage = "Extracting form data..."
                    default:
                        self.processingMessage = "Finalizing results..."
                    }
                } else {
                    timer.invalidate()
                }
            }
        }
        
        ocrService.processImage(image) { [weak self] result in
            Task { @MainActor in
                self?.progressTimer?.invalidate()
                self?.processingProgress = 1.0
                self?.isProcessing = false
                
                switch result {
                case .success(let form):
                    self?.currentForm = form
                    self?.processingMessage = "Processing complete!"
                    
                    // Add to recent scans
                    let scan = DA2062Scan(
                        date: Date(),
                        pageCount: 1,
                        itemCount: form.items.count,
                        confidence: form.confidence,
                        formNumber: form.formNumber,
                        requiresVerification: false
                    )
                    self?.recentScans.insert(scan, at: 0)
                    
                    // Keep only last 10 scans
                    if self?.recentScans.count ?? 0 > 10 {
                        self?.recentScans = Array(self?.recentScans.prefix(10) ?? [])
                    }
                    
                    completion(.success(()))
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    self?.processingMessage = "Processing failed"
                    
                    // Handle specific OCR errors
                    if let ocrError = error as? OCRError {
                        switch ocrError {
                        case .lowConfidenceResult(let confidence):
                            self?.processingMessage = "Low confidence result (\(Int(confidence * 100))%)"
                            // Still show results but warn user
                            completion(.success(()))
                        default:
                            completion(.failure(error))
                        }
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    // MARK: - Azure OCR Integration
    
    // Upload scanned pages to Azure OCR for processing
    func uploadScannedFormToAzure(pages: [DA2062DocumentScannerViewModel.ScannedPage]) async -> Result<Void, Error> {
        await MainActor.run {
            isProcessing = true
            processingProgress = 0.0
            processingMethod = "Azure Cloud OCR"
            processingMessage = "Preparing document for upload..."
            errorMessage = nil
        }
        
        do {
            // Step 1: Create PDF from scanned pages
            await MainActor.run {
                processingProgress = 0.1
                processingMessage = "Creating PDF from scanned pages..."
            }
            
            guard let pdfData = PDFCreationUtility.createPDFFromScannedPages(pages) else {
                throw NSError(domain: "PDFCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF from scanned images"])
            }
            
            // Step 2: Upload to Azure OCR
            await MainActor.run {
                processingProgress = 0.3
                processingMessage = "Uploading to Azure OCR service..."
            }
            
            let fileName = "DA2062_\(Int(Date().timeIntervalSince1970)).pdf"
            let response = try await apiService.uploadDA2062Form(pdfData: pdfData, fileName: fileName)
            
            // Step 3: Process Azure OCR response
            await MainActor.run {
                processingProgress = 0.8
                processingMessage = "Processing OCR results..."
            }
            
            await MainActor.run {
                self.currentForm = self.convertAzureResponseToForm(response)
                self.processingProgress = 1.0
                self.processingMessage = "Azure OCR processing complete!"
                self.isProcessing = false
                
                // Add to recent scans
                let scan = DA2062Scan(
                    date: Date(),
                    pageCount: pages.count,
                    itemCount: response.items?.count ?? 0,
                    confidence: response.formInfo.confidence,
                    formNumber: response.formInfo.formNumber,
                    requiresVerification: response.nextSteps?.verificationNeeded ?? false
                )
                self.recentScans.insert(scan, at: 0)
                
                // Keep only last 10 scans
                if self.recentScans.count > 10 {
                    self.recentScans = Array(self.recentScans.prefix(10))
                }
            }
            
            return .success(())
            
        } catch {
            await MainActor.run {
                self.isProcessing = false
                self.processingProgress = 0.0
                self.errorMessage = error.localizedDescription
                self.processingMessage = "Azure OCR processing failed"
            }
            
            return .failure(error)
        }
    }
    
    // Convert Azure OCR response to local DA2062Form model
    private func convertAzureResponseToForm(_ response: AzureOCRResponse) -> DA2062Form {
        let items = (response.items ?? []).map { azureItem in
            DA2062Item(
                lineNumber: 0, // Azure doesn't provide line numbers
                stockNumber: azureItem.nsn,
                itemDescription: azureItem.description,
                quantity: azureItem.quantity,
                unitOfIssue: azureItem.unit,
                serialNumber: azureItem.serialNumber,
                condition: nil, // Azure response doesn't have condition field
                confidence: azureItem.importMetadata.confidence,
                quantityConfidence: azureItem.importMetadata.confidence, // Use same confidence for quantity
                hasExplicitSerial: !(azureItem.serialNumber?.isEmpty ?? true)
            )
        }
        
        return DA2062Form(
            unitName: response.formInfo.unitName,
            dodaac: response.formInfo.dodaac,
            dateCreated: Date(),
            items: items,
            formNumber: response.formInfo.formNumber,
            confidence: response.formInfo.confidence
        )
    }
    
    // Import verified items to backend
    func importVerifiedItems(_ editableItems: [EditableDA2062Item]) async -> Result<BatchImportResponse, Error> {
        // Filter and validate items before creating batch items
        let validItems = editableItems.filter { item in
            guard item.isSelected else { return false }
            
            // Validate required fields
            let serialNumber = item.serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = item.description.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip items without valid serial numbers or descriptions
            if serialNumber.isEmpty || description.isEmpty {
                debugPrint("⚠️ Skipping item '\(description)' - missing required fields (serial: '\(serialNumber)', description: '\(description)')")
                return false
            }
            
            // Skip items with obviously generated/placeholder serials
            let upperSerial = serialNumber.uppercased()
            if upperSerial.contains("NOSERIAL") || 
               upperSerial.contains("TEMP") || 
               upperSerial.contains("PLACEHOLDER") ||
               upperSerial.contains("GENERATED") {
                debugPrint("⚠️ Skipping item '\(description)' - placeholder serial number: '\(serialNumber)'")
                return false
            }
            
            return true
        }
        
        // Check if we have any valid items to import
        guard !validItems.isEmpty else {
            let errorMessage = "No valid items to import. Please ensure all items have valid serial numbers and descriptions."
            return .failure(NSError(domain: "DA2062Import", code: 400, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
        }
        
        // Convert valid items to batch items
        let batchItems = validItems.map { item in
            let quantity = Int(item.quantity) ?? 1
            
            return DA2062BatchItem(
                name: item.description,
                description: buildEnhancedDescription(for: item),
                serialNumber: item.serialNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                nsn: item.nsn.isEmpty ? nil : item.nsn,
                quantity: quantity,
                unit: item.unit ?? "EA",
                category: categorizeItem(item.description),
                importMetadata: BatchImportMetadata(
                    confidence: item.confidence,
                    requiresVerification: item.needsVerification,
                    verificationReasons: getVerificationReasons(for: item),
                    sourceDocumentUrl: nil, // Will be filled by backend
                    originalQuantity: quantity > 1 ? quantity : nil,
                    quantityIndex: nil
                )
            )
        }
        
        debugPrint("📤 Importing \(batchItems.count) validated items (filtered from \(editableItems.filter { $0.isSelected }.count) selected items)")
        
        do {
            let response = try await apiService.importDA2062Items(
                items: batchItems,
                source: "da2062_scan",
                sourceReference: currentForm?.formNumber
            )
            return .success(response)
        } catch {
            return .failure(error)
        }
    }
    
    // Helper methods for batch import
    private func getVerificationReasons(for item: EditableDA2062Item) -> [String] {
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
    
    // Parse DA2062 text format (simplified for compatibility)
    private func parseDA2062Text(_ text: String) throws -> DA2062Form {
        // This is a simplified parser - actual implementation would be more sophisticated
        let items: [DA2062Item] = []
        let lines = text.components(separatedBy: .newlines)
        
        var unitName: String?
        var dodaac: String?
        
        // Look for unit name and DODAAC in header
        for line in lines {
            if line.contains("UNIT:") {
                unitName = line.replacingOccurrences(of: "UNIT:", with: "").trimmingCharacters(in: .whitespaces)
            }
            if line.contains("DODAAC:") {
                dodaac = line.replacingOccurrences(of: "DODAAC:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        
        // For now, return form with parsed header info
        // Actual items would be parsed by the OCR service
        return DA2062Form(
            unitName: unitName,
            dodaac: dodaac,
            dateCreated: Date(),
            items: items,
            formNumber: "DA2062-\(Date().timeIntervalSince1970)",
            confidence: 0.85
        )
    }
    
    // Select a recent scan
    func selectScan(_ scan: DA2062Scan) {
        // In a real app, you'd load the scan data from storage
        // For now, just set a placeholder
    }
    
    // Create properties from reviewed items
    func createProperties(from items: [DA2062PropertyRequest]) {
        // This would call your API service to create the properties
        // For now, just print
        print("Creating \(items.count) properties from DA2062")
        
        // In production, this would call the API service
        // apiService.createBulkProperties(items) { result in ... }
    }
    
    // Clean up resources
    deinit {
        progressTimer?.invalidate()
    }
    
    // MARK: - Missing Methods
    
    func startScanning() {
        // Implementation for starting the scanning process
        // This would typically trigger camera scanning
        print("Starting scanning process...")
    }
    
    func reprocessScan(_ scan: DA2062Scan) {
        // Implementation for reprocessing a previous scan
        Task { @MainActor in
            isProcessing = true
            processingMessage = "Reprocessing scan..."
        }
        // Add reprocessing logic here
    }
    
    func processScannedDocuments(_ images: [UIImage]) {
        guard let firstImage = images.first else { return }
        
        lastProcessedImage = firstImage
        
        processDA2062(image: firstImage) { result in
            switch result {
            case .success():
                print("Successfully processed scanned document")
            case .failure(let error):
                print("Failed to process scanned document: \(error)")
            }
        }
    }
}

// MARK: - Debug helpers
#if DEBUG
extension DA2062ScanViewModel {
    func testRecognitionLevels(with image: UIImage) {
        ocrService.compareRecognitionLevels(image)
    }
}
#endif 