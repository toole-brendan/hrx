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
        configureNavigationBarAppearance(for: scannerViewController)
        
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed
    }
    
    private func configureNavigationBarAppearance(for controller: VNDocumentCameraViewController) {
        // Create custom navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Background styling
        appearance.backgroundColor = UIColor(AppColors.appBackground)
        appearance.shadowColor = UIColor(AppColors.shadowColor)
        
        // Title styling - use serif font for elegance
        appearance.titleTextAttributes = [
            .font: UIFont(name: "Times New Roman", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor(AppColors.primaryText)
        ]
        
        appearance.largeTitleTextAttributes = [
            .font: UIFont(name: "Times New Roman", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: UIColor(AppColors.primaryText)
        ]
        
        // Button styling
        appearance.buttonAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor(AppColors.accent)
        ]
        
        appearance.doneButtonAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor(AppColors.accent)
        ]
        
        // Apply appearance to navigation bar
        if let navigationController = controller.navigationController {
            let navigationBar = navigationController.navigationBar
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
            navigationBar.tintColor = UIColor(AppColors.accent)
            
            // Add subtle shadow
            navigationBar.layer.masksToBounds = false
            navigationBar.layer.shadowColor = UIColor.black.cgColor
            navigationBar.layer.shadowOpacity = 0.05
            navigationBar.layer.shadowRadius = 2
            navigationBar.layer.shadowOffset = CGSize(width: 0, height: 1)
        }
        
        // Configure the controller itself
        controller.view.backgroundColor = UIColor(AppColors.appBackground)
        
        // Style the scan overlay if possible
        DispatchQueue.main.async {
            self.applyScannerOverlayStyle(to: controller)
        }
    }
    
    private func applyScannerOverlayStyle(to controller: VNDocumentCameraViewController) {
        // Find and style scanner overlay elements
        func styleSubviews(in view: UIView) {
            for subview in view.subviews {
                // Style instruction labels
                if let label = subview as? UILabel {
                    if label.text?.contains("Position") == true || 
                       label.text?.contains("document") == true ||
                       label.text?.contains("camera") == true {
                        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
                        label.textColor = UIColor(AppColors.primaryText)
                    }
                }
                
                // Style buttons
                if let button = subview as? UIButton {
                    button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
                    button.setTitleColor(UIColor(AppColors.accent), for: .normal)
                }
                
                // Recursively style nested views
                styleSubviews(in: subview)
            }
        }
        
        styleSubviews(in: controller.view)
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