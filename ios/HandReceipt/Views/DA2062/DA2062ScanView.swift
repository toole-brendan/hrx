import SwiftUI
import VisionKit
import PhotosUI

struct DA2062ScanView: View {
    @StateObject private var scannerViewModel = DA2062ScanViewModel()
    @State private var showingProcessingView = false
    @State private var showingReviewSheet = false
    @State private var parsedForm: DA2062Form?
    @State private var importError: String?
    @State private var isImporting = false
    @State private var showingSettings = false
    @State private var selectedImageItem: Any? // Will be PhotosPickerItem on iOS 16+
    @State private var showingImagePicker = false
    @State private var showingLegacyImagePicker = false
    @State private var selectedImageChanged = false // Helper for onChange
    @State private var scannedPages: [DA2062DocumentScannerViewModel.ScannedPage] = []
    @State private var showingImportProgress = false
    
    // OCR Mode Settings
    @AppStorage("useAzureOCR") private var useAzureOCR = true
    @AppStorage("enableDebugMode") private var enableDebugMode = false
    
    private var scannerAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Navigation Bar with Settings
                HStack {
                    Text("DA 2062 Scanner")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding()
                
                // OCR Mode Indicator
                HStack {
                    Image(systemName: useAzureOCR ? "cloud.fill" : "iphone")
                        .foregroundColor(useAzureOCR ? .blue : .orange)
                    Text(useAzureOCR ? "Azure Computer Vision OCR" : "Local Vision Framework")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Scanner Section
                        if scannerAvailable {
                            ScannerCard()
                        } else {
                            SimulatorTestingCard()
                        }
                        
                        // Sample Image Testing (Debug Mode)
                        if enableDebugMode || !scannerAvailable {
                            SampleImageCard()
                        }
                        
                        // Recent Scans
                        if !scannerViewModel.recentScans.isEmpty {
                            RecentScansCard()
                        }
                        
                        // Information Card
                        InformationCard()
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingProcessingView) {
                OCRProcessingView(
                    sourceImage: scannerViewModel.lastProcessedImage ?? UIImage(),
                    useAzureOCR: useAzureOCR,
                    onCompletion: handleOCRCompletion
                )
            }
            .sheet(isPresented: $showingReviewSheet) {
                if let form = parsedForm {
                    DA2062ReviewSheet(
                        form: form,
                        scannedPages: scannedPages,
                        onConfirm: handleReviewConfirmation
                    )
                }
            }
            .sheet(isPresented: $showingImportProgress) {
                DA2062ImportProgressView(sourceImage: scannerViewModel.lastProcessedImage ?? UIImage())
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet()
            }
            .conditionalPhotosPicker()
            .sheet(isPresented: $showingLegacyImagePicker) {
                LegacyImagePicker { image in
                    processImage(image)
                    showingLegacyImagePicker = false
                }
            }
        }
    }
    
    // MARK: - Scanner Card
    
    @ViewBuilder
    private func ScannerCard() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("Scan DA 2062 Form")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Use your camera to scan a completed DA Form 2062 (Hand Receipt)")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Start Scanning") {
                scannerViewModel.startScanning()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Simulator Testing Card
    
    @ViewBuilder
    private func SimulatorTestingCard() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Simulator Mode")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Camera scanning is not available in the simulator. Use the photo picker to select an image instead.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Button("Choose Image from Photos") {
                    if #available(iOS 16.0, *) {
                        showingImagePicker = true
                    } else {
                        showingLegacyImagePicker = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Use Sample DA 2062") {
                    loadSampleImage()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(24)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Sample Image Card
    
    @ViewBuilder
    private func SampleImageCard() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "testtube.2")
                    .foregroundColor(.purple)
                Text("Testing & Development")
                    .font(.headline)
                    .foregroundColor(.purple)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Test with built-in sample DA 2062 form")
                Text("• Compare Azure OCR vs Local processing")
                Text("• Validate parsing accuracy and performance")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Button("Sample Form (Azure)") {
                    useAzureOCR = true
                    loadSampleImage()
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                
                Button("Sample Form (Local)") {
                    useAzureOCR = false
                    loadSampleImage()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding(16)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Recent Scans Card
    
    @ViewBuilder
    private func RecentScansCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Scans")
                .font(.headline)
            
            ForEach(scannerViewModel.recentScans) { scan in
                RecentScanRow(scan: scan) {
                    // Reprocess this scan
                    scannerViewModel.reprocessScan(scan)
                    showingProcessingView = true
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Information Card
    
    @ViewBuilder
    private func InformationCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("How it Works")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "1.circle.fill", text: "Scan or select your DA 2062 form image")
                InfoRow(icon: "2.circle.fill", text: useAzureOCR ? "Process with Azure Computer Vision" : "Process with local OCR")
                InfoRow(icon: "3.circle.fill", text: "Review and edit recognized items", highlighted: true)
                InfoRow(icon: "4.circle.fill", text: "Import into your property inventory")
                InfoRow(icon: "5.circle.fill", text: "All actions logged to Azure Immutable Ledger")
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Settings Sheet
    
    @ViewBuilder
    private func SettingsSheet() -> some View {
        NavigationView {
            Form {
                Section("OCR Processing") {
                    Toggle("Use Azure Computer Vision", isOn: $useAzureOCR)
                    
                    if useAzureOCR {
                        Label("Cloud-based OCR with superior accuracy", systemImage: "cloud.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Label("On-device processing for privacy", systemImage: "iphone")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Section("Development") {
                    Toggle("Enable Debug Mode", isOn: $enableDebugMode)
                    
                    if enableDebugMode {
                        Label("Shows additional testing options", systemImage: "testtube.2")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("OCR Mode")
                        Spacer()
                        Text(useAzureOCR ? "Azure" : "Local")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Ledger Logging")
                        Spacer()
                        Text("Azure Immutable Ledger")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Scanner Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingSettings = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func InfoRow(icon: String, text: String, highlighted: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(highlighted ? .green : .blue)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(highlighted ? .primary : .secondary)
                .fontWeight(highlighted ? .medium : .regular)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadSampleImage() {
        guard let sampleImage = UIImage(named: "sampleDA2062") else {
            // Create a fallback test image if sample doesn't exist
            createFallbackTestImage()
            return
        }
        
        processImage(sampleImage)
    }
    
    private func createFallbackTestImage() -> Void {
        // Create a simple test image with text if no sample is available
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300))
        let testImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
            
            let text = "DA FORM 2062\nHAND RECEIPT\n\nRIFLE, 5.56MM, M4A1\nNSN: 1005-01-231-0973\nSERIAL: W123456789\nQTY: 1 EA"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]
            
            text.draw(in: CGRect(x: 20, y: 20, width: 360, height: 260), withAttributes: attributes)
        }
        
        processImage(testImage)
    }
    
    @available(iOS 16.0, *)
    private func loadSelectedImage(_ item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    processImage(image)
                }
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        scannerViewModel.lastProcessedImage = image
        
        // Create a scanned page for the review sheet
        scannedPages = [DA2062DocumentScannerViewModel.ScannedPage(
            image: image,
            pageNumber: 1,
            confidence: 0.85
        )]
        
        showingProcessingView = true
    }
    
    private func handleOCRCompletion(result: Result<DA2062Form, Error>) {
        showingProcessingView = false
        
        switch result {
        case .success(let form):
            parsedForm = form
            showingReviewSheet = true
        case .failure(let error):
            importError = error.localizedDescription
            // Handle error - maybe show an alert
            print("OCR processing failed: \(error)")
        }
    }
    
    private func handleReviewConfirmation(_ propertyRequests: [DA2062PropertyRequest]) {
        showingReviewSheet = false
        showingImportProgress = true
        
        // The import progress view will handle the actual import
        // We'll need to pass the confirmed items to it
    }
}

// MARK: - Supporting Views

struct RecentScanRow: View {
    let scan: DA2062Scan
    let onReprocess: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(scan.formNumber ?? "DA 2062")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(scan.itemCount) items • \(scan.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if scan.requiresVerification {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            
            Button("Reprocess") {
                onReprocess()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Legacy Image Picker for iOS < 16.0

struct LegacyImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: LegacyImagePicker
        
        init(_ parent: LegacyImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
        }
    }
}

// MARK: - View Modifier for Conditional PhotosPicker

extension View {
    @ViewBuilder
    func conditionalPhotosPicker() -> some View {
        if #available(iOS 16.0, *) {
            self.modifier(PhotosPickerModifier())
        } else {
            self
        }
    }
}

@available(iOS 16.0, *)
struct PhotosPickerModifier: ViewModifier {
    @State private var selectedItem: PhotosPickerItem?
    
    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: .constant(false), selection: $selectedItem, matching: .images)
    }
}

// MARK: - OCR Processing View

struct OCRProcessingView: View {
    let sourceImage: UIImage
    let useAzureOCR: Bool
    let onCompletion: (Result<DA2062Form, Error>) -> Void
    
    @StateObject private var scanViewModel = DA2062ScanViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var processingStarted = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Processing DA 2062")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                HStack {
                    Image(systemName: useAzureOCR ? "cloud.fill" : "iphone")
                        .foregroundColor(useAzureOCR ? .blue : .orange)
                    Text(useAzureOCR ? "Azure Computer Vision" : "Local Vision Framework")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Processing progress
            VStack(spacing: 16) {
                if scanViewModel.isProcessing {
                    ProgressView(value: scanViewModel.processingProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 8)
                    
                    Text(scanViewModel.processingMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else if !processingStarted {
                    Text("Ready to process document")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                if !processingStarted {
                    Button("Start Processing") {
                        startProcessing()
                    }
                    .buttonStyle(.borderedProminent)
                } else if scanViewModel.isProcessing {
                    Button("Processing...") {
                        // Can't cancel Azure processing once started
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationBarHidden(true)
        .interactiveDismissDisabled(scanViewModel.isProcessing)
    }
    
    private func startProcessing() {
        processingStarted = true
        
        if useAzureOCR {
            // Create a scanned page for Azure processing
            let scannedPage = DA2062DocumentScannerViewModel.ScannedPage(
                image: sourceImage,
                pageNumber: 1,
                confidence: 0.85
            )
            
            Task {
                let result = await scanViewModel.uploadScannedFormToAzure(pages: [scannedPage])
                
                await MainActor.run {
                    switch result {
                    case .success():
                        if let form = scanViewModel.currentForm {
                            onCompletion(.success(form))
                        } else {
                            onCompletion(.failure(NSError(domain: "OCRProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "No form data returned"])))
                        }
                    case .failure(let error):
                        onCompletion(.failure(error))
                    }
                }
            }
        } else {
            // Use local OCR
            scanViewModel.processDA2062(image: sourceImage) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success():
                        if let form = scanViewModel.currentForm {
                            onCompletion(.success(form))
                        } else {
                            onCompletion(.failure(NSError(domain: "OCRProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "No form data returned"])))
                        }
                    case .failure(let error):
                        onCompletion(.failure(error))
                    }
                }
            }
        }
    }
}

 