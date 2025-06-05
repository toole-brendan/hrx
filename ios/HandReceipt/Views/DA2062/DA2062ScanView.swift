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
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var showingImagePicker = false
    
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
                DA2062ImportProgressView(sourceImage: scannerViewModel.lastProcessedImage ?? UIImage())
            }
            .sheet(isPresented: $showingReviewSheet) {
                if let form = parsedForm {
                    DA2062ReviewSheet(
                        parsedForm: form,
                        onImport: handleImport,
                        onCancel: { showingReviewSheet = false }
                    )
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet()
            }
            .photosPicker(isPresented: $showingImagePicker, selection: $selectedImageItem, matching: .images)
            .onChange(of: selectedImageItem) { item in
                loadSelectedImage(item)
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
                    showingImagePicker = true
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
                InfoRow(icon: "3.circle.fill", text: "Review and edit recognized items")
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
    
    private func InfoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
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
    
    private func loadSelectedImage(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
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
        scannerViewModel.processScannedDocuments([image])
        showingProcessingView = true
    }
    
    private func handleImport(_ items: [EditableDA2062Item]) {
        showingReviewSheet = false
        isImporting = true
        
        Task {
            do {
                // Convert to batch import format
                let batchItems = items.filter(\.isSelected).map { item in
                    DA2062BatchItem(
                        name: item.description,
                        description: item.description,
                        serialNumber: item.serialNumber.isEmpty ? nil : item.serialNumber,
                        nsn: item.nsn.isEmpty ? nil : item.nsn,
                        quantity: Int(item.quantity) ?? 1,
                        unit: item.unit,
                        category: "Equipment",
                        importMetadata: BatchImportMetadata(
                            confidence: item.confidence,
                            requiresVerification: item.needsVerification,
                            verificationReasons: item.needsVerification ? ["Manual review required"] : nil,
                            sourceDocumentUrl: nil,
                            originalQuantity: Int(item.quantity) ?? 1,
                            quantityIndex: nil
                        )
                    )
                }
                
                let response = try await APIService.shared.importDA2062Items(
                    items: batchItems,
                    source: useAzureOCR ? "azure_ocr_ios" : "local_ocr_ios",
                    sourceReference: parsedForm?.formNumber
                )
                
                await MainActor.run {
                    isImporting = false
                    // Handle successful import
                    handleImportSuccess(response)
                }
                
            } catch {
                await MainActor.run {
                    isImporting = false
                    importError = error.localizedDescription
                }
            }
        }
    }
    
    private func handleImportSuccess(_ response: BatchImportResponse) {
        if response.createdCount > 0 {
            // Show success message
            print("✅ Successfully imported \(response.createdCount) items to inventory with ledger logging")
        }
        
        if response.failedCount > 0 {
            importError = "Partial success: \(response.createdCount) items imported, \(response.failedCount) failed"
        }
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

 