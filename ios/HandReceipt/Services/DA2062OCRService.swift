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
    
    // MARK: - Main Processing Method
    func processImage(_ image: UIImage, completion: @escaping (Result<DA2062Form, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(OCRError.invalidImage))
            return
        }
        
        let request = configureTextRecognitionRequest()
        
        request.progressHandler = { request, progress, error in
            // Optional: Report progress back to UI
            print("OCR Progress: \(progress)")
        }
        
        let requestHandler = { (request: VNRequest, error: Error?) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.noTextFound))
                return
            }
            
            let form = self.parseDA2062(from: observations, originalImage: image)
            completion(.success(form))
        }
        
        request.completionHandler = requestHandler
        
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
    private func configureTextRecognitionRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        
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
    private func customMilitaryTerms() -> [String] {
        return [
            // Common military abbreviations on DA-2062
            "NSN", "LIN", "EA", "BX", "PR", "FT", "DOZ",
            // Military equipment terms
            "CARBINE", "MAGAZINE", "OPTIC", "NVGS", "IOTV", "ACH",
            "ESAPI", "IFAK", "SINCGARS", "ASIP", "ACOG", "EOTECH",
            // Common form headers
            "HAND RECEIPT", "STOCK NUMBER", "ITEM DESCRIPTION",
            "UNIT OF ISSUE", "QUANTITY", "SERIAL NUMBER",
            // Additional military terms
            "DODAAC", "UIC", "PBO", "MTOE", "TDA", "FEDLOG",
            "PROPERTY BOOK", "COMPONENT", "END ITEM"
        ]
    }
    
    // MARK: - Parsing Methods
    private func parseDA2062(from observations: [VNRecognizedTextObservation], originalImage: UIImage) -> DA2062Form {
        var items: [DA2062Item] = []
        var overallConfidence: Double = 0.0
        var confidenceCount = 0
        
        var unitName: String?
        var dodaac: String?
        var allTextLines: [String] = []
        
        for observation in observations {
            // With .accurate, we get better confidence scores
            guard let candidate = observation.topCandidates(1).first else { continue }
            
            let text = candidate.string
            let confidence = candidate.confidence
            
            // Track overall confidence
            overallConfidence += Double(confidence)
            confidenceCount += 1
            
            // Only process high-confidence text (threshold lower with .accurate)
            if confidence > minimumConfidenceThreshold {
                allTextLines.append(text)
                
                // Look for specific patterns
                if text.contains("UNIT:") || text.contains("ORGANIZATION:") {
                    unitName = extractValue(from: text, after: ["UNIT:", "ORGANIZATION:"])
                }
                
                if text.contains("DODAAC:") || text.contains("UIC:") {
                    dodaac = extractValue(from: text, after: ["DODAAC:", "UIC:"])
                }
            }
        }
        
        // Parse items from collected text lines
        items = parseItemsFromLines(allTextLines)
        
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
            formNumber: "DA2062-\(Int(Date().timeIntervalSince1970))",
            confidence: avgConfidence
        )
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
    
    private func parseItemsFromLines(_ lines: [String]) -> [DA2062Item] {
        // Use the enhanced parsing method
        return parseItemsFromLinesEnhanced(lines)
    }
    
    private func extractGroup(from string: String, at index: Int, in match: NSTextCheckingResult) -> String? {
        guard index < match.numberOfRanges else { return nil }
        let range = match.range(at: index)
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: string) else { return nil }
        return String(string[swiftRange]).trimmingCharacters(in: .whitespaces)
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

// MARK: - OCR Service Enhancement for Quantity Detection

extension DA2062OCRService {
    
    private func parseItemLine(_ line: String, lineNumber: Int) -> DA2062Item? {
        let components = line.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
        
        guard components.count >= 3 else { return nil }
        
        let nsn = extractNSN(from: String(components[0]))
        
        // Enhanced quantity parsing with confidence
        let (quantity, quantityConfidence) = extractQuantity(from: components)
        
        // Look for explicit serial number
        let (serialNumber, hasExplicitSerial) = extractSerialNumber(from: line)
        
        // Build description from middle components
        let descriptionEndIndex = max(1, components.count - 2)
        let description = components[1..<descriptionEndIndex].joined(separator: " ")
        
        // Extract unit of issue
        let unit = extractUnitOfIssue(from: components)
        
        return DA2062Item(
            lineNumber: lineNumber,
            stockNumber: nsn,
            itemDescription: description,
            quantity: quantity,
            unitOfIssue: unit,
            serialNumber: serialNumber,
            condition: "Serviceable",
            confidence: calculateItemConfidence(nsn: nsn, description: description),
            quantityConfidence: quantityConfidence,
            hasExplicitSerial: hasExplicitSerial
        )
    }
    
    private func extractQuantity(from components: [String.SubSequence]) -> (quantity: Int, confidence: Double) {
        // DA-2062 typically has quantity in one of the last columns
        // Look for numeric values near the end
        
        for i in (max(0, components.count - 4)..<components.count).reversed() {
            if let qty = Int(components[i]) {
                // Confidence based on position and value reasonableness
                let confidence: Double
                if qty >= 1 && qty <= 99 {
                    confidence = 0.9 // Reasonable quantity
                } else if qty >= 100 && qty <= 999 {
                    confidence = 0.7 // Less common but possible
                } else {
                    confidence = 0.5 // Unusual quantity
                }
                
                return (qty, confidence)
            }
        }
        
        // Default to 1 with low confidence if not found
        return (1, 0.3)
    }
    
    private func extractNSN(from text: String) -> String? {
        // NSN format: 1234-56-789-0123
        let nsnPattern = #"\d{4}-\d{2}-\d{3}-\d{4}"#
        
        if let regex = try? NSRegularExpression(pattern: nsnPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            return String(text[range])
        }
        
        return nil
    }
    
    private func extractSerialNumber(from line: String) -> (serial: String?, hasExplicit: Bool) {
        // Look for common serial number patterns
        let patterns = [
            "SN:\\s*([A-Z0-9]+)",
            "S/N:\\s*([A-Z0-9]+)",
            "SERIAL:\\s*([A-Z0-9]+)",
            "SER NO:\\s*([A-Z0-9]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                return (String(line[range]), true)
            }
        }
        
        // Check for standalone alphanumeric strings that might be serials
        // (6-20 characters, mix of letters and numbers)
        let components = line.split(separator: " ")
        for component in components {
            let str = String(component)
            if str.count >= 6 && str.count <= 20 &&
               str.contains(where: { $0.isLetter }) &&
               str.contains(where: { $0.isNumber }) &&
               !str.contains("-") { // Not an NSN
                return (str, false) // Found but with lower confidence
            }
        }
        
        return (nil, false)
    }
    
    private func extractUnitOfIssue(from components: [String.SubSequence]) -> String {
        let commonUnits = ["EA", "PR", "SE", "BX", "RL", "FT", "YD", "LB", "OZ", "GL", "QT", "PT"]
        
        // Check last few components for unit
        for i in (max(0, components.count - 3)..<components.count).reversed() {
            let component = String(components[i]).uppercased()
            if commonUnits.contains(component) {
                return component
            }
        }
        
        return "EA" // Default to "each"
    }
    
    private func calculateItemConfidence(nsn: String?, description: String) -> Double {
        var confidence = 0.5 // Base confidence
        
        if nsn != nil && nsn!.count == 16 { // Valid NSN format (includes dashes)
            confidence += 0.2
        }
        
        if description.count > 5 && description.count < 100 { // Reasonable description length
            confidence += 0.2
        }
        
        if description.contains(where: { $0.isLetter }) { // Has letters (not just numbers)
            confidence += 0.1
        }
        
        return min(confidence, 1.0)
    }
    
    // Enhanced parseItemsFromLines to use the new parsing logic
    func parseItemsFromLinesEnhanced(_ lines: [String]) -> [DA2062Item] {
        var items: [DA2062Item] = []
        var lineNumber = 1
        
        for line in lines {
            // Skip empty lines and headers
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty || isHeaderLine(trimmedLine) {
                continue
            }
            
            // Try to parse as item line
            if let item = parseItemLine(trimmedLine, lineNumber: lineNumber) {
                items.append(item)
                lineNumber += 1
            }
        }
        
        return items
    }
    
    private func isHeaderLine(_ line: String) -> Bool {
        let headerKeywords = [
            "HAND RECEIPT", "DA FORM", "STOCK NUMBER", "ITEM DESCRIPTION",
            "UNIT OF ISSUE", "QUANTITY", "SERIAL NUMBER", "END ITEM",
            "PAGE", "DODAAC", "UNIT", "DATE", "NOMENCLATURE"
        ]
        
        let upperLine = line.uppercased()
        return headerKeywords.contains { upperLine.contains($0) }
    }
} 