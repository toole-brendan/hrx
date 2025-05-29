import SwiftUI
import AVFoundation
import CoreImage

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: QRScannerViewModel
    
    init(apiService: APIServiceProtocol? = nil) {
        let service = apiService ?? APIService()
        self._viewModel = StateObject(wrappedValue: QRScannerViewModel(apiService: service))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera View
                CameraPreview(session: viewModel.captureSession)
                    .ignoresSafeArea()
                    .onAppear {
                        viewModel.startScanning()
                    }
                    .onDisappear {
                        viewModel.stopScanning()
                    }
                
                // Scanning Overlay
                scanningOverlay
                
                // Bottom Info Panel
                VStack {
                    Spacer()
                    infoPanel
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.toggleFlash() }) {
                        Image(systemName: viewModel.isFlashOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") {
                    viewModel.showingError = false
                    viewModel.startScanning() // Resume scanning
                }
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(isPresented: $viewModel.showingTransferConfirmation) {
                if let property = viewModel.scannedProperty {
                    TransferConfirmationView(
                        property: property,
                        viewModel: viewModel,
                        onConfirm: {
                            Task {
                                await initiateTransfer(for: property)
                            }
                        },
                        onCancel: {
                            viewModel.showingTransferConfirmation = false
                            viewModel.startScanning() // Resume scanning
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Scanning Overlay
    private var scanningOverlay: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width * 0.7, 280)
            let offsetY = -50 // Move scanning area up slightly
            
            ZStack {
                // Dark overlay with cutout
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .mask(
                        ZStack {
                            Rectangle()
                            
                            RoundedRectangle(cornerRadius: 20)
                                .frame(width: size, height: size)
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + CGFloat(offsetY))
                                .blendMode(.destinationOut)
                        }
                    )
                
                // Scanning frame
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.accent, lineWidth: 3)
                    .frame(width: size, height: size)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + CGFloat(offsetY))
                
                // Corner markers
                ForEach(0..<4) { index in
                    CornerMarker()
                        .stroke(AppColors.accent, lineWidth: 4)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(Double(index) * 90))
                        .position(
                            x: geometry.size.width / 2 + (index % 2 == 0 ? -size/2 : size/2),
                            y: geometry.size.height / 2 + CGFloat(offsetY) + (index < 2 ? -size/2 : size/2)
                        )
                }
                
                // Scanning animation
                if viewModel.isScanning {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppColors.accent.opacity(0),
                                    AppColors.accent.opacity(0.5),
                                    AppColors.accent.opacity(0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size - 40, height: 2)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + CGFloat(offsetY))
                        .offset(y: viewModel.scanLineOffset)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true),
                            value: viewModel.scanLineOffset
                        )
                        .onAppear {
                            viewModel.scanLineOffset = size / 2 - 20
                        }
                }
            }
        }
    }
    
    // MARK: - Info Panel
    private var infoPanel: some View {
        VStack(spacing: 16) {
            if viewModel.isProcessing {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Processing QR Code...")
                        .font(AppFonts.body)
                        .foregroundColor(.white)
                }
            } else {
                Text("Scan property QR code to request transfer")
                    .font(AppFonts.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Position QR code within the frame")
                    .font(AppFonts.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .padding()
    }
    
    // MARK: - Transfer Initiation
    private func initiateTransfer(for property: ScannedPropertyInfo) async {
        viewModel.showingTransferConfirmation = false
        
        do {
            let transfer = try await viewModel.initiateTransfer(for: property)
            // Show success and dismiss
            await MainActor.run {
                dismiss()
                // TODO: Navigate to transfer detail or show success notification
            }
        } catch {
            await MainActor.run {
                viewModel.errorMessage = "Failed to initiate transfer: \(error.localizedDescription)"
                viewModel.showingError = true
            }
        }
    }
}

// MARK: - Transfer Confirmation View

struct TransferConfirmationView: View {
    let property: ScannedPropertyInfo
    @ObservedObject var viewModel: QRScannerViewModel
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Property Info
                    VStack(spacing: 16) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.accent)
                        
                        Text("Transfer Request")
                            .font(AppFonts.title)
                            .foregroundColor(AppColors.primaryText)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            PropertyInfoRow(label: "Item", value: property.itemName)
                            PropertyInfoRow(label: "Serial #", value: property.serialNumber)
                            PropertyInfoRow(label: "Category", value: property.category.capitalized)
                            PropertyInfoRow(label: "Current Holder", value: property.currentHolderName ?? "User #\(property.currentHolderId)")
                        }
                        .padding()
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    // Confirmation Text
                    Text("Are you sure you want to request transfer of this property?")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: onConfirm) {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Confirm Transfer Request")
                                    .font(AppFonts.bodyBold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.primary)
                        .disabled(viewModel.isProcessing)
                        
                        Button(action: onCancel) {
                            Text("Cancel")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.accent)
                                .frame(maxWidth: .infinity)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

struct PropertyInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.secondaryText)
            Spacer()
            Text(value)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer else { return }
        previewLayer.frame = uiView.bounds
    }
}

// MARK: - Corner Marker Shape

struct CornerMarker: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = 15
        
        // Top-left corner
        path.move(to: CGPoint(x: 0, y: length))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: length, y: 0))
        
        return path
    }
}

// MARK: - View Model

@MainActor
class QRScannerViewModel: NSObject, ObservableObject {
    let apiService: APIServiceProtocol
    let captureSession = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var videoDevice: AVCaptureDevice?
    
    @Published var isScanning = false
    @Published var isProcessing = false
    @Published var isFlashOn = false
    @Published var scanLineOffset: CGFloat = -140
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var scannedProperty: ScannedPropertyInfo?
    @Published var showingTransferConfirmation = false
    
    private var lastScannedCode: String?
    private var scanDebounceTimer: Timer?
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession.beginConfiguration()
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            errorMessage = "Camera not available"
            showingError = true
            return
        }
        
        self.videoDevice = videoDevice
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }
        
        captureSession.commitConfiguration()
    }
    
    func startScanning() {
        guard !captureSession.isRunning else { return }
        
        Task { @MainActor in
            isScanning = true
            lastScannedCode = nil
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func stopScanning() {
        guard captureSession.isRunning else { return }
        
        isScanning = false
        captureSession.stopRunning()
        scanDebounceTimer?.invalidate()
    }
    
    func toggleFlash() {
        guard let device = videoDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            isFlashOn.toggle()
            device.torchMode = isFlashOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Failed to toggle flash: \(error)")
        }
    }
    
    func processQRCode(_ code: String) async -> ScannedPropertyInfo? {
        // Prevent processing the same code multiple times
        guard code != lastScannedCode else { return nil }
        lastScannedCode = code
        
        isProcessing = true
        defer { 
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        do {
            // Parse QR code data
            guard let data = code.data(using: .utf8),
                  let qrData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  qrData["type"] as? String == "handreceipt_property",
                  let itemId = qrData["itemId"] as? String,
                  let serialNumber = qrData["serialNumber"] as? String,
                  let itemName = qrData["itemName"] as? String,
                  let category = qrData["category"] as? String,
                  let currentHolderId = qrData["currentHolderId"] as? String else {
                throw QRError.invalidFormat
            }
            
            // Verify QR hash
            guard let qrHash = qrData["qrHash"] as? String else {
                throw QRError.missingHash
            }
            
            // TODO: Verify hash matches computed hash
            
            return ScannedPropertyInfo(
                itemId: itemId,
                serialNumber: serialNumber,
                itemName: itemName,
                category: category,
                currentHolderId: currentHolderId,
                qrData: qrData
            )
        } catch {
            await MainActor.run {
                errorMessage = "Invalid QR code format"
                showingError = true
            }
            return nil
        }
    }
    
    func initiateTransfer(for property: ScannedPropertyInfo) async throws -> Transfer {
        // Use the QR transfer API endpoint
        let response = try await apiService.initiateQRTransfer(
            qrData: property.qrData,
            scannedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        // Since the QR transfer returns a transferId, we need to fetch the actual transfer
        // This would need to be implemented if needed, for now return a mock transfer
        // In a real implementation, you might want to fetch the transfer by ID
        return Transfer(
            id: response.transferId,
            propertyId: Int(property.itemId) ?? 0,
            propertySerialNumber: property.serialNumber,
            propertyName: property.itemName,
            fromUserId: Int(property.currentHolderId) ?? 0,
            toUserId: 0, // Would be set by the API
            status: .PENDING,
            requestTimestamp: Date(),
            approvalTimestamp: nil,
            fromUser: nil,
            toUser: nil,
            notes: "Transfer initiated via QR scan"
        )
    }
}

// MARK: - QR Code Scanning Delegate

extension QRScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else { return }
        
        Task { @MainActor in
            guard isScanning, !isProcessing else { return }
            
            // Debounce rapid scans
            scanDebounceTimer?.invalidate()
            scanDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                self.lastScannedCode = nil
            }
            
            // Stop scanning temporarily
            stopScanning()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Process the QR code
            if let property = await processQRCode(stringValue) {
                // Get property owner name if possible
                if let holderId = Int(property.currentHolderId) {
                    do {
                        let users = try await apiService.fetchUsers(searchQuery: nil)
                        if let holder = users.first(where: { $0.id == holderId }) {
                            var updatedProperty = property
                            updatedProperty.currentHolderName = "\(holder.rank ?? "") \(holder.lastName ?? "")"
                            
                            // Show confirmation sheet
                            self.scannedProperty = updatedProperty
                            self.showingTransferConfirmation = true
                            return
                        }
                    } catch {
                        print("Failed to fetch user info: \(error)")
                    }
                }
                
                // Show confirmation without holder name
                self.scannedProperty = property
                self.showingTransferConfirmation = true
            } else {
                // Resume scanning if processing failed
                startScanning()
            }
        }
    }
}

// MARK: - Supporting Types

struct ScannedPropertyInfo {
    let itemId: String
    let serialNumber: String
    let itemName: String
    let category: String
    let currentHolderId: String
    let qrData: [String: Any]
    var currentHolderName: String?
}

enum QRError: Error {
    case invalidFormat
    case missingHash
    case invalidData
    case scanningError(String)
}

// MARK: - Previews

struct QRScannerView_Previews: PreviewProvider {
    static var previews: some View {
        QRScannerView(apiService: MockAPIService())
            .preferredColorScheme(.dark)
    }
} 