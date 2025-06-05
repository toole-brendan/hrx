import SwiftUI

// MARK: - Transfer Detail View (Elegant 8VC-styled)
struct TransferDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let transfer: Transfer
    @ObservedObject var viewModel: TransfersViewModel
    @State private var showingActionConfirmation = false
    @State private var pendingAction: TransferAction?
    @State private var rejectionNotes = ""
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom navigation header
                navigationHeader
                
                // Main content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Status header
                        statusHeader
                        
                        // Property information
                        propertySection
                        
                        // Transfer information
                        transferSection
                        
                        // Notes if available
                        if let notes = transfer.notes, !notes.isEmpty {
                            notesSection(notes)
                        }
                        
                        // Actions for pending incoming transfers
                        if viewModel.currentUserId == transfer.toUserId && transfer.status.lowercased() == "pending" {
                            actionSection
                        }
                        
                        // Bottom padding
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .alert("Confirm Action", isPresented: $showingActionConfirmation) {
            if pendingAction == .reject {
                TextField("Rejection reason (optional)", text: $rejectionNotes)
            }
            
            Button("Cancel", role: .cancel) {
                pendingAction = nil
                rejectionNotes = ""
            }
            
            Button(pendingAction == .approve ? "Approve" : "Reject", role: pendingAction == .approve ? .none : .destructive) {
                if let action = pendingAction {
                    Task {
                        await performAction(action)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to \(pendingAction == .approve ? "approve" : "reject") this transfer?")
        }
    }
    
    // MARK: - Navigation Header
    private var navigationHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                // Back button
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .regular))
                        Text("Back")
                            .font(AppFonts.body)
                    }
                    .foregroundColor(AppColors.secondaryText)
                }
                .frame(minWidth: 60, alignment: .leading)
                
                Spacer()
                
                // Title
                Text("Transfer Details")
                    .font(AppFonts.serifHeadline)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                // Share button
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(AppColors.primaryText)
                }
                .frame(minWidth: 60, alignment: .trailing)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppColors.appBackground)
            
            // Subtle divider
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)
        }
    }
    
    // MARK: - Status Header
    private var statusHeader: some View {
        let statusColor = statusColor(for: transfer.status)
        
        return VStack(spacing: 16) {
            Circle()
                .fill(statusColor.opacity(0.1))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: statusIcon(for: transfer.status))
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(statusColor)
                )
            
            Text(transfer.status.uppercased())
                .font(AppFonts.monoHeadline)
                .foregroundColor(statusColor)
                .compatibleKerning(AppFonts.ultraWideKerning)
        }
        .frame(maxWidth: .infinity)
        .cleanCard(padding: 20)
    }
    
    // MARK: - Property Section
    private var propertySection: some View {
        VStack(spacing: 16) {
            ElegantSectionHeader(
                title: "Property Details",
                style: .serif
            )
            
            VStack(spacing: 12) {
                CleanDetailRow(label: "ITEM NAME", value: transfer.propertyName ?? "Unknown Item")
                CleanDetailRow(label: "SERIAL NUMBER", value: transfer.propertySerialNumber ?? "Unknown", isMonospaced: true)
                CleanDetailRow(label: "PROPERTY ID", value: "#\(transfer.propertyId)", isMonospaced: true)
            }
            .cleanCard(padding: 20)
        }
    }
    
    // MARK: - Transfer Section
    private var transferSection: some View {
        VStack(spacing: 16) {
            ElegantSectionHeader(
                title: "Transfer Information",
                style: .serif
            )
            
            VStack(spacing: 12) {
                if let fromUser = transfer.fromUser {
                    CleanUserRow(label: "FROM", user: fromUser)
                }
                
                Divider()
                    .background(AppColors.divider)
                
                if let toUser = transfer.toUser {
                    CleanUserRow(label: "TO", user: toUser)
                }
                
                Divider()
                    .background(AppColors.divider)
                
                CleanDetailRow(label: "REQUESTED", value: formatDate(transfer.requestDate))
                
                if let approvalDate = transfer.resolvedDate {
                    Divider()
                        .background(AppColors.divider)
                    CleanDetailRow(label: "COMPLETED", value: formatDate(approvalDate))
                }
            }
            .cleanCard(padding: 20)
        }
    }
    
    // MARK: - Notes Section
    private func notesSection(_ notes: String) -> some View {
        VStack(spacing: 16) {
            ElegantSectionHeader(
                title: "Notes",
                style: .serif
            )
            
            Text(notes)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cleanCard(padding: 20)
        }
    }
    
    // MARK: - Action Section
    private var actionSection: some View {
        VStack(spacing: 20) {
            Text("PENDING YOUR APPROVAL")
                .font(AppFonts.captionMedium)
                .foregroundColor(AppColors.warning)
                .compatibleKerning(AppFonts.ultraWideKerning)
            
            HStack(spacing: 12) {
                Button(action: {
                    pendingAction = .reject
                    showingActionConfirmation = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                        Text("REJECT")
                            .compatibleKerning(AppFonts.wideKerning)
                    }
                    .font(AppFonts.bodyMedium)
                }
                .buttonStyle(MinimalSecondaryButtonStyle())
                .disabled(isProcessing)
                
                Button(action: {
                    pendingAction = .approve
                    showingActionConfirmation = true
                }) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                            Text("APPROVE")
                                .compatibleKerning(AppFonts.wideKerning)
                        }
                        .font(AppFonts.bodyMedium)
                    }
                }
                .buttonStyle(MinimalPrimaryButtonStyle())
                .disabled(isProcessing)
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Helper Methods
    private func performAction(_ action: TransferAction) async {
        isProcessing = true
        
        switch action {
        case .approve:
            viewModel.approveTransfer(transferId: transfer.id)
        case .reject:
            viewModel.rejectTransfer(transferId: transfer.id)
        }
        
        dismiss()
        viewModel.fetchTransfers()
        
        isProcessing = false
        pendingAction = nil
        rejectionNotes = ""
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy HH:mm"
        return formatter.string(from: date).uppercased()
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "pending": return AppColors.warning
        case "completed", "approved": return AppColors.success
        case "rejected": return AppColors.destructive
        default: return AppColors.secondaryText
        }
    }
    
    private func statusIcon(for status: String) -> String {
        switch status.lowercased() {
        case "pending": return "clock"
        case "completed", "approved": return "checkmark.circle"
        case "rejected": return "xmark.circle"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - Supporting Views

struct CleanDetailRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
                .compatibleKerning(AppFonts.wideKerning)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(isMonospaced ? AppFonts.monoBody : AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CleanUserRow: View {
    let label: String
    let user: UserSummary
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
                .compatibleKerning(AppFonts.wideKerning)
                .frame(width: 100, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(user.rank ?? "") \(user.lastName ?? "")")
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                                    Text(user.email ?? "No email")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                Text("ID: #\(user.id)")
                    .font(AppFonts.monoCaption)
                    .foregroundColor(AppColors.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}



 