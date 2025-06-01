import SwiftUI
import VisionKit

struct DA2062ScanView: View {
    @StateObject private var scannerViewModel = DA2062DocumentScannerViewModel()
    @StateObject private var da2062ViewModel = DA2062ScanViewModel()
    @StateObject private var importViewModel = DA2062ImportViewModel()
    @State private var showingScanner = false
    @State private var showingProcessingView = false
    @State private var showingReviewSheet = false
    @State private var showingImportProgress = false
    @State private var showingImportSummary = false
    @State private var scannerAvailable = VNDocumentCameraViewController.isSupported
    
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
                    // Processing complete
                    showingProcessingView = false
                    
                    // Parse the extracted text into DA2062 form
                    da2062ViewModel.processExtractedText(
                        scannerViewModel.extractedText,
                        pages: scannerViewModel.scannedPages.map { $0.image },
                        confidence: scannerViewModel.ocrConfidence
                    ) { result in
                        switch result {
                        case .success:
                            showingReviewSheet = true
                        case .failure(let error):
                            // Show error alert
                            print("Error processing DA2062: \(error)")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingReviewSheet) {
                DA2062ReviewSheet(
                    form: da2062ViewModel.currentForm,
                    scannedPages: scannerViewModel.scannedPages,
                    onConfirm: { items in
                        // Start the import process with progress tracking
                        showingReviewSheet = false
                        showingImportProgress = true
                        
                        Task {
                            // Use the first scanned image for processing
                            if let firstImage = scannerViewModel.scannedPages.first?.image {
                                await importViewModel.processDA2062WithProgress(image: firstImage)
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showingImportProgress) {
                DA2062ImportProgressView(viewModel: importViewModel)
                    .interactiveDismissDisabled(importViewModel.isImporting)
            }
            .sheet(isPresented: $showingImportSummary) {
                DA2062ImportSummaryView(
                    totalItems: importViewModel.importSummary.total,
                    successfulItems: importViewModel.importSummary.successful,
                    errors: importViewModel.progress.errors,
                    onDismiss: {
                        showingImportSummary = false
                        // Reset import view model
                        importViewModel.progress = ImportProgress(totalItems: 0)
                    }
                )
            }
            .onChange(of: importViewModel.showingSummary) { showingSummary in
                if showingSummary {
                    showingImportProgress = false
                    showingImportSummary = true
                }
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
                        .trim(from: 0, to: viewModel.processingProgress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: viewModel.processingProgress)
                    
                    Text("\(Int(viewModel.processingProgress * 100))%")
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
                    
                    if viewModel.processingProgress == 1.0 {
                        Label("Complete", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .padding(.top)
                    }
                    
                    // Recognition level info
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Using accurate recognition for best results")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
                
                if viewModel.processingProgress == 1.0 {
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