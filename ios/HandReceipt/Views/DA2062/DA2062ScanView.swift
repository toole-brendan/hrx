import SwiftUI
import VisionKit

struct DA2062ScanView: View {
    @StateObject private var scannerViewModel = DA2062DocumentScannerViewModel()
    @StateObject private var da2062ViewModel = DA2062ScanViewModel()
    @State private var showingScanner = false
    @State private var showingProcessingView = false
    @State private var showingReviewSheet = false
    @State private var scannerAvailable = VNDocumentCameraViewController.isSupported
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import DA-2062")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Scan your DA-2062 form to quickly digitize your property book")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Scanner Availability Check
                if !scannerAvailable {
                    WarningCard(
                        icon: "exclamationmark.triangle.fill",
                        message: "Document scanner not available on this device"
                    )
                    .padding(.horizontal)
                }
                
                // Scan Button
                Button(action: { showingScanner = true }) {
                    HStack {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.title2)
                        Text("Scan DA-2062 Form")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(scannerAvailable ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!scannerAvailable)
                .padding(.horizontal)
                
                // Features List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scanner Features:")
                        .font(.headline)
                    
                    FeatureRow(icon: "doc.on.doc", text: "Multi-page scanning support")
                    FeatureRow(icon: "viewfinder.rectangular", text: "Automatic edge detection")
                    FeatureRow(icon: "perspective", text: "Perspective correction")
                    FeatureRow(icon: "text.viewfinder", text: "Enhanced OCR accuracy")
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Recent Scans
                if !da2062ViewModel.recentScans.isEmpty {
                    RecentScansSection(
                        scans: da2062ViewModel.recentScans,
                        onSelect: { scan in
                            da2062ViewModel.selectScan(scan)
                            showingReviewSheet = true
                        }
                    )
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.accent)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("IMPORT DA-2062")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.primaryText)
                        .compatibleKerning(1.2)
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                VisionDocumentScanner(
                    onCompletion: { images in
                        showingScanner = false
                        showingProcessingView = true
                        scannerViewModel.processScannedDocuments(images)
                    },
                    onCancel: {
                        showingScanner = false
                    }
                )
            }
            .sheet(isPresented: $showingProcessingView) {
                ProcessingView(viewModel: scannerViewModel, da2062ViewModel: da2062ViewModel) {
                    // Processing complete - use Azure OCR as primary method
                    showingProcessingView = false
                    
                    Task {
                        let result = await da2062ViewModel.uploadScannedFormToAzure(pages: scannerViewModel.scannedPages)
                        
                        switch result {
                        case .success:
                            showingReviewSheet = true
                        case .failure(let error):
                            print("Azure OCR failed: \(error)")
                            
                            // Fallback to on-device OCR if Azure fails
                            if da2062ViewModel.useAzureOCR {
                                print("Falling back to on-device OCR...")
                                da2062ViewModel.processExtractedText(
                                    scannerViewModel.extractedText,
                                    pages: scannerViewModel.scannedPages.map { $0.image },
                                    confidence: scannerViewModel.ocrConfidence
                                ) { fallbackResult in
                                    switch fallbackResult {
                                    case .success:
                                        showingReviewSheet = true
                                    case .failure(let fallbackError):
                                        print("Fallback OCR also failed: \(fallbackError)")
                                        // Show error to user
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingReviewSheet) {
                DA2062ReviewSheet(
                    form: da2062ViewModel.currentForm,
                    scannedPages: scannerViewModel.scannedPages,
                    onConfirm: { items in
                        // Legacy callback - not used in Azure OCR workflow
                        // Import is handled directly in DA2062ReviewSheet
                        showingReviewSheet = false
                    }
                )
            }
        }
    }
}

// Processing View to show OCR progress
struct ProcessingView: View {
    @ObservedObject var viewModel: DA2062DocumentScannerViewModel
    @ObservedObject var da2062ViewModel: DA2062ScanViewModel
    let onComplete: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Progress Indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: da2062ViewModel.isProcessing ? da2062ViewModel.processingProgress : viewModel.processingProgress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: da2062ViewModel.isProcessing ? da2062ViewModel.processingProgress : viewModel.processingProgress)
                    
                    Text("\(Int((da2062ViewModel.isProcessing ? da2062ViewModel.processingProgress : viewModel.processingProgress) * 100))%")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 8) {
                    Text("Processing Document")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(da2062ViewModel.processingMessage.isEmpty ? "Extracting text from \(viewModel.scannedPages.count) pages" : da2062ViewModel.processingMessage)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if da2062ViewModel.isProcessing && !da2062ViewModel.processingMethod.isEmpty {
                        Text("Method: \(da2062ViewModel.processingMethod)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.top, 2)
                    }
                    
                    if viewModel.processingProgress == 1.0 || da2062ViewModel.processingProgress == 1.0 {
                        Label("Complete", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .padding(.top)
                    }
                    
                    // Recognition level info
                    HStack {
                        Image(systemName: da2062ViewModel.useAzureOCR ? "cloud" : "info.circle")
                            .foregroundColor(.blue)
                        Text(da2062ViewModel.useAzureOCR ? "Using Azure Cloud OCR for best accuracy" : "Using on-device recognition")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
                
                if viewModel.processingProgress == 1.0 || da2062ViewModel.processingProgress == 1.0 {
                    Button("Continue") {
                        onComplete()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .navigationBarTitle("Processing", displayMode: .inline)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct WarningCard: View {
    let icon: String
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// Recent Scans Section
struct RecentScansSection: View {
    let scans: [DA2062Scan]
    let onSelect: (DA2062Scan) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Scans")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(scans) { scan in
                        RecentScanRow(scan: scan) {
                            onSelect(scan)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxHeight: 200)
    }
}

struct RecentScanRow: View {
    let scan: DA2062Scan
    let onTap: () -> Void
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateFormatter.string(from: scan.date))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Label("\(scan.pageCount) pages", systemImage: "doc.on.doc")
                        Label("\(scan.itemCount) items", systemImage: "cube.box")
                        Label("\(Int(scan.confidence * 100))%", systemImage: "checkmark.shield")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 