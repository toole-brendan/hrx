import SwiftUI

struct TransfersView: View {
    @StateObject private var viewModel: TransfersViewModel
    @State private var selectedTab = TransferTab.incoming
    @State private var showingTransferOptions = false
    @State private var showingSerialRequest = false
    @State private var activeOffers: [TransferOffer] = []
    @State private var selectedTransfer: Transfer?
    @State private var showingFilterOptions = false
    @Environment(\.presentationMode) var presentationMode
    
    init(apiService: APIServiceProtocol? = nil) {
        let service = apiService ?? APIService()
        let currentUserId = AuthManager.shared.getUserId()
        self._viewModel = StateObject(wrappedValue: TransfersViewModel(
            apiService: service,
            currentUserId: currentUserId
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom minimal navigation bar
            MinimalNavigationBar(
                title: "TRANSFERS",
                titleStyle: .mono,
                trailingItems: [
                    .init(text: "New", style: .text, action: { showingTransferOptions = true })
                ]
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Main content - no header, direct to tabs
                    VStack(spacing: 32) {
                        // Filter tabs with reduced top spacing
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 16)
                            tabSelector
                        }
                        
                        // Transfer content
                        transferMainContent
                    }
                    
                    // Bottom padding
                    Color.clear.frame(height: 80)
                }
            }
            .background(AppColors.appBackground)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            viewModel.fetchTransfers()
        }
        .task {
            await loadActiveOffers()
        }
        .actionSheet(isPresented: $showingTransferOptions) {
            ActionSheet(
                title: Text("New Transfer"),
                buttons: [
                    .default(Text("Request by Serial Number")) {
                        showingSerialRequest = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingSerialRequest) {
            SerialNumberRequestView()
        }
        .sheet(item: $selectedTransfer) { transfer in
            NavigationView {
                TransferDetailView(transfer: transfer, viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Tab Selector (8VC-inspired minimal tabs)
    private var tabSelector: some View {
        VStack(spacing: 0) {
            HStack(spacing: 32) {
                ForEach(TransferTab.allCases, id: \.self) { tab in
                    VStack(spacing: 8) {
                        Text(tab.title.uppercased())
                            .font(AppFonts.captionBold)
                            .foregroundColor(selectedTab == tab ? AppColors.primaryText : AppColors.tertiaryText)
                            .compatibleKerning(1.5)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? AppColors.primaryText : Color.clear)
                            .frame(height: 2)
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        IndustrialLoadingView(message: "LOADING TRANSFERS")
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        ModernEmptyStateView(
            icon: selectedTab == .incoming ? "arrow.down" : "arrow.up",
            title: "No \(selectedTab.title) Transfers",
            message: selectedTab == .incoming ? 
                "Transfer requests from your connections will appear here." : 
                "Your outgoing transfer requests will appear here.",
            actionTitle: selectedTab == .outgoing ? "CREATE TRANSFER" : nil,
            action: selectedTab == .outgoing ? { showingTransferOptions = true } : nil
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Transfer Main Content
    @ViewBuilder
    private var transferMainContent: some View {
        let transfers = viewModel.filteredTransfers.filter { transfer in
            if selectedTab == .incoming {
                return viewModel.currentUserId != nil && transfer.toUserId == viewModel.currentUserId
            } else {
                return viewModel.currentUserId != nil && transfer.fromUserId == viewModel.currentUserId
            }
        }
        
        if case .loading = viewModel.loadingState {
            loadingView
        } else if transfers.isEmpty && activeOffers.isEmpty {
            emptyStateView
        } else {
            VStack(spacing: 32) {
                // Active offers section (only for incoming tab)
                if selectedTab == .incoming && !activeOffers.isEmpty {
                    VStack(spacing: 24) {
                        ModernSectionHeader(
                            title: "Property Offers",
                            subtitle: "Items offered by your connections"
                        )
                        
                        VStack(spacing: 16) {
                            ForEach(activeOffers) { offer in
                                CleanOfferCard(offer: offer)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                // Transfer requests section
                if !transfers.isEmpty {
                    VStack(spacing: 24) {
                        ModernSectionHeader(
                            title: selectedTab == .incoming ? "Incoming Transfers" : "Outgoing Transfers",
                            subtitle: "\(transfers.count) transfers"
                        )
                        
                        VStack(spacing: 16) {
                            ForEach(transfers) { transfer in
                                CleanTransferCard(
                                    transfer: transfer,
                                    isIncoming: selectedTab == .incoming,
                                    onTap: { selectedTransfer = transfer },
                                    onQuickApprove: {
                                        viewModel.approveTransfer(transferId: transfer.id)
                                    },
                                    onQuickReject: {
                                        viewModel.rejectTransfer(transferId: transfer.id)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .refreshable {
                viewModel.fetchTransfers()
            }
        }
    }
    
    private func loadActiveOffers() async {
        do {
            activeOffers = try await TransferService.shared.getActiveOffers()
        } catch {
            print("Failed to load offers: \(error)")
        }
    }
}

// MARK: - Clean Transfer Card (8VC-styled)
struct CleanTransferCard: View {
    let transfer: Transfer
    let isIncoming: Bool
    let onTap: () -> Void
    let onQuickApprove: () -> Void
    let onQuickReject: () -> Void
    
    @State private var isPressed = false
    @State private var isOtherUserConnected = false
    @StateObject private var connectionsVM = ConnectionsViewModel()
    
    private var statusColor: Color {
        switch transfer.status.lowercased() {
        case "pending": return AppColors.warning
        case "approved": return AppColors.success
        case "rejected": return AppColors.destructive
        default: return AppColors.secondaryText
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 20) {
                    // Property header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transfer.propertyName ?? "Unknown Item")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("SN: \(transfer.propertySerialNumber ?? "Unknown")")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    // Transfer participants
                    HStack(spacing: 24) {
                        // From
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FROM")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                                .compatibleKerning(1.5)
                            
                            if let fromUser = transfer.fromUser {
                                Text("\(fromUser.rank ?? "") \(fromUser.lastName ?? "")")
                                    .font(AppFonts.bodyBold)
                                    .foregroundColor(AppColors.primaryText)
                                Text("@\(fromUser.username)")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(AppColors.accent)
                        
                        // To
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TO")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                                .compatibleKerning(1.5)
                            
                            if let toUser = transfer.toUser {
                                Text("\(toUser.rank ?? "") \(toUser.lastName ?? "")")
                                    .font(AppFonts.bodyBold)
                                    .foregroundColor(AppColors.primaryText)
                                Text("@\(toUser.username)")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                    }
                    
                    // Status and timestamp
                    HStack {
                        Text(transfer.status.uppercased())
                            .font(AppFonts.captionBold)
                            .foregroundColor(statusColor)
                            .compatibleKerning(1.5)
                        
                        Spacer()
                        
                        Text(formatDate(transfer.requestDate))
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                    }
                }
                .padding(24)
                
                // Quick actions for pending incoming transfers
                if isIncoming && transfer.status.lowercased() == "pending" {
                    HStack(spacing: 0) {
                        Button(action: onQuickReject) {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .regular))
                                Text("REJECT")
                                    .compatibleKerning(1.5)
                            }
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.destructive)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(width: 1)
                        
                        Button(action: onQuickApprove) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .regular))
                                Text("APPROVE")
                                    .compatibleKerning(1.5)
                            }
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.success)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                    }
                    .background(AppColors.tertiaryBackground)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .modernCard()
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
        .task {
            let otherUserId = isIncoming ? transfer.fromUserId : transfer.toUserId
            await connectionsVM.refresh()
            isOtherUserConnected = connectionsVM.connections.contains { 
                $0.connectedUserId == otherUserId && $0.connectionStatus == .accepted
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM HH:mm"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Clean Offer Card (8VC-styled)
struct CleanOfferCard: View {
    let offer: TransferOffer
    @State private var showingAcceptDialog = false
    @State private var showingRejectDialog = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Property info
            VStack(alignment: .leading, spacing: 8) {
                Text(offer.property?.name ?? "Unknown Item")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundColor(AppColors.primaryText)
                
                Text("SN: \(offer.property?.serialNumber ?? "")")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(AppColors.secondaryText)
            }
            
            // Offer details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OFFERED BY")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                        .compatibleKerning(1.5)
                    
                    Text("\(offer.offeror?.rank ?? "") \(offer.offeror?.lastName ?? "")")
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                }
                
                Spacer()
                
                if let expiresAt = offer.expiresAt {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("EXPIRES")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                            .compatibleKerning(1.5)
                        
                        Text(formatRelativeDate(expiresAt))
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.warning)
                    }
                }
            }
            
            // Notes if any
            if let notes = offer.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .italic()
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: { showingRejectDialog = true }) {
                    Text("DECLINE")
                        .font(AppFonts.captionBold)
                        .compatibleKerning(1.5)
                }
                .buttonStyle(.secondary)
                
                Button(action: { showingAcceptDialog = true }) {
                    Text("ACCEPT")
                        .font(AppFonts.captionBold)
                        .compatibleKerning(1.5)
                }
                .buttonStyle(.primary)
            }
        }
        .modernCard()
        .alert("Accept Offer?", isPresented: $showingAcceptDialog) {
            Button("Cancel", role: .cancel) { }
            Button("Accept") {
                Task {
                    try? await TransferService.shared.acceptOffer(offer.id)
                }
            }
        } message: {
            Text("Accept this property transfer offer from \(offer.offeror?.rank ?? "") \(offer.offeror?.lastName ?? "")?")
        }
        .alert("Decline Offer?", isPresented: $showingRejectDialog) {
            Button("Cancel", role: .cancel) { }
            Button("Decline", role: .destructive) {
                Task {
                    try? await TransferService.shared.rejectOffer(offer.id)
                }
            }
        } message: {
            Text("Decline this property transfer offer?")
        }
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Transfer Detail View (Updated with existing components)
struct TransferDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let transfer: Transfer
    @ObservedObject var viewModel: TransfersViewModel
    @State private var showingActionConfirmation = false
    @State private var pendingAction: TransferAction?
    @State private var rejectionNotes = ""
    @State private var isProcessing = false
    
    var body: some View {
        ZStack(alignment: .top) {
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Spacer for header
                Color.clear.frame(height: 36)
                
                ScrollView {
                    VStack(spacing: 40) {
                        // Top padding
                        Color.clear.frame(height: 24)
                        
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
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, 24)
                }
            }
            
            // Header
            UniversalHeaderView(
                title: "Transfer Details",
                showBackButton: true,
                backButtonAction: { dismiss() },
                trailingButton: {
                    AnyView(
                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }
                    )
                }
            )
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
    
    // MARK: - Status Header
    private var statusHeader: some View {
        let statusColor = statusColor(for: transfer.status)
        
        return VStack(spacing: 20) {
            Circle()
                .fill(statusColor.opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: statusIcon(for: transfer.status))
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(statusColor)
                )
            
            Text(transfer.status.uppercased())
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .foregroundColor(statusColor)
                .compatibleKerning(2.0)
        }
        .frame(maxWidth: .infinity)
        .modernCard()
    }
    
    // MARK: - Property Section
    private var propertySection: some View {
        VStack(spacing: 24) {
            ModernSectionHeader(
                title: "Property Details"
            )
            
            VStack(spacing: 16) {
                CleanDetailRow(label: "ITEM NAME", value: transfer.propertyName ?? "Unknown Item")
                CleanDetailRow(label: "SERIAL NUMBER", value: transfer.propertySerialNumber ?? "Unknown", isMonospaced: true)
                CleanDetailRow(label: "PROPERTY ID", value: "#\(transfer.propertyId)", isMonospaced: true)
            }
            .modernCard()
        }
    }
    
    // MARK: - Transfer Section
    private var transferSection: some View {
        VStack(spacing: 24) {
            ModernSectionHeader(
                title: "Transfer Information"
            )
            
            VStack(spacing: 16) {
                if let fromUser = transfer.fromUser {
                    CleanUserRow(label: "FROM", user: fromUser)
                }
                
                if let toUser = transfer.toUser {
                    CleanUserRow(label: "TO", user: toUser)
                }
                
                CleanDetailRow(label: "REQUESTED", value: formatDate(transfer.requestDate))
                
                if let approvalDate = transfer.resolvedDate {
                    CleanDetailRow(label: "COMPLETED", value: formatDate(approvalDate))
                }
            }
            .modernCard()
        }
    }
    
    // MARK: - Notes Section
    private func notesSection(_ notes: String) -> some View {
        VStack(spacing: 24) {
            ModernSectionHeader(
                title: "Notes"
            )
            
            Text(notes)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modernCard()
        }
    }
    
    // MARK: - Action Section
    private var actionSection: some View {
        VStack(spacing: 24) {
            Text("PENDING YOUR APPROVAL")
                .font(AppFonts.captionBold)
                .foregroundColor(AppColors.warning)
                .compatibleKerning(2.0)
            
            HStack(spacing: 16) {
                Button(action: {
                    pendingAction = .reject
                    showingActionConfirmation = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                        Text("REJECT")
                            .compatibleKerning(1.5)
                    }
                    .font(AppFonts.bodyBold)
                }
                .buttonStyle(.secondary)
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
                                .compatibleKerning(1.5)
                        }
                        .font(AppFonts.bodyBold)
                    }
                }
                .buttonStyle(.primary)
                .disabled(isProcessing)
            }
        }
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
                .compatibleKerning(1.5)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(isMonospaced ? .system(size: 16, design: .monospaced) : AppFonts.body)
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
                .compatibleKerning(1.5)
                .frame(width: 120, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(user.rank ?? "") \(user.lastName ?? "")")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                Text("@\(user.username)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                Text("ID: #\(user.id)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(AppColors.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Supporting Types

enum TransferTab: String, CaseIterable {
    case incoming
    case outgoing
    
    var title: String {
        switch self {
        case .incoming: return "Incoming"
        case .outgoing: return "Outgoing"
        }
    }
    
    var icon: String {
        switch self {
        case .incoming: return "arrow.down"
        case .outgoing: return "arrow.up"
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
        TransfersView()
    }
} 