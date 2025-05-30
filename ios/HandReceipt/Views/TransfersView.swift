import SwiftUI

struct TransfersView: View {
    @StateObject private var viewModel: TransfersViewModel
    @State private var selectedTab = TransferTab.incoming
    @State private var showingQRScanner = false
    @State private var selectedTransfer: Transfer?
    
    init(apiService: APIServiceProtocol? = nil) {
        let service = apiService ?? APIService()
        self._viewModel = StateObject(wrappedValue: TransfersViewModel(apiService: service))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab Selector
                    tabSelector
                    
                    // Transfer List
                    transferList
                }
            }
            .navigationTitle("Transfers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingQRScanner = true }) {
                        Image(systemName: "qrcode.viewfinder")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .sheet(isPresented: $showingQRScanner) {
                QRScannerView()
            }
            .sheet(item: $selectedTransfer) { transfer in
                TransferDetailView(transfer: transfer, viewModel: viewModel)
            }
            .onAppear {
                Task {
                    await viewModel.fetchTransfers()
                }
            }
            .refreshable {
                await viewModel.fetchTransfers()
            }
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(TransferTab.allCases, id: \.self) { tab in
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(AppFonts.bodyBold)
                            .foregroundColor(selectedTab == tab ? AppColors.accent : AppColors.secondaryText)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? AppColors.accent : Color.clear)
                            .frame(height: 3)
                            .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Transfer List
    @ViewBuilder
    private var transferList: some View {
        let transfers = viewModel.filteredTransfers.filter { transfer in
            if selectedTab == .incoming {
                return viewModel.currentUserId != nil && transfer.toUserId == viewModel.currentUserId
            } else {
                return viewModel.currentUserId != nil && transfer.fromUserId == viewModel.currentUserId
            }
        }
        
        if case .loading = viewModel.loadingState {
            loadingView
        } else if transfers.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(transfers) { transfer in
                        TransferCard(transfer: transfer, isIncoming: selectedTab == .incoming)
                            .onTapGesture {
                                selectedTransfer = transfer
                            }
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
            Text("Loading transfers...")
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedTab == .incoming ? "arrow.down.circle" : "arrow.up.circle")
                .font(.system(size: 48))
                .foregroundColor(AppColors.secondaryText)
            
            Text("No \(selectedTab.title.lowercased()) transfers")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
            
            Text(selectedTab == .incoming ? 
                 "You don't have any pending transfer requests" : 
                 "You haven't requested any transfers")
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if selectedTab == .outgoing {
                Button(action: { showingQRScanner = true }) {
                    Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                        .font(AppFonts.bodyBold)
                }
                .buttonStyle(.primary)
                .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Transfer Card

struct TransferCard: View {
    let transfer: Transfer
    let isIncoming: Bool
    
    init(transfer: Transfer, isIncoming: Bool) {
        self.transfer = transfer
        self.isIncoming = isIncoming
    }
    
    private var statusColor: Color {
        switch transfer.status {
        case .PENDING:
            return .orange
        case .APPROVED:
            return AppColors.accent
        case .REJECTED:
            return AppColors.destructive
        default:
            return AppColors.secondaryText
        }
    }
    
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transfer.propertyName ?? "Unknown Item")
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("SN: \(transfer.propertySerialNumber)")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                // Status Badge
                Text(transfer.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(AppFonts.captionBold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundColor(.white)
                    .background(statusColor)
                    .clipShape(Capsule())
            }
            
            Divider()
            
            // Transfer Info
            transferInfoSection
            
            // Timestamp
            Text("Requested: \(transfer.requestTimestamp, formatter: dateFormatter)")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
            
            // Quick Actions for Pending Incoming Transfers
            if isIncoming && transfer.status == .PENDING {
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Text("Reject")
                            .font(AppFonts.bodyBold)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(AppColors.destructive)
                    }
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.destructive, lineWidth: 1)
                    )
                    
                    Button(action: {}) {
                        Text("Approve")
                            .font(AppFonts.bodyBold)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                    .background(AppColors.accent)
                    .cornerRadius(8)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var transferInfoSection: some View {
        HStack(spacing: 16) {
            // From User
            VStack(alignment: .leading, spacing: 4) {
                Text("From")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                if let fromUser = transfer.fromUser {
                    Text("\(fromUser.rank ?? "") \(fromUser.lastName ?? "")")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                }
            }
            
            // Arrow
            Image(systemName: "arrow.right")
                .foregroundColor(AppColors.secondaryText)
            
            // To User
            VStack(alignment: .leading, spacing: 4) {
                Text("To")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                if let toUser = transfer.toUser {
                    Text("\(toUser.rank ?? "") \(toUser.lastName ?? "")")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Transfer Detail View

struct TransferDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let transfer: Transfer
    @ObservedObject var viewModel: TransfersViewModel
    @State private var showingActionConfirmation = false
    @State private var pendingAction: TransferAction?
    @State private var rejectionNotes = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Property Info
                        propertyInfoSection
                        
                        // Transfer Details
                        transferDetailsSection
                        
                        // Notes (if any)
                        if let notes = transfer.notes, !notes.isEmpty {
                            notesSection(notes: notes)
                        }
                        
                        // Actions (for pending incoming transfers)
                        if viewModel.currentUserId == transfer.toUserId && transfer.status == .PENDING {
                            actionSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Transfer Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
            .alert("Confirm Action", isPresented: $showingActionConfirmation) {
                if pendingAction == .reject {
                    TextField("Rejection reason (optional)", text: $rejectionNotes)
                }
                
                Button("Cancel", role: .cancel) {
                    pendingAction = nil
                }
                
                Button(pendingAction == .approve ? "Approve" : "Reject") {
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
    }
    
    // MARK: - Property Info Section
    private var propertyInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Property Information", systemImage: "cube.box")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Item Name", value: transfer.propertyName ?? "Unknown Item")
                InfoRow(label: "Serial Number", value: transfer.propertySerialNumber)
                InfoRow(label: "Property ID", value: "#\(transfer.propertyId)")
            }
            .padding()
            .background(AppColors.secondaryBackground)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Transfer Details Section
    private var transferDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Transfer Details", systemImage: "arrow.triangle.2.circlepath")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
            
            VStack(alignment: .leading, spacing: 12) {
                // Status
                HStack {
                    Text("Status")
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.secondaryText)
                    Spacer()
                    StatusBadge(
                        status: transfer.status.rawValue.capitalized,
                        type: statusBadgeType(for: transfer.status)
                    )
                }
                
                Divider()
                
                // From User
                if let fromUser = transfer.fromUser {
                    UserInfoRow(label: "From", user: fromUser)
                    Divider()
                }
                
                // To User
                if let toUser = transfer.toUser {
                    UserInfoRow(label: "To", user: toUser)
                    Divider()
                }
                
                // Timestamps
                InfoRow(label: "Requested", value: formatDate(transfer.requestTimestamp))
                
                if let approvalDate = transfer.approvalTimestamp {
                    InfoRow(label: "Completed", value: formatDate(approvalDate))
                }
            }
            .padding()
            .background(AppColors.secondaryBackground)
            .cornerRadius(12)
        }
    }
    
    // Helper to determine StatusBadge type
    private func statusBadgeType(for status: TransferStatus) -> StatusBadge.StatusType {
        switch status {
        case .PENDING:
            return .warning
        case .APPROVED:
            return .success
        case .REJECTED:
            return .error
        case .CANCELLED:
            return .neutral
        case .UNKNOWN:
            return .neutral
        }
    }
    
    // MARK: - Notes Section
    private func notesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Notes", systemImage: "note.text")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
            
            Text(notes)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.secondaryBackground)
                .cornerRadius(12)
        }
    }
    
    // MARK: - Action Section
    private var actionSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                pendingAction = .approve
                showingActionConfirmation = true
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Approve Transfer")
                }
                .font(AppFonts.bodyBold)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
            
            Button(action: {
                pendingAction = .reject
                showingActionConfirmation = true
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Reject Transfer")
                }
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.destructive)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.destructive, lineWidth: 2)
            )
        }
        .padding(.top)
    }
    
    // MARK: - Helper Methods
    private func performAction(_ action: TransferAction) async {
        do {
            switch action {
            case .approve:
                _ = try await viewModel.approveTransfer(transferId: transfer.id)
            case .reject:
                _ = try await viewModel.rejectTransfer(transferId: transfer.id)
            }
            
            await MainActor.run {
                dismiss()
            }
            
            // Refresh transfers
            await viewModel.fetchTransfers()
        } catch {
            // Handle error
            print("Transfer action failed: \(error)")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
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

struct UserInfoRow: View {
    let label: String
    let user: UserSummary
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.secondaryText)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(user.rank ?? "") \(user.lastName ?? "")")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                Text("@\(user.username)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }
}

// MARK: - Supporting Types

enum TransferTab: CaseIterable {
    case incoming
    case outgoing
    
    var title: String {
        switch self {
        case .incoming:
            return "Incoming"
        case .outgoing:
            return "Outgoing"
        }
    }
}

enum TransferAction {
    case approve
    case reject
}

// MARK: - Previews

struct TransfersView_Previews: PreviewProvider {
    static var previews: some View {
        TransfersView(apiService: MockAPIService())
    }
} 