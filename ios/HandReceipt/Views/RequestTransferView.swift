import SwiftUI

// MARK: - Request Transfer View
struct RequestTransferView: View {
    @State private var serialNumber = ""
    @State private var notes = ""
    @StateObject private var transferService = TransferService()
    @StateObject private var viewModel = ManualSNViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.accent)
                            
                            Text("REQUEST PROPERTY")
                                .font(AppFonts.title)
                                .foregroundColor(AppColors.primaryText)
                                .tracking(AppFonts.militaryTracking)
                            
                            Text("Enter the serial number of the property you want to request from your network")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 32)
                        
                        // Input Form
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
                                            .stroke(serialNumber.isEmpty ? AppColors.border : AppColors.accent, lineWidth: 1)
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
                        
                        // Search Button
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
                        .padding(.horizontal, 24)
                        
                        // Property Details (if found)
                        if let property = viewModel.foundProperty {
                            VStack(spacing: 16) {
                                PropertyRequestCard(property: property)
                                
                                Button(action: {
                                    transferService.requestTransfer(
                                        serialNumber: serialNumber,
                                        notes: notes
                                    )
                                }) {
                                    HStack(spacing: 12) {
                                        if transferService.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "arrow.right.circle.fill")
                                        }
                                        Text(transferService.isLoading ? "SENDING REQUEST..." : "REQUEST TRANSFER")
                                            .tracking(AppFonts.militaryTracking)
                                    }
                                    .font(AppFonts.bodyBold)
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.secondary)
                                .disabled(transferService.isLoading)
                            }
                            .padding(.horizontal, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Error Messages
                        if let errorMessage = viewModel.errorMessage {
                            ErrorMessageView(message: errorMessage)
                                .padding(.horizontal, 24)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        if let transferError = transferService.errorMessage {
                            ErrorMessageView(message: transferError)
                                .padding(.horizontal, 24)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Success Message
                        if transferService.isSuccess {
                            SuccessMessageView(message: "Transfer request sent successfully!")
                                .padding(.horizontal, 24)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }
                        }
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationTitle("Request Transfer")
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
        .animation(.spring(), value: viewModel.foundProperty)
        .animation(.spring(), value: viewModel.errorMessage)
        .animation(.spring(), value: transferService.isSuccess)
    }
}

// MARK: - Property Request Card
struct PropertyRequestCard: View {
    let property: Property
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                Text("PROPERTY FOUND")
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
                PropertyDetailRow(label: "NAME", value: property.itemName.uppercased())
                Divider()
                PropertyDetailRow(label: "SERIAL", value: property.serialNumber)
                Divider()
                PropertyDetailRow(label: "NSN", value: property.nsn ?? "N/A")
                Divider()
                PropertyDetailRow(label: "STATUS", value: (property.status ?? property.currentStatus ?? "Unknown").uppercased())
                
                if let currentHolder = property.currentHolder {
                    Divider()
                    PropertyDetailRow(label: "CURRENT HOLDER", value: "\(currentHolder.rank ?? "") \(currentHolder.name ?? "Unknown")")
                }
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

// MARK: - Property Detail Row
struct PropertyDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .font(AppFonts.captionBold)
                .foregroundColor(AppColors.tertiaryText)
                .tracking(AppFonts.militaryTracking)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1)
            
            Spacer()
        }
    }
}

// MARK: - Error Message View
struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.destructive)
                .font(.title2)
            Text(message.uppercased())
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
    }
}

// MARK: - Success Message View
struct SuccessMessageView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.success)
                .font(.title2)
            Text(message.uppercased())
                .font(AppFonts.body)
                .foregroundColor(AppColors.success)
                .multilineTextAlignment(.center)
                .tracking(AppFonts.militaryTracking)
        }
        .padding()
        .background(AppColors.success.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview
struct RequestTransferView_Previews: PreviewProvider {
    static var previews: some View {
        RequestTransferView()
            .preferredColorScheme(.dark)
    }
} 