import SwiftUI

// This is the view shown when tapping the "Request" tab in the tab bar
struct RequestTransferTabView: View {
    @State private var showingRequestTransfer = false
    @State private var animationAmount: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Animated search icon
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
                        
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.accent)
                    }
                }
                .onAppear {
                    animationAmount = 2.0
                }
                
                // Instructions
                VStack(spacing: 16) {
                    Text("REQUEST TRANSFER")
                        .font(AppFonts.title)
                        .foregroundColor(AppColors.primaryText)
                        .tracking(AppFonts.militaryTracking)
                    
                    Text("Enter serial number to request property from connected users")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Action button
                Button(action: { showingRequestTransfer = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "keyboard")
                        Text("ENTER SERIAL NUMBER")
                            .tracking(AppFonts.militaryTracking)
                    }
                    .font(AppFonts.bodyBold)
                    .frame(width: 240)
                }
                .buttonStyle(.primary)
                
                // Alternative actions
                HStack(spacing: 32) {
                    Button(action: {
                        // TODO: Show connections
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2")
                                .font(.title2)
                                .foregroundColor(AppColors.accent)
                            Text("MY NETWORK")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .tracking(AppFonts.normalTracking)
                        }
                    }
                    
                    Button(action: {
                        // TODO: Show recent requests
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title2)
                                .foregroundColor(AppColors.accent)
                            Text("RECENT REQUESTS")
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
        .sheet(isPresented: $showingRequestTransfer) {
            RequestTransferView()
        }
    }
}

// MARK: - Manual Serial Number Entry View
struct ScanView: View {
    @StateObject private var viewModel = ManualSNViewModel()
    @State private var serialNumber = ""
    @State private var notes = ""
    @State private var showingTransferConfirmation = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.accent)
                    
                    Text("REQUEST PROPERTY")
                        .font(AppFonts.title)
                        .foregroundColor(AppColors.primaryText)
                        .tracking(AppFonts.militaryTracking)
                    
                    Text("Enter the serial number of the property you want to request")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Input form
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SERIAL NUMBER")
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.tertiaryText)
                            .tracking(AppFonts.militaryTracking)
                        
                        TextField("Enter serial number", text: $serialNumber)
                            .textInputAutocapitalization(.characters)
                            .font(AppFonts.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(AppColors.secondaryBackground)
                            .overlay(
                                Rectangle()
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REQUEST NOTES (OPTIONAL)")
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.tertiaryText)
                            .tracking(AppFonts.militaryTracking)
                        
                        TextField("Reason for request...", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .font(AppFonts.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(AppColors.secondaryBackground)
                            .overlay(
                                Rectangle()
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    Button(action: {
                        viewModel.searchProperty(serialNumber: serialNumber)
                    }) {
                        HStack(spacing: 12) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text(viewModel.isLoading ? "SEARCHING..." : "FIND PROPERTY")
                                .tracking(AppFonts.militaryTracking)
                        }
                        .font(AppFonts.bodyBold)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary)
                    .disabled(serialNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                    
                    if let property = viewModel.foundProperty {
                        Button(action: {
                            showingTransferConfirmation = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("REQUEST TRANSFER")
                                    .tracking(AppFonts.militaryTracking)
                            }
                            .font(AppFonts.bodyBold)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                
                // Property details (if found)
                if let property = viewModel.foundProperty {
                    PropertyDetailsCard(property: property)
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Error message
                if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.destructive)
                        Text(errorMessage.uppercased())
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.destructive)
                            .multilineTextAlignment(.center)
                            .tracking(AppFonts.militaryTracking)
                    }
                    .padding()
                    .background(AppColors.destructive.opacity(0.1))
                    .overlay(
                        Rectangle()
                            .stroke(AppColors.destructive.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("REQUEST TRANSFER")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("CANCEL") {
                    presentationMode.wrappedValue.dismiss()
                }
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.accent)
            }
        }
        .sheet(isPresented: $showingTransferConfirmation) {
            if let property = viewModel.foundProperty {
                TransferRequestConfirmationView(
                    property: property,
                    notes: notes
                )
            }
        }
        .animation(.spring(), value: viewModel.foundProperty)
        .animation(.spring(), value: viewModel.errorMessage)
    }
}

// MARK: - Transfer Request Confirmation View
struct TransferRequestConfirmationView: View {
    let property: Property
    let notes: String
    @StateObject private var transferService = TransferService()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Property Summary
                    PropertyDetailsCard(property: property)
                        .padding(.horizontal, 16)
                    
                    // Notes Section
                    if !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("REQUEST NOTES")
                                .font(AppFonts.captionBold)
                                .foregroundColor(AppColors.tertiaryText)
                                .tracking(AppFonts.militaryTracking)
                            
                            Text(notes)
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.primaryText)
                                .padding()
                                .background(AppColors.secondaryBackground)
                                .overlay(
                                    Rectangle()
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer()
                    
                    // Confirmation Button
                    Button(action: {
                        transferService.requestTransfer(
                            serialNumber: property.serialNumber,
                            notes: notes
                        )
                    }) {
                        HStack(spacing: 12) {
                            if transferService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(transferService.isLoading ? "SENDING REQUEST..." : "CONFIRM REQUEST")
                                .tracking(AppFonts.militaryTracking)
                        }
                        .font(AppFonts.bodyBold)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary)
                    .disabled(transferService.isLoading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    
                    // Success/Error Messages
                    if transferService.isSuccess {
                        SuccessMessageView(message: "Transfer request sent!")
                            .padding(.horizontal, 16)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                    }
                    
                    if let error = transferService.errorMessage {
                        ErrorMessageView(message: error)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 16)
            }
            .navigationTitle("Confirm Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.accent)
                }
            }
        }
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
                ScanDetailRow(label: "NSN", value: property.nsn ?? "N/A")
                Rectangle().fill(AppColors.border).frame(height: 1)
                ScanDetailRow(label: "NAME", value: property.itemName.uppercased())
                Rectangle().fill(AppColors.border).frame(height: 1)
                ScanDetailRow(label: "SERIAL", value: property.serialNumber)
                Rectangle().fill(AppColors.border).frame(height: 1)
                ScanDetailRow(label: "STATUS", value: (property.status ?? property.currentStatus ?? "Unknown").uppercased())
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

// MARK: - Transfer Service for Serial Number Requests
class TransferService: ObservableObject {
    @Published var isLoading = false
    @Published var isSuccess = false
    @Published var errorMessage: String?
    
    func requestTransfer(serialNumber: String, notes: String) {
        isLoading = true
        errorMessage = nil
        isSuccess = false
        
        // TODO: Implement actual API call to request transfer by serial number
        // This should call the backend endpoint POST /api/transfers/request
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Simulate API response
            self.isLoading = false
            if serialNumber.count >= 4 {
                self.isSuccess = true
            } else {
                self.errorMessage = "Failed to send transfer request"
            }
        }
    }
}

// MARK: - Previews

struct ScanView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Request transfer tab placeholder
            NavigationView {
                RequestTransferTabView()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Request Tab")
            
            // Manual entry view
            NavigationView {
                ScanView()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Manual Entry")
            
            // Request transfer view
            RequestTransferView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Request Transfer")
        }
    }
} 