import Foundation
import Vision
import UIKit

// OCR modes for different scanning scenarios
enum OCRMode {
    case realTime  // For live camera feed (serial number scanning)
    case staticDocument  // For DA-2062 form scanning
}

// OCR Error types
enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case parsingFailed
    case recognitionLevelNotSupported
    case lowConfidenceResult(Double)
    
    var errorDescription: String? {
        switch self {
        case .recognitionLevelNotSupported:
            return "This device doesn't support accurate text recognition. Please update iOS."
        case .lowConfidenceResult(let confidence):
            return "Text recognition confidence is low (\(Int(confidence * 100))%). Please retake the photo with better lighting."
        case .invalidImage:
            return "Invalid image provided for OCR processing"
        case .noTextFound:
            return "No text found in the image"
        case .parsingFailed:
            return "Failed to parse DA-2062 form data"
        }
    }
}

class DA2062OCRService {
    
    // MARK: - Properties
    private let minimumConfidenceThreshold: Float = 0.5  // Lower threshold with .accurate
    private let patterns = DA2062Patterns()  // Enhanced pattern recognition
    
    // MARK: - Main Processing Method
    func processImage(_ image: UIImage, completion: @escaping (Result<DA2062Form, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(OCRError.invalidImage))
            return
        }
        
        let request = configureTextRecognitionRequest { [weak self] request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.noTextFound))
                return
            }
            
            guard let self = self else { return }
            let form = self.parseDA2062(from: observations, originalImage: image)
            completion(.success(form))
        }
        
        request.progressHandler = { request, progress, error in
            // Optional: Report progress back to UI
            print("OCR Progress: \(progress)")
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Configuration Methods
    private func configureTextRecognitionRequest(completionHandler: @escaping VNRequestCompletionHandler) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest(completionHandler: completionHandler)
        
        // CRITICAL: Set to .accurate for static document scanning
        request.recognitionLevel = .accurate  // Maximum accuracy for static documents
        request.usesLanguageCorrection = true // Enable language correction
        request.recognitionLanguages = ["en-US"] // DA-2062 forms are in English
        
        // Additional accuracy optimizations
        request.minimumTextHeight = 0.0  // Capture all text sizes
        request.customWords = customMilitaryTerms() // Add military-specific vocabulary
        
        return request
    }
    
    // Custom military terms to improve recognition accuracy
    internal func customMilitaryTerms() -> [String] {
        // Combine basic terms with enhanced military terms
        var terms = [
            // Common military abbreviations on DA-2062
            "NSN", "LIN", "EA", "PR", "BX", "DZ", "GR", "CS", "HD", "ST", "SE", 
            "KT", "PG", "PK", "RL", "CN", "BT", "GL", "DR", "QT", "PT", "LB", 
            "OZ", "FT", "IN", "YD", "MI", "M", "CM", "MM", "KM",
            // Common form headers
            "HAND RECEIPT", "STOCK NUMBER", "ITEM DESCRIPTION",
            "UNIT OF ISSUE", "QUANTITY", "SERIAL NUMBER",
            // Additional military terms
            "DODAAC", "UIC", "PBO", "MTOE", "TDA", "FEDLOG",
            "PROPERTY BOOK", "COMPONENT", "END ITEM"
        ]
        
        // Add all terms from MilitaryTerms
        terms.append(contentsOf: DA2062Patterns.MilitaryTerms.allTerms)
        
        return terms
    }
    
    // MARK: - Parsing Methods
    private func parseDA2062(from observations: [VNRecognizedTextObservation], originalImage: UIImage) -> DA2062Form {
        var overallConfidence: Double = 0.0
        var confidenceCount = 0
        
        var unitName: String?
        var dodaac: String?
        var formNumber: String?
        var allTextLines: [String] = []
        
        // First pass - collect all high-confidence text lines
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            
            let text = candidate.string
            let confidence = candidate.confidence
            
            // Track overall confidence
            overallConfidence += Double(confidence)
            confidenceCount += 1
            
            // Only process high-confidence text
            if confidence > minimumConfidenceThreshold {
                allTextLines.append(text)
                
                // Look for specific patterns
                if text.contains("UNIT:") || text.contains("ORGANIZATION:") {
                    unitName = extractValue(from: text, after: ["UNIT:", "ORGANIZATION:"])
                }
                
                if text.contains("DODAAC:") || text.contains("UIC:") {
                    dodaac = extractValue(from: text, after: ["DODAAC:", "UIC:"])
                }
                
                if text.contains("FORM") && text.contains("2062") {
                    formNumber = extractFormNumber(from: text)
                }
            }
        }
        
        // Use enhanced multi-line detection
        let itemGroups = patterns.detectMultiLineItems(from: allTextLines)
        var items: [DA2062Item] = []
        
        // Parse each group of lines as a single item
        for (index, group) in itemGroups.enumerated() {
            if let item = parseItemFromGroup(group, lineNumber: index + 1) {
                items.append(item)
            }
        }
        
        let avgConfidence = confidenceCount > 0 ? overallConfidence / Double(confidenceCount) : 0.0
        
        // Check if confidence is too low
        if avgConfidence < 0.6 {
            print("Warning: Low overall confidence score: \(avgConfidence)")
        }
        
        return DA2062Form(
            unitName: unitName,
            dodaac: dodaac,
            dateCreated: Date(),
            items: items,
            formNumber: formNumber ?? "DA2062-\(Int(Date().timeIntervalSince1970))",
            confidence: avgConfidence
        )
    }
    
    private func parseItemFromGroup(_ lines: [String], lineNumber: Int) -> DA2062Item? {
        // Join lines to check for complete item info
        let fullText = lines.joined(separator: " ")
        
        // Try to parse as single line first
        if let item = patterns.parseItemLine(fullText, lineNumber: lineNumber) {
            // Check if serial number is in subsequent lines
            if item.serialNumber == nil && lines.count > 1 {
                if let serial = patterns.extractSerialFromLines(lines) {
                    // Create new item with updated serial
                    return DA2062Item(
                        lineNumber: item.lineNumber,
                        stockNumber: item.stockNumber,
                        itemDescription: item.itemDescription,
                        quantity: item.quantity,
                        unitOfIssue: item.unitOfIssue,
                        serialNumber: serial,
                        condition: item.condition,
                        confidence: item.confidence,
                        quantityConfidence: item.quantityConfidence,
                        hasExplicitSerial: true
                    )
                }
            }
            return item
        }
        
        // If single line parsing failed, try parsing first line and enhance with subsequent lines
        guard let firstLine = lines.first else { return nil }
        
        // Extract all components first
        var stockNumber: String?
        var itemDescription = ""
        var quantity = 1
        var unitOfIssue = "EA"
        var serialNumber: String?
        var hasExplicitSerial = false
        
        // Extract components from first line
        if let nsn = patterns.extractNSN(from: firstLine) {
            stockNumber = nsn
        }
        
        if let lin = patterns.extractLIN(from: firstLine) {
            itemDescription = "[LIN: \(lin)] "
        }
        
        // Extract from all lines
        for line in lines {
            if let unit = patterns.extractUnitOfIssue(from: line) {
                unitOfIssue = unit
            }
            
            // Try to extract quantity from each line
            if let qty = extractQuantityFromLine(line) {
                quantity = qty
            }
        }
        
        // Extract serial from multi-line
        if let serial = patterns.extractSerialFromLines(lines) {
            serialNumber = serial
            hasExplicitSerial = true
        }
        
        // Build description from remaining text
        var description = fullText
        if let nsn = stockNumber {
            description = description.replacingOccurrences(of: nsn, with: "")
        }
        description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !description.isEmpty {
            itemDescription += description
        }
        
        // Create the item with all extracted values
        let item = DA2062Item(
            lineNumber: lineNumber,
            stockNumber: stockNumber,
            itemDescription: itemDescription,
            quantity: quantity,
            unitOfIssue: unitOfIssue,
            serialNumber: serialNumber,
            condition: "Serviceable",
            confidence: 0.0,
            quantityConfidence: 0.8,
            hasExplicitSerial: hasExplicitSerial
        )
        
        // Calculate confidence
        let finalConfidence = calculateItemConfidence(item: item)
        
        // Create final item with calculated confidence
        let finalItem = DA2062Item(
            lineNumber: item.lineNumber,
            stockNumber: item.stockNumber,
            itemDescription: item.itemDescription,
            quantity: item.quantity,
            unitOfIssue: item.unitOfIssue,
            serialNumber: item.serialNumber,
            condition: item.condition,
            confidence: finalConfidence,
            quantityConfidence: item.quantityConfidence,
            hasExplicitSerial: item.hasExplicitSerial
        )
        
        return finalItem.itemDescription.isEmpty && finalItem.stockNumber == nil ? nil : finalItem
    }
    
    private func extractValue(from text: String, after keywords: [String]) -> String? {
        for keyword in keywords {
            if let range = text.range(of: keyword) {
                let value = String(text[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }
    
    private func extractFormNumber(from text: String) -> String? {
        // Extract form number pattern like "2062-R-NOV-2017"
        let pattern = "2062[A-Z0-9-]*"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            return String(text[range])
        }
        return nil
    }
    
    private func extractQuantityFromLine(_ line: String) -> Int? {
        // Look for standalone numbers that could be quantities
        let pattern = "\\b(\\d{1,3})\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: line) {
                    let numberStr = String(line[range])
                    if let number = Int(numberStr), number > 0 && number <= 999 {
                        // Check context to see if this is likely a quantity
                        let beforeIndex = line.index(range.lowerBound, offsetBy: -min(10, line.distance(from: line.startIndex, to: range.lowerBound)))
                        let afterIndex = line.index(range.upperBound, offsetBy: min(10, line.distance(from: range.upperBound, to: line.endIndex)))
                        let context = String(line[beforeIndex..<afterIndex])
                        
                        // If near a unit of issue, likely a quantity
                        if patterns.extractUnitOfIssue(from: context) != nil {
                            return number
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func calculateItemConfidence(item: DA2062Item) -> Double {
        var confidence = 0.5 // Base confidence
        
        if item.stockNumber != nil {
            confidence += 0.2
        }
        
        if !item.itemDescription.isEmpty && item.itemDescription.count > 5 {
            confidence += 0.15
        }
        
        if item.serialNumber != nil && item.hasExplicitSerial {
            confidence += 0.15
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Device Capability Check
    func checkRecognitionCapability() -> Bool {
        if #available(iOS 13.0, *) {
            // .accurate is available on iOS 13+
            return true
        } else {
            // Fallback for older iOS versions
            return false
        }
    }
}

// MARK: - Unified OCR Service for different modes
class UnifiedOCRService {
    
    func createTextRecognitionRequest(for mode: OCRMode) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        
        switch mode {
        case .realTime:
            // Settings for real-time serial number scanning
            request.recognitionLevel = .fast
            request.minimumTextHeight = 0.05  // Larger text only
            request.usesLanguageCorrection = false  // Speed over accuracy
            
        case .staticDocument:
            // Settings for DA-2062 form scanning
            request.recognitionLevel = .accurate
            request.minimumTextHeight = 0.0  // All text sizes
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            request.customWords = DA2062OCRService().customMilitaryTerms()
        }
        
        return request
    }
}

// MARK: - Debug Extension
#if DEBUG
extension DA2062OCRService {
    
    func compareRecognitionLevels(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let levels: [VNRequestTextRecognitionLevel] = [.fast, .accurate]
        
        for level in levels {
            let startTime = Date()
            
            let request = VNRecognizeTextRequest { request, error in
                let endTime = Date()
                let processingTime = endTime.timeIntervalSince(startTime)
                
                if let observations = request.results as? [VNRecognizedTextObservation] {
                    let totalConfidence = observations.compactMap { 
                        $0.topCandidates(1).first?.confidence 
                    }.reduce(0, +)
                    
                    let avgConfidence = observations.isEmpty ? 0 : totalConfidence / Float(observations.count)
                    
                    print("""
                    ===== Recognition Level Comparison =====
                    Recognition Level: \(level == .accurate ? "Accurate" : "Fast")
                    Processing Time: \(String(format: "%.2f", processingTime))s
                    Text Observations: \(observations.count)
                    Average Confidence: \(String(format: "%.2f", avgConfidence))
                    =====================================
                    """)
                    
                    // Print sample text for comparison
                    if observations.count > 0 {
                        print("Sample recognized text:")
                        for (index, observation) in observations.prefix(5).enumerated() {
                            if let text = observation.topCandidates(1).first?.string {
                                print("\(index + 1). \(text)")
                            }
                        }
                    }
                }
            }
            
            request.recognitionLevel = level
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = (level == .accurate)
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("Error processing with \(level == .accurate ? "accurate" : "fast") level: \(error)")
            }
        }
    }
}
#endif

 