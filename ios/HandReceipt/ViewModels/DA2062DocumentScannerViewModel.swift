import SwiftUI
import Vision
import Combine

class DA2062DocumentScannerViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var scannedPages: [ScannedPage] = []
    @Published var extractedText: String = ""
    @Published var ocrConfidence: Double = 0.0
    
    private let ocrQueue = DispatchQueue(label: "com.handreceipt.ocr", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    private let unifiedOCRService = UnifiedOCRService()
    
    struct ScannedPage {
        let id = UUID()
        let image: UIImage
        let pageNumber: Int
        let extractedText: String
        let textObservations: [VNRecognizedTextObservation]
        let confidence: Double
    }
    
    // Process multiple scanned images
    func processScannedDocuments(_ images: [UIImage]) {
        isProcessing = true
        processingProgress = 0.0
        scannedPages = []
        
        let totalImages = Double(images.count)
        
        // Process each page asynchronously
        for (index, image) in images.enumerated() {
            ocrQueue.async { [weak self] in
                self?.processPage(image, pageNumber: index + 1) { scannedPage in
                    DispatchQueue.main.async {
                        self?.scannedPages.append(scannedPage)
                        self?.processingProgress = Double(self?.scannedPages.count ?? 0) / totalImages
                        
                        // If all pages processed
                        if self?.scannedPages.count == images.count {
                            self?.finalizeProcessing()
                        }
                    }
                }
            }
        }
    }
    
    private func processPage(_ image: UIImage, pageNumber: Int, completion: @escaping (ScannedPage) -> Void) {
        guard let cgImage = image.cgImage else { return }
        
        // Use unified OCR service with static document mode
        let request = unifiedOCRService.createTextRecognitionRequest(for: .staticDocument)
        
        // Add progress handler for better feedback
        request.progressHandler = { request, progress, error in
            DispatchQueue.main.async {
                print("Page \(pageNumber) OCR Progress: \(progress)")
            }
        }
        
        request.completionHandler = { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], 
                  error == nil else {
                print("OCR Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Extract text with confidence scores
            var pageText = ""
            var totalConfidence: Double = 0.0
            var recognizedCount = 0
            
            for observation in observations {
                // Get the top candidate with highest confidence
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                
                pageText += topCandidate.string + "\n"
                totalConfidence += Double(topCandidate.confidence)
                recognizedCount += 1
            }
            
            let averageConfidence = recognizedCount > 0 ? totalConfidence / Double(recognizedCount) : 0.0
            
            let scannedPage = ScannedPage(
                image: image,
                pageNumber: pageNumber,
                extractedText: pageText,
                textObservations: observations,
                confidence: averageConfidence
            )
            
            completion(scannedPage)
        }
        
        // Perform the request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform OCR: \(error)")
        }
    }
    
    private func finalizeProcessing() {
        // Sort pages by page number
        scannedPages.sort { $0.pageNumber < $1.pageNumber }
        
        // Combine all text
        extractedText = scannedPages.map { $0.extractedText }.joined(separator: "\n---PAGE BREAK---\n")
        
        // Calculate overall confidence
        let totalConfidence = scannedPages.reduce(0.0) { $0 + $1.confidence }
        ocrConfidence = scannedPages.isEmpty ? 0.0 : totalConfidence / Double(scannedPages.count)
        
        // Log confidence levels for debugging
        print("OCR Processing Complete:")
        print("- Total pages: \(scannedPages.count)")
        print("- Average confidence: \(String(format: "%.2f", ocrConfidence))")
        
        // Log per-page confidence for debugging
        for page in scannedPages {
            print("- Page \(page.pageNumber) confidence: \(String(format: "%.2f", page.confidence))")
        }
        
        isProcessing = false
        processingProgress = 1.0
    }
    
    // Get structured data with bounding boxes for review UI
    func getTextWithBoundingBoxes(for pageIndex: Int) -> [(text: String, bounds: CGRect, confidence: Float)] {
        guard pageIndex < scannedPages.count else { return [] }
        
        let page = scannedPages[pageIndex]
        var results: [(text: String, bounds: CGRect, confidence: Float)] = []
        
        for observation in page.textObservations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            // Convert Vision coordinates to UIKit coordinates
            let boundingBox = observation.boundingBox
            let convertedBox = CGRect(
                x: boundingBox.origin.x,
                y: 1 - boundingBox.origin.y - boundingBox.height,
                width: boundingBox.width,
                height: boundingBox.height
            )
            
            results.append((
                text: topCandidate.string,
                bounds: convertedBox,
                confidence: topCandidate.confidence
            ))
        }
        
        return results
    }
} 