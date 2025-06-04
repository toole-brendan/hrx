import SwiftUI
import VisionKit
import Vision

// SwiftUI wrapper for VNDocumentCameraViewController
struct VisionDocumentScanner: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    let onCompletion: ([UIImage]) -> Void
    let onCancel: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        
        // Apply 8VC-inspired styling to the scanner
        if let navigationBar = scannerViewController.navigationController?.navigationBar {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppColors.appBackground)
            appearance.titleTextAttributes = [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular, design: .monospaced),
                .foregroundColor: UIColor(AppColors.primaryText)
            ]
            appearance.shadowColor = .clear
            
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.tintColor = UIColor(AppColors.accent)
        }
        
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: VisionDocumentScanner
        
        init(_ parent: VisionDocumentScanner) {
            self.parent = parent
        }
        
        // Called when user finishes scanning
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var scannedImages: [UIImage] = []
            
            // Extract all pages from the scan
            for pageIndex in 0..<scan.pageCount {
                let scannedImage = scan.imageOfPage(at: pageIndex)
                scannedImages.append(scannedImage)
            }
            
            parent.presentationMode.wrappedValue.dismiss()
            parent.onCompletion(scannedImages)
        }
        
        // Called when user cancels
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.presentationMode.wrappedValue.dismiss()
            parent.onCancel()
        }
        
        // Called if scanning fails
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.presentationMode.wrappedValue.dismiss()
            // You might want to pass the error to the parent for handling
            print("Document scanning failed: \(error.localizedDescription)")
            parent.onCancel()
        }
    }
} 