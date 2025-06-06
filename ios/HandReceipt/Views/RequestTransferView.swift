// handreceipt/ios/HandReceipt/Views/RequestTransferView.swift

import SwiftUI
import Foundation

// MARK: - Request Transfer View
struct RequestTransferView: View {
    @State private var serialNumber = ""
    @State private var notes = ""
    @State private var isTransferring = false
    @State private var transferError: String?
    @State private var transferSuccess = false
    @StateObject private var viewModel = ManualSNViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    // Computed properties to work with ManualSNViewModel's lookupState
    private var foundProperty: Property? {
        if case .success(let property) = viewModel.lookupState {
            return property
        }
        return nil
    }
    
    private var isSearching: Bool {
        if case .loading = viewModel.lookupState {
            return true
        }
        return false
    }
    
    private var searchErrorMessage: String? {
        switch viewModel.lookupState {
        case .error(let message):
            return message
        case .notFound:
            return "Property with serial number '\(serialNumber)' not found"
        default:
            return nil
        }
    }
    
    private func requestTransfer() async {
        guard let property = foundProperty else { return }
        
        isTransferring = true
        transferError = nil
        transferSuccess = false
        
        do {
            // Request transfer by serial number
            _ = try await TransferService.shared.requestBySerial(
                serialNumber: property.serialNumber,
                notes: notes.isEmpty ? nil : notes
            )
            
            await MainActor.run {
                isTransferring = false
                transferSuccess = true
            }
        } catch {
            await MainActor.run {
                isTransferring = false
                transferError = "Failed to send transfer request: \(error.localizedDescription)"
            }
        }
    }
    
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
                                .compatibleKerning(AppFonts.militaryTracking)
                            
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
                                    .compatibleKerning(AppFonts.militaryTracking)
                                
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
                                    .onChange(of: serialNumber) { newValue in
                                        // Update the view model's input to trigger search
                                        viewModel.serialNumberInput = newValue
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("REQUEST NOTES (OPTIONAL)")
                                    .font(AppFonts.captionBold)
                                    .foregroundColor(AppColors.tertiaryText)
                                    .compatibleKerning(AppFonts.militaryTracking)
                                
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $notes)
                                        .frame(minHeight: 60, maxHeight: 120)
                                        .font(AppFonts.body)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(AppColors.secondaryBackground)
                                        .overlay(
                                            Rectangle()
                                                .stroke(AppColors.border, lineWidth: 1)
                                        )
                                    
                                    if notes.isEmpty {
                                        Text("Reason for request...")
                                            .font(AppFonts.body)
                                            .foregroundColor(AppColors.tertiaryText)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 22)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Search Button
                        Button(action: {
                            // Manually trigger search if needed
                            if !serialNumber.isEmpty {
                                viewModel.serialNumberInput = serialNumber
                                viewModel.findProperty()
                            }
                        }) {
                            HStack(spacing: 12) {
                                if isSearching {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                                Text(isSearching ? "SEARCHING..." : "FIND PROPERTY")
                                    .compatibleKerning(AppFonts.militaryTracking)
                            }
                            .font(AppFonts.bodyBold)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primary)
                        .disabled(serialNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                        .padding(.horizontal, 24)
                        
                        // Property Details (if found)
                        if let property = foundProperty {
                            VStack(spacing: 16) {
                                PropertyRequestCard(property: property)
                                
                                Button(action: {
                                    Task {
                                        await requestTransfer()
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        if isTransferring {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "arrow.right.circle.fill")
                                        }
                                        Text(isTransferring ? "SENDING REQUEST..." : "REQUEST TRANSFER")
                                            .compatibleKerning(AppFonts.militaryTracking)
                                    }
                                    .font(AppFonts.bodyBold)
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.secondary)
                                .disabled(isTransferring)
                            }
                            .padding(.horizontal, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Error Messages
                        if let errorMessage = searchErrorMessage {
                            ErrorMessageView(message: errorMessage)
                                .padding(.horizontal, 24)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        if let transferError = transferError {
                            ErrorMessageView(message: transferError)
                                .padding(.horizontal, 24)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Success Message
                        if transferSuccess {
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
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.accent)
            )
        }
        .animation(.spring(), value: viewModel.lookupState)
        .animation(.spring(), value: searchErrorMessage)
        .animation(.spring(), value: transferSuccess)
        .onAppear {
            // Sync the local state with view model
            serialNumber = viewModel.serialNumberInput
        }
    }
}

// MARK: - Property Request Card
struct PropertyRequestCard: View {
    let property: Property
    @State private var isOwnerConnected = false
    @State private var ownerInfo: UserSummary?
    @StateObject private var connectionsVM = ConnectionsViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                Text("PROPERTY FOUND")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.success)
                    .compatibleKerning(AppFonts.militaryTracking)
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
                PropertyDetailRow(label: "NAME", value: property.name.uppercased())
                Divider()
                PropertyDetailRow(label: "SERIAL", value: property.serialNumber)
                Divider()
                PropertyDetailRow(label: "NSN", value: property.nsn ?? "N/A")
                Divider()
                PropertyDetailRow(label: "STATUS", value: (property.status ?? property.currentStatus ?? "Unknown").uppercased())
                
                // Owner Information - simplified since we only have user ID
                if let assignedToUserId = property.assignedToUserId {
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURRENT HOLDER:")
                                .font(AppFonts.captionBold)
                                .foregroundColor(AppColors.tertiaryText)
                                .compatibleKerning(AppFonts.militaryTracking)
                            
                            if let owner = ownerInfo {
                                Text("\(owner.rank ?? "") \(owner.lastName ?? "Unknown")")
                                    .font(AppFonts.bodyBold)
                                    .foregroundColor(AppColors.primaryText)
                                
                                Text(owner.email ?? "No email")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            } else {
                                Text("User #\(assignedToUserId)")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                        
                        Spacer()
                        
                        // Connection Status Badge
                        if ownerInfo != nil {
                            if isOwnerConnected {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption)
                                    Text("CONNECTED")
                                        .font(AppFonts.captionBold)
                                        .compatibleKerning(AppFonts.militaryTracking)
                                }
                                .foregroundColor(AppColors.success)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppColors.success.opacity(0.15))
                                .overlay(
                                    Rectangle()
                                        .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
                                )
                            } else {
                                Button(action: {
                                    if let holderId = property.assignedToUserId {
                                        Task {
                                            do {
                                                let _ = try await APIService().sendConnectionRequest(targetUserId: holderId)
                                                await connectionsVM.refresh()
                                            } catch {
                                                print("Failed to send connection request: \(error)")
                                            }
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.badge.plus")
                                            .font(.caption)
                                        Text("CONNECT")
                                            .font(AppFonts.captionBold)
                                            .compatibleKerning(AppFonts.militaryTracking)
                                    }
                                }
                                .buttonStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .stroke(AppColors.border, lineWidth: 1)
        )
        .task {
            // Try to load owner info and check connection status
            if let holderId = property.assignedToUserId {
                // Fetch user info
                do {
                    ownerInfo = try await APIService().getUserById(holderId)
                } catch {
                    print("Failed to fetch owner info: \(error)")
                }
                
                // Check if they're connected
                await connectionsVM.refresh()
                isOwnerConnected = connectionsVM.connections.contains { 
                    $0.connectedUserId == holderId && $0.connectionStatus == .accepted
                }
            }
        }
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
                .compatibleKerning(AppFonts.militaryTracking)
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
                .compatibleKerning(AppFonts.militaryTracking)
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
                .compatibleKerning(AppFonts.militaryTracking)
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