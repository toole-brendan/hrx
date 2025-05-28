import SwiftUI

struct ScanView: View {
    // Use @StateObject because this View owns the ViewModel
    @StateObject private var viewModel = ScanViewModel()
    
    // Keep isScanning state local to control the CameraView representation
    // This is needed because the CameraView itself needs a binding to control start/stop
    @State private var isScanningActive: Bool = true 
    @State private var showingUserSelection = false // State for sheet presentation

    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        // NavigationView styling is handled globally
        ZStack {
            // Camera View background
            CameraView(scannedCode: $viewModel.scannedCodeFromCamera, isScanning: $isScanningActive)
                .edgesIgnoringSafeArea(.all)
                .onChange(of: viewModel.scanState) { newState in
                    isScanningActive = (newState == .scanning)
                }

            // Dimming overlay when not actively scanning (optional, for visual focus)
            if !isScanningActive {
                 Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
            }

            // UI Overlays
            ScanStatusOverlay(
                scanState: viewModel.scanState, 
                onScanAgain: { viewModel.scanAgain() },
                onConfirm: { property in
                    showingUserSelection = true
                }
            )
            
            TransferStatusMessage(state: viewModel.transferRequestState)
        }
        // Removed redundant NavigationView wrapper here, assuming presented modally
        // or within an existing NavigationView from AuthenticatedTabView
        .navigationTitle("Scan Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { // Use .toolbar modifier
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { 
                    viewModel.scanAgain()
                    isScanningActive = false
                    presentationMode.wrappedValue.dismiss()
                }
                // Font/Color applied globally by AuthenticatedTabView's appearance setup
            }
        }
        .background(Color.black.ignoresSafeArea()) // Ensure background is black behind camera
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
                    viewModel.initiateTransfer(targetUser: selectedUser)
                    showingUserSelection = false 
                })
                // Appearance should be inherited from global settings
                // .navigationTitle("Select User for Transfer")
                // .navigationBarTitleDisplayMode(.inline)
                // .toolbar { 
                //     ToolbarItem(placement: .navigationBarLeading) {
                //         Button("Cancel") { showingUserSelection = false }
                //             .font(AppFonts.body) // Apply font
                //             .foregroundColor(AppColors.accent) // Apply color
                //     }
                // }
            }
            .accentColor(AppColors.accent) 
        }
    }
}

// Separate Overlay View for clarity
struct ScanStatusOverlay: View {
    let scanState: ScanState
    let onScanAgain: () -> Void
    let onConfirm: (Property) -> Void // Add confirmation callback

    var body: some View {
        VStack {
            Spacer() // Push to bottom

            Group { // Group helps apply modifiers commonly
                switch scanState {
                case .scanning:
                    statusMessage(text: "Point camera at barcode or serial number", icon: "viewfinder", color: AppColors.secondaryText)

                case .loading:
                     ProgressView {
                         Text("Looking up item...")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.primaryText)
                     }
                     .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                     .padding()
                     .background(AppColors.secondaryBackground.opacity(0.8))
                     .cornerRadius(10)

                case .success(let property):
                    PropertyDetailsCard(property: property) // Already themed
                    
                    HStack(spacing: 15) { 
                        Button("Scan Again", role: .cancel) {
                            onScanAgain()
                        }
                        .buttonStyle(.bordered) // Use bordered for secondary action
                        .tint(AppColors.secondaryText) // Themed tint for border/text
                        .font(AppFonts.body) // Apply theme font
                        .frame(maxWidth: .infinity)

                        Button("Confirm & Transfer") { 
                            onConfirm(property)
                        }
                        .buttonStyle(.primary) // Use primary for main action
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 10)

                case .notFound:
                    statusMessage(text: "Item not found in database.", icon: "questionmark.circle", color: .orange) // Keep orange distinct?
                    Spacer().frame(height: 10)
                    Button("Scan Again", action: onScanAgain)
                        .buttonStyle(.bordered)
                        .tint(AppColors.secondaryText)
                        .font(AppFonts.body)

                case .error(let message):
                    statusMessage(text: "Error: \(message)", icon: "exclamationmark.triangle.fill", color: AppColors.destructive)
                    Spacer().frame(height: 10)
                    Button("Try Again", action: onScanAgain)
                        .buttonStyle(.bordered)
                        .tint(AppColors.secondaryText)
                        .font(AppFonts.body)
                }
            }
            .padding(.bottom)
        }
        .padding()
        .animation(.spring(), value: scanState) // Animate state changes
    }
    
    // Helper for consistent status message display
    @ViewBuilder
    private func statusMessage(text: String, icon: String?, color: Color) -> some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(text)
                .font(AppFonts.caption) // Use caption font
                .multilineTextAlignment(.center)
        }
        .padding()
        .foregroundColor(AppColors.primaryText) // Consistent text color
        .background(AppColors.secondaryBackground.opacity(0.9)) // Dark background
        .cornerRadius(10)
        // Use a neutral shadow or remove if too noisy
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }
}

// Simple Card View
struct PropertyDetailsCard: View {
    let property: Property

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Item Found")
                .font(AppFonts.headline) // Use theme font
                .foregroundColor(AppColors.primaryText)
                .padding(.bottom, 4)
            Divider().background(AppColors.secondaryText.opacity(0.5))
            detailRow(label: "NSN", value: property.nsn)
            detailRow(label: "Name", value: property.itemName)
            detailRow(label: "Serial Nr", value: property.serialNumber)
            detailRow(label: "Status", value: property.status.capitalized)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondaryBackground.opacity(0.8))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.secondaryText.opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(AppFonts.captionBold) // Use theme font
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 70, alignment: .leading) // Align labels
            Text(value)
                .font(AppFonts.caption) // Use theme font
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1) // Prevent long values wrapping poorly
        }
    }
}

// Separate view for overlaying transfer status/errors
struct TransferStatusMessage: View {
    let state: ScanViewModel.TransferRequestState
    
    var body: some View {
        VStack {
            Spacer() // Push to bottom
             if state != .idle { // Only show if not idle
                 HStack(spacing: 10) {
                     if state == .loading {
                         ProgressView()
                             .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                     } else {
                         Image(systemName: state.iconName)
                             .foregroundColor(state.iconColor) // Use themed color from extension
                     }
                     Text(state.message)
                         .font(AppFonts.caption) // Use theme font
                         .foregroundColor(AppColors.primaryText)
                         .lineLimit(2)
                 }
                 .padding()
                 .background(state.backgroundColor) // Use themed background from extension
                 .cornerRadius(10)
                 .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                 .transition(.move(edge: .bottom).combined(with: .opacity))
                 .padding(.bottom, 80) // Position above ScanStatusOverlay
             }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(), value: state)
    }
}

// Add helper extensions for TransferRequestState styling
extension ScanViewModel.TransferRequestState {
    var message: String {
        switch self {
            case .idle: return ""
            case .loading: return "Requesting Transfer..."
            case .success(let transfer): return "Transfer #\(transfer.id) Requested!"
            case .error(let msg): return "Transfer Error: \(msg)"
        }
    }

    var iconName: String {
        switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            default: return ""
        }
    }

    var iconColor: Color {
        switch self {
            case .success: return AppColors.accent // Use theme accent for success
            case .error: return AppColors.destructive
            default: return .clear
        }
    }
    
    var backgroundColor: Color {
         switch self {
            case .loading:
                return AppColors.secondaryBackground.opacity(0.9)
            case .success:
                return AppColors.accent.opacity(0.8) // Use theme accent background
            case .error:
                 return AppColors.destructive.opacity(0.8)
             case .idle:
                 return Color.clear
         }
     }
}

struct ScanView_Previews: PreviewProvider {
    static var previews: some View {
        // Wrap in NavView for preview context
        NavigationView {
            ScanView()
        }
        .preferredColorScheme(.dark) // Preview in dark mode
    }
} 