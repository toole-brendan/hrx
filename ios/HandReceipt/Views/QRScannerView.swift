import SwiftUI
import CoreImage

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: QRScannerViewModel
    @State private var scannedCode: String?
    @State private var isScanningActive = true
    
    init(apiService: APIServiceProtocol? = nil) {
        let service = apiService ?? APIService()
        self._viewModel = StateObject(wrappedValue: QRScannerViewModel(apiService: service))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Use shared CameraView component
                CameraView(
                    scannedCode: $scannedCode,
                    isScanning: $isScanningActive
                )
                .ignoresSafeArea()
                .onChange(of: scannedCode) { newCode in
                    if let code = newCode {
                        handleScannedCode(code)
                    }
                }
                
                // Scanning Overlay with industrial design
                scanningOverlay
                
                // Bottom Control Panel
                VStack {
                    Spacer()
                    controlPanel
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
            .overlay(customNavigationBar, alignment: .top)
            .onAppear {
                isScanningActive = true
                viewModel.isScanning = true
            }
            .onDisappear {
                isScanningActive = false
                viewModel.isScanning = false
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") {
                    viewModel.showingError = false
                    scannedCode = nil
                    isScanningActive = true
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
                            scannedCode = nil
                            isScanningActive = true
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Handle Scanned Code
    private func handleScannedCode(_ code: String) {
        // Stop scanning while processing
        isScanningActive = false
        
        Task {
            await viewModel.processQRCode(code)
        }
    }
    
    // MARK: - Custom Navigation Bar
    private var customNavigationBar: some View {
        HStack {
            Button("CANCEL") {
                dismiss()
            }
            .font(AppFonts.bodyBold)
            .foregroundColor(.white)
            .tracking(AppFonts.militaryTracking)
            
            Spacer()
            
            Text("SCAN QR CODE")
                .font(AppFonts.headline)
                .foregroundColor(.white)
                .tracking(AppFonts.militaryTracking)
            
            Spacer()
            
            // Space for symmetry (flash control removed as CameraView doesn't support it)
            Color.clear
                .frame(width: 60)
        }
        .padding(.horizontal)
        .padding(.top, 50) // Account for status bar
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.8),
                    Color.black.opacity(0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Scanning Overlay
    private var scanningOverlay: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width * 0.75, 300)
            let centerY = geometry.size.height / 2 - 40
            
            ZStack {
                // Dark overlay with cutout
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .mask(
                        ZStack {
                            Rectangle()
                            
                            // Square cutout with industrial corners
                            Rectangle()
                                .frame(width: size, height: size)
                                .position(x: geometry.size.width / 2, y: centerY)
                                .blendMode(.destinationOut)
                        }
                    )
                
                // Scanning frame with industrial styling
                Rectangle()
                    .stroke(AppColors.accent, lineWidth: 2)
                    .frame(width: size, height: size)
                    .position(x: geometry.size.width / 2, y: centerY)
                
                // Corner brackets
                ForEach(0..<4) { index in
                    IndustrialCornerBracket(cornerIndex: index)
                        .stroke(AppColors.accent, lineWidth: 4)
                        .frame(width: 60, height: 60)
                        .position(
                            x: geometry.size.width / 2 + (index % 2 == 0 ? -size/2 : size/2),
                            y: centerY + (index < 2 ? -size/2 : size/2)
                        )
                }
                
                // Grid overlay for industrial feel
                if viewModel.isScanning && isScanningActive {
                    GridOverlay(size: size)
                        .position(x: geometry.size.width / 2, y: centerY)
                        .opacity(0.3)
                }
                
                // Scanning animation
                if viewModel.isScanning && !viewModel.isProcessing && isScanningActive {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppColors.accent.opacity(0),
                                    AppColors.accent.opacity(0.6),
                                    AppColors.accent.opacity(0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size - 40, height: 4)
                        .position(x: geometry.size.width / 2, y: centerY)
                        .offset(y: viewModel.scanLineOffset)
                        .animation(
                            Animation.linear(duration: 2)
                                .repeatForever(autoreverses: true),
                            value: viewModel.scanLineOffset
                        )
                        .onAppear {
                            viewModel.scanLineOffset = size / 2 - 20
                        }
                }
                
                // Center crosshair
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .thin))
                    .foregroundColor(AppColors.accent.opacity(0.5))
                    .position(x: geometry.size.width / 2, y: centerY)
            }
        }
    }
    
    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 0) {
            // Status indicator
            statusIndicator
            
            // Info panel
            VStack(spacing: 16) {
                if viewModel.isProcessing {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        Text("VERIFYING QR CODE...")
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.primaryText)
                            .tracking(AppFonts.militaryTracking)
                    }
                    .padding()
                } else {
                    VStack(spacing: 8) {
                        Text("POSITION QR CODE WITHIN FRAME")
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.primaryText)
                            .tracking(AppFonts.militaryTracking)
                        
                        Text("Scan property QR code to request transfer")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding()
                }
                
                // Manual entry option
                Button(action: {
                    // TODO: Implement manual serial number entry
                }) {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("ENTER MANUALLY")
                            .tracking(AppFonts.militaryTracking)
                    }
                    .font(AppFonts.captionBold)
                    .foregroundColor(AppColors.accent)
                }
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .background(AppColors.secondaryBackground)
            .overlay(
                Rectangle()
                    .stroke(AppColors.border, lineWidth: 1),
                alignment: .top
            )
        }
    }
    
    // MARK: - Status Indicator
    private var statusIndicator: some View {
        HStack(spacing: 12) {
            // Scanner status LED
            Circle()
                .fill(isScanningActive ? AppColors.success : AppColors.destructive)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(isScanningActive ? AppColors.success : AppColors.destructive, lineWidth: 1)
                        .frame(width: 12, height: 12)
                )
            
            Text(isScanningActive ? "SCANNER ACTIVE" : "SCANNER PAUSED")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .tracking(AppFonts.militaryTracking)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(AppColors.mutedBackground)
    }
    
    // MARK: - Transfer Initiation
    private func initiateTransfer(for property: ScannedPropertyInfo) async {
        viewModel.showingTransferConfirmation = false
        
        do {
            let _ = try await viewModel.initiateTransfer(for: property)
            await MainActor.run {
                dismiss()
                // Success feedback would be shown by parent view
            }
        } catch {
            await MainActor.run {
                viewModel.errorMessage = "Failed to initiate transfer: \(error.localizedDescription)"
                viewModel.showingError = true
                // Reset scanning
                scannedCode = nil
                isScanningActive = true
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
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Rectangle()
                                .fill(AppColors.success.opacity(0.1))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Rectangle()
                                        .stroke(AppColors.success.opacity(0.3), lineWidth: 2)
                                )
                            
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.success)
                        }
                        
                        Text("QR CODE VERIFIED")
                            .font(AppFonts.headline)
                            .foregroundColor(AppColors.success)
                            .tracking(AppFonts.militaryTracking)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.secondaryBackground)
                    .overlay(
                        Rectangle()
                            .stroke(AppColors.border, lineWidth: 1),
                        alignment: .bottom
                    )
                    
                    // Property Information
                    VStack(spacing: 0) {
                        sectionHeader(title: "PROPERTY INFORMATION")
                        
                        VStack(spacing: 16) {
                            PropertyInfoRow(label: "ITEM NAME", value: property.itemName)
                            Rectangle().fill(AppColors.border).frame(height: 1)
                            PropertyInfoRow(label: "SERIAL NUMBER", value: property.serialNumber, isMonospaced: true)
                            Rectangle().fill(AppColors.border).frame(height: 1)
                            PropertyInfoRow(label: "CATEGORY", value: property.category.uppercased())
                            Rectangle().fill(AppColors.border).frame(height: 1)
                            PropertyInfoRow(
                                label: "CURRENT HOLDER",
                                value: property.currentHolderName ?? "USER #\(property.currentHolderId)"
                            )
                        }
                        .padding()
                        .background(AppColors.secondaryBackground)
                    }
                    
                    Spacer()
                    
                    // Confirmation message
                    Text("REQUEST TRANSFER OF THIS PROPERTY?")
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                        .tracking(AppFonts.militaryTracking)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    // Action buttons
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(height: 1)
                        
                        HStack(spacing: 0) {
                            Button(action: onCancel) {
                                Text("CANCEL")
                                    .font(AppFonts.bodyBold)
                                    .foregroundColor(AppColors.secondaryText)
                                    .tracking(AppFonts.militaryTracking)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                            
                            Rectangle()
                                .fill(AppColors.border)
                                .frame(width: 1)
                            
                            Button(action: onConfirm) {
                                if viewModel.isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                } else {
                                    Text("CONFIRM TRANSFER")
                                        .font(AppFonts.bodyBold)
                                        .foregroundColor(AppColors.accent)
                                        .tracking(AppFonts.militaryTracking)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                }
                            }
                            .disabled(viewModel.isProcessing)
                        }
                        .background(AppColors.tertiaryBackground)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .tracking(AppFonts.militaryTracking)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(AppColors.mutedBackground)
        .overlay(
            Rectangle()
                .stroke(AppColors.border, lineWidth: 1),
            alignment: .bottom
        )
    }
}

struct PropertyInfoRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.captionBold)
                .foregroundColor(AppColors.tertiaryText)
                .tracking(AppFonts.militaryTracking)
                .frame(width: 140, alignment: .leading)
            
            Text(value)
                .font(isMonospaced ? AppFonts.mono : AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Supporting Shapes

struct IndustrialCornerBracket: Shape {
    let cornerIndex: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = 20
        
        switch cornerIndex {
        case 0: // Top-left
            path.move(to: CGPoint(x: 0, y: length))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: length, y: 0))
        case 1: // Top-right
            path.move(to: CGPoint(x: rect.width - length, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: length))
        case 2: // Bottom-left
            path.move(to: CGPoint(x: 0, y: rect.height - length))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: length, y: rect.height))
        case 3: // Bottom-right
            path.move(to: CGPoint(x: rect.width - length, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - length))
        default:
            break
        }
        
        return path
    }
}

struct GridOverlay: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Horizontal lines
            ForEach(0..<5) { i in
                Rectangle()
                    .fill(AppColors.accent.opacity(0.2))
                    .frame(width: size - 40, height: 0.5)
                    .offset(y: CGFloat(i - 2) * (size / 5))
            }
            
            // Vertical lines
            ForEach(0..<5) { i in
                Rectangle()
                    .fill(AppColors.accent.opacity(0.2))
                    .frame(width: 0.5, height: size - 40)
                    .offset(x: CGFloat(i - 2) * (size / 5))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - View Model

@MainActor
class QRScannerViewModel: ObservableObject {
    let apiService: APIServiceProtocol
    
    @Published var isScanning = true
    @Published var isProcessing = false
    @Published var scanLineOffset: CGFloat = -140
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var scannedProperty: ScannedPropertyInfo?
    @Published var showingTransferConfirmation = false
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    func processQRCode(_ code: String) async {
        // Prevent processing multiple times
        guard !isProcessing else { return }
        
        await MainActor.run {
            isProcessing = true
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
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
            
            // Verify QR hash exists
            guard qrData["qrHash"] != nil else {
                throw QRError.missingHash
            }
            
            // Create scanned property info
            var property = ScannedPropertyInfo(
                itemId: itemId,
                serialNumber: serialNumber,
                itemName: itemName,
                category: category,
                currentHolderId: currentHolderId,
                qrData: qrData
            )
            
            // Try to get property owner name
            if let holderId = Int(currentHolderId) {
                do {
                    let users = try await apiService.fetchUsers(searchQuery: nil)
                    if let holder = users.first(where: { $0.id == holderId }) {
                        property.currentHolderName = "\(holder.rank ?? "") \(holder.lastName ?? "")"
                    }
                } catch {
                    print("Failed to fetch user info: \(error)")
                }
            }
            
            await MainActor.run {
                self.scannedProperty = property
                self.showingTransferConfirmation = true
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Invalid QR code format"
                self.showingError = true
                self.isProcessing = false
            }
        }
    }
    
    func initiateTransfer(for property: ScannedPropertyInfo) async throws -> Transfer {
        isProcessing = true
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        // Use the QR transfer API endpoint
        let response = try await apiService.initiateQRTransfer(
            qrData: property.qrData,
            scannedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        // Return a mock transfer for now
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