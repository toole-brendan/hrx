import Foundation
import UIKit
import PDFKit

class PDFCreationUtility {
    
    static func createPDF(from images: [UIImage], fileName: String = "DA2062_Scan") -> Data? {
        let pdfMetaData = [
            kCGPDFContextCreator: "HandReceipt iOS App",
            kCGPDFContextAuthor: "U.S. Army",
            kCGPDFContextTitle: "DA Form 2062 - Hand Receipt",
            kCGPDFContextSubject: "Scanned DA 2062 Hand Receipt Form"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // Use letter size pages (8.5" x 11")
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Points (72 DPI)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let pdfData = renderer.pdfData { context in
            for (index, image) in images.enumerated() {
                context.beginPage()
                
                // Calculate scaling to fit the image within the page while maintaining aspect ratio
                let imageSize = image.size
                let pageSize = pageRect.size
                
                let scaleX = pageSize.width / imageSize.width
                let scaleY = pageSize.height / imageSize.height
                let scale = min(scaleX, scaleY)
                
                let scaledWidth = imageSize.width * scale
                let scaledHeight = imageSize.height * scale
                
                // Center the image on the page
                let x = (pageSize.width - scaledWidth) / 2
                let y = (pageSize.height - scaledHeight) / 2
                
                let drawRect = CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
                image.draw(in: drawRect)
                
                debugPrint("Added page \(index + 1) to PDF with size: \(scaledWidth) x \(scaledHeight)")
            }
        }
        
        debugPrint("Created PDF with \(images.count) pages, size: \(pdfData.count) bytes")
        return pdfData
    }
    
    static func createPDFFromScannedPages(_ pages: [DA2062DocumentScannerViewModel.ScannedPage]) -> Data? {
        let images = pages.map { $0.image }
        let fileName = "DA2062_\(Int(Date().timeIntervalSince1970))"
        return createPDF(from: images, fileName: fileName)
    }
}

// Debug print function to avoid cluttering 
private func debugPrint(_ items: Any..., function: String = #function, file: String = #file, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    print("DEBUG: [\(fileName):\(line)] \(function) - ", terminator: "")
    for item in items {
        print(item, terminator: " ")
    }
    print()
    #endif
} 