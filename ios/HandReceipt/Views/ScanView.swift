import SwiftUI

// This is the view shown when tapping the "Scan" tab in the tab bar
struct ScanTabPlaceholderView: View {
    @State private var showingQRScanner = false
    @State private var animationAmount: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Animated QR icon
                ZStack {
                    // Background rings
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(AppColors.accent.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                            .frame(width: CGFloat(120 + index * 40), height: CGFloat(120 + index * 40))
                            .scaleEffect(animationAmount)
                            .opacity(2 - animationAmount)
                            .animation(
                                Animation.easeOut(duration: 2)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.4),
                                value: animationAmount
                            )
                    }
                    
                    // Main icon container
                    ZStack {
                        Rectangle()
                            .fill(AppColors.secondaryBackground)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Rectangle()
                                    .stroke(AppColors.accent, lineWidth: 2)
                            )
                        
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.accent)
                    }
                }
                .onAppear {
                    animationAmount = 2.0
                }
                
                // Instructions
                VStack(spacing: 16) {
                    Text("SCAN QR CODE")
                        .font(AppFonts.title)
                        .foregroundColor(AppColors.primaryText)
                        .tracking(AppFonts.militaryTracking)
                    
                    Text("Scan property QR codes to initiate transfers")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Action button
                Button(action: { showingQRScanner = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                        Text("OPEN SCANNER")
                            .tracking(AppFonts.militaryTracking)
                    }
                    .font(AppFonts.bodyBold)
                    .frame(width: 200)
                }
                .buttonStyle(.primary)
                
                // Alternative actions
                HStack(spacing: 32) {
                    Button(action: {
                        // TODO: Navigate to manual entry
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "keyboard")
                                .font(.title2)
                                .foregroundColor(AppColors.accent)
                            Text("MANUAL ENTRY")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .tracking(AppFonts.normalTracking)
                        }
                    }
                    
                    Button(action: {
                        // TODO: Show recent scans
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title2)
                                .foregroundColor(AppColors.accent)
                            Text("RECENT SCANS")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .tracking(AppFonts.normalTracking)
                        }
                    }
                }
                .padding(.top, 20)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingQRScanner) {
            QRScannerView()
        }
    }
}

// MARK: - Original ScanView for direct camera scanning (kept for compatibility)
struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @State private var isScanningActive: Bool = true
    @State private var showingUserSelection = false
    @State private var selectedProperty: Property?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Camera View background
            CameraView(scannedCode: $viewModel.scannedCodeFromCamera, isScanning: $isScanningActive)
                .edgesIgnoringSafeArea(.all)
                .onChange(of: viewModel.scanState) { newState in
                    isScanningActive = (newState == .scanning)
                }

            // Dimming overlay when not actively scanning
            if !isScanningActive {
                Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
            }

            // UI Overlays
            ScanStatusOverlay(
                scanState: viewModel.scanState,
                onScanAgain: { viewModel.scanAgain() },
                onConfirm: { property in
                    selectedProperty = property
                    showingUserSelection = true
                }
            )
            
            ScanTransferStatusMessage(state: viewModel.transferRequestState)
        }
        .navigationTitle("SCAN ITEM")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("CANCEL") {
                    viewModel.scanAgain()
                    isScanningActive = false
                    presentationMode.wrappedValue.dismiss()
                }
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.accent)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            isScanningActive = true
            if viewModel.scanState != .scanning {
                viewModel.scanAgain()
            }
        }
        .onDisappear {
            isScanningActive = false
        }
        .sheet(isPresented: $showingUserSelection) {
            NavigationView {
                UserSelectionView(onUserSelected: { selectedUser in
                    if selectedProperty != nil {
                        viewModel.initiateTransfer(targetUser: selectedUser)
                    }
                    showingUserSelection = false
                })
            }
            .accentColor(AppColors.accent)
        }
    }
}

// MARK: - Scan Status Overlay with Industrial Design
struct ScanStatusOverlay: View {
    let scanState: ScanState
    let onScanAgain: () -> Void
    let onConfirm: (Property) -> Void

    var body: some View {
        VStack {
            Spacer()

            Group {
                switch scanState {
                case .scanning:
                    statusCard(
                        icon: "viewfinder",
                        text: "POSITION CAMERA AT SERIAL NUMBER",
                        subtext: "Align barcode or text within frame",
                        color: AppColors.accent
                    )

                case .loading:
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SEARCHING DATABASE...")
                                .font(AppFonts.bodyBold)
                                .foregroundColor(AppColors.primaryText)
                                .tracking(AppFonts.militaryTracking)
                            Text("Verifying serial number")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppColors.secondaryBackground)
                    .overlay(
                        Rectangle()
                            .stroke(AppColors.accent, lineWidth: 1)
                    )

                case .success(let property):
                    VStack(spacing: 16) {
                        PropertyDetailsCard(property: property)
                        
                        HStack(spacing: 16) {
                            Button("SCAN AGAIN", role: .cancel) {
                                onScanAgain()
                            }
                            .buttonStyle(.secondary)
                            .frame(maxWidth: .infinity)

                            Button("REQUEST TRANSFER") {
                                onConfirm(property)
                            }
                            .buttonStyle(.primary)
                            .frame(maxWidth: .infinity)
                        }
                    }

                case .notFound:
                    VStack(spacing: 16) {
                        statusCard(
                            icon: "questionmark.circle",
                            text: "ITEM NOT FOUND",
                            subtext: "Serial number not in database",
                            color: AppColors.warning
                        )
                        
                        Button("SCAN AGAIN", action: onScanAgain)
                            .buttonStyle(.secondary)
                    }

                case .error(let message):
                    VStack(spacing: 16) {
                        statusCard(
                            icon: "exclamationmark.triangle.fill",
                            text: "SCAN ERROR",
                            subtext: message,
                            color: AppColors.destructive
                        )
                        
                        Button("TRY AGAIN", action: onScanAgain)
                            .buttonStyle(.secondary)
                    }
                }
            }
            .padding()
            .animation(.spring(), value: scanState)
        }
    }
    
    @ViewBuilder
    private func statusCard(icon: String, text: String, subtext: String, color: Color) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                        .tracking(AppFonts.militaryTracking)
                    
                    Text(subtext)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .stroke(color.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Property Details Card with Industrial Design
struct PropertyDetailsCard: View {
    let property: Property

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                Text("ITEM VERIFIED")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.success)
                    .tracking(AppFonts.militaryTracking)
                Spacer()
            }
            .padding()
            .background(AppColors.success.opacity(0.1))
            .overlay(
                Rectangle()
                    .stroke(AppColors.success.opacity(0.3), lineWidth: 1),
                alignment: .bottom
            )
            
            // Property details
            VStack(spacing: 12) {
                ScanDetailRow(label: "NSN", value: property.nsn)
                Rectangle().fill(AppColors.border).frame(height: 1)
                ScanDetailRow(label: "NAME", value: property.itemName.uppercased())
                Rectangle().fill(AppColors.border).frame(height: 1)
                ScanDetailRow(label: "SERIAL", value: property.serialNumber)
                Rectangle().fill(AppColors.border).frame(height: 1)
                ScanDetailRow(label: "STATUS", value: property.status.uppercased())
            }
            .padding()
        }
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Transfer Status Message
struct ScanTransferStatusMessage: View {
    let state: TransferRequestState
    
    var body: some View {
        VStack {
            if state != .idle {
                VStack(spacing: 12) {
                    switch state {
                    case .idle:
                        EmptyView()
                        
                    case .loading:
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("INITIATING TRANSFER...")
                                .font(AppFonts.bodyBold)
                                .foregroundColor(.white)
                                .tracking(AppFonts.militaryTracking)
                        }
                        
                    case .success:
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            Text("TRANSFER REQUEST SENT")
                                .font(AppFonts.bodyBold)
                                .foregroundColor(.white)
                                .tracking(AppFonts.militaryTracking)
                        }
                        
                    case .error(let message):
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                            Text(message.uppercased())
                                .font(AppFonts.bodyBold)
                                .foregroundColor(.white)
                                .tracking(AppFonts.militaryTracking)
                        }
                    }
                }
                .padding()
                .background(
                    state == .error("") ? AppColors.destructive : AppColors.accent
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
        .animation(.spring(), value: state)
    }
}

// MARK: - Detail Row Component
struct ScanDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .font(AppFonts.captionBold)
                .foregroundColor(AppColors.tertiaryText)
                .tracking(AppFonts.militaryTracking)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1)
            
            Spacer()
        }
    }
}

// MARK: - Previews

struct ScanView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Scan tab placeholder
            NavigationView {
                ScanTabPlaceholderView()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Scan Tab")
            
            // Direct scan view
            NavigationView {
                ScanView()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Direct Scan")
        }
    }
} 