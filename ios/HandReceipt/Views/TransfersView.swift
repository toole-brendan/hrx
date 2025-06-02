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
        // TODO: Get actual current user ID from AuthManager/AuthViewModel
        let currentUserId = AuthManager.shared.getCurrentUserId()
        self._viewModel = StateObject(wrappedValue: TransfersViewModel(
            apiService: service,
            currentUserId: currentUserId
        ))
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Spacer for header
                Color.clear
                    .frame(height: 36)
                
                // Tab Selector with industrial styling
                tabSelector
                
                // Filter Bar
                filterBar
                
                // Transfer List or Empty State
                transferContent
            }
            
            // Top bar that mirrors bottom tab bar
            headerSection
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        ZStack {
            // Background that extends to top of screen
            AppColors.secondaryBackground
                .ignoresSafeArea()
            
            // Content positioned at bottom of header
            VStack {
                Spacer()
                ZStack {
                    // Center the title
                    Text("TRANSFERS")
                        .font(.system(size: 16, weight: .medium)) // Larger font
                        .foregroundColor(AppColors.primaryText)
                        .compatibleKerning(AppFonts.militaryTracking)
                        .frame(maxWidth: .infinity)
                    
                    // Add button aligned to trailing edge
                    HStack {
                        Spacer()
                        Button(action: { showingTransferOptions = true }) {
                            Image(systemName: "plus")
                                .font(.body)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12) // Bottom padding
            }
        }
        .frame(height: 36) // Very tight header
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
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            
                            Text(tab.title.uppercased())
                                .font(AppFonts.bodyBold)
                                .compatibleKerning(AppFonts.militaryTracking)
                        }
                        .foregroundColor(selectedTab == tab ? AppColors.accent : AppColors.secondaryText)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? AppColors.accent : Color.clear)
                            .frame(height: 3)
                            .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .stroke(AppColors.border, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
    
    // MARK: - Filter Bar
    private var filterBar: some View {
        HStack(spacing: 12) {
            // Status Filter
            Menu {
                ForEach(TransfersViewModel.FilterStatus.allCases) { status in
                    Button(action: {
                        viewModel.selectedStatusFilter = status
                    }) {
                        HStack {
                            Text(status.rawValue.capitalized)
                            if viewModel.selectedStatusFilter == status {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .font(.caption)
                    Text(viewModel.selectedStatusFilter.rawValue.uppercased())
                        .font(AppFonts.captionBold)
                        .compatibleKerning(AppFonts.normalTracking)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.tertiaryBackground)
                .cornerRadius(0) // Industrial square corners
                .overlay(
                    Rectangle()
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
            
            Spacer()
            
            // Transfer count
            if viewModel.filteredTransfers.count > 0 {
                Text("\(viewModel.filteredTransfers.count) TRANSFERS")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .compatibleKerning(AppFonts.militaryTracking)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(AppColors.mutedBackground)
    }
    
    // MARK: - Transfer Content
    @ViewBuilder
    private var transferContent: some View {
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
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Active offers section (only for incoming tab)
                    if selectedTab == .incoming && !activeOffers.isEmpty {
                        Section {
                            ForEach(activeOffers) { offer in
                                OfferRow(offer: offer)
                                
                                if offer.id != activeOffers.last?.id {
                                    Rectangle()
                                        .fill(AppColors.border)
                                        .frame(height: 1)
                                        .padding(.horizontal)
                                }
                            }
                        } header: {
                            ModernSectionHeader(
                                title: "Offers For You",
                                subtitle: "Properties offered to you by your connections"
                            )
                        }
                        
                        // Divider between offers and transfers
                        if !transfers.isEmpty {
                            Rectangle()
                                .fill(AppColors.border)
                                .frame(height: 1)
                                .padding(.vertical, 8)
                        }
                    }
                    
                    ForEach(transfers) { transfer in
                        TransferCard(
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
                        
                        // Divider between cards
                        if transfer.id != transfers.last?.id {
                            Rectangle()
                                .fill(AppColors.border)
                                .frame(height: 1)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                viewModel.fetchTransfers()
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        IndustrialLoadingView(message: "LOADING TRANSFERS")
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        ModernEmptyStateView(
            icon: selectedTab == .incoming ? "arrow.down.circle" : "arrow.up.circle",
            title: "No \(selectedTab.title) Transfers",
            message: selectedTab == .incoming ? 
                "No pending transfer requests" : 
                "No outgoing transfer requests",
            actionTitle: selectedTab == .outgoing ? "NEW TRANSFER REQUEST" : nil,
            action: selectedTab == .outgoing ? { showingTransferOptions = true } : nil
        )
    }
    
    private func loadActiveOffers() async {
        do {
            activeOffers = try await TransferService.shared.getActiveOffers()
        } catch {
            print("Failed to load offers: \(error)")
        }
    }
}

// MARK: - Transfer Card

struct TransferCard: View {
    let transfer: Transfer
    let isIncoming: Bool
    let onTap: () -> Void
    let onQuickApprove: () -> Void
    let onQuickReject: () -> Void
    
    @State private var isPressed = false
    @State private var isOtherUserConnected = false
    @StateObject private var connectionsVM = ConnectionsViewModel()
    
    private var statusColor: Color {
        switch transfer.status.uppercased() {
        case "PENDING":
            return AppColors.warning
        case "APPROVED":
            return AppColors.success
        case "REJECTED":
            return AppColors.destructive
        default:
            return AppColors.secondaryText
        }
    }
    
    private var statusIcon: String {
        switch transfer.status.uppercased() {
        case "PENDING":
            return "clock.fill"
        case "APPROVED":
            return "checkmark.circle.fill"
        case "REJECTED":
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Main card content
                VStack(alignment: .leading, spacing: 16) {
                    // Header with property info
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(transfer.propertyName ?? "UNKNOWN ITEM")
                                .font(AppFonts.bodyBold)
                                .foregroundColor(AppColors.primaryText)
                                .compatibleKerning(AppFonts.normalTracking)
                            
                            Text("SN: \(transfer.propertySerialNumber ?? "Unknown")")
                                .font(AppFonts.mono)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        // Status indicator
                        StatusBadge(
                            status: transfer.status,
                            type: statusBadgeType(for: transfer.status),
                            size: .medium
                        )
                    }
                    
                    // Transfer participants
                    HStack(spacing: 16) {
                        // From
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("FROM")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.tertiaryText)
                                    .compatibleKerning(AppFonts.militaryTracking)
                                
                                if !isIncoming && isOtherUserConnected {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.success)
                                }
                            }
                            
                            if let fromUser = transfer.fromUser {
                                Text("\(fromUser.rank ?? "") \(fromUser.lastName ?? "")")
                                    .font(AppFonts.bodyBold)
                                    .foregroundColor(AppColors.primaryText)
                                Text("@\(fromUser.username)")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Arrow
                        Image(systemName: "arrow.right")
                            .font(.body)
                            .foregroundColor(AppColors.accent)
                        
                        // To
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("TO")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.tertiaryText)
                                    .compatibleKerning(AppFonts.militaryTracking)
                                
                                if isIncoming && isOtherUserConnected {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.success)
                                }
                            }
                            
                            if let toUser = transfer.toUser {
                                Text("\(toUser.rank ?? "") \(toUser.lastName ?? "")")
                                    .font(AppFonts.bodyBold)
                                    .foregroundColor(AppColors.primaryText)
                                Text("@\(toUser.username)")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Timestamp
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(AppColors.tertiaryText)
                            Text("Requested: \(formatDate(transfer.requestDate))")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                .padding()
                
                // Quick actions for pending incoming transfers
                if isIncoming && transfer.status.lowercased() == "pending" {
                    HStack(spacing: 0) {
                        Button(action: onQuickReject) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("REJECT")
                                    .compatibleKerning(AppFonts.militaryTracking)
                            }
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.destructive)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.destructive.opacity(0.1))
                        }
                        
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(width: 1)
                        
                        Button(action: onQuickApprove) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("APPROVE")
                                    .compatibleKerning(AppFonts.militaryTracking)
                            }
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.success)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.success.opacity(0.1))
                        }
                    }
                    .background(AppColors.tertiaryBackground)
                    .overlay(
                        Rectangle()
                            .stroke(AppColors.border, lineWidth: 1)
                            .allowsHitTesting(false),
                        alignment: .top
                    )
                }
            }
        }
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .stroke(isPressed ? AppColors.accent : AppColors.border, lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .padding(.horizontal)
        .task {
            // Check if the other user is in our connections
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
    
    private func statusBadgeType(for status: String) -> StatusBadge.StatusType {
        switch status.lowercased() {
        case "pending":
            return .warning
        case "approved", "completed":
            return .success
        case "rejected":
            return .error
        default:
            return .neutral
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
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Status Header
                    statusHeader
                    
                    // Property Information
                    sectionContainer(title: "PROPERTY DETAILS") {
                        propertyInfoSection
                    }
                    
                    // Transfer Information
                    sectionContainer(title: "TRANSFER INFORMATION") {
                        transferInfoSection
                    }
                    
                    // Notes section
                    if let notes = transfer.notes, !notes.isEmpty {
                        sectionContainer(title: "NOTES") {
                            Text(notes)
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Actions for pending incoming transfers
                    if viewModel.currentUserId == transfer.toUserId && transfer.status.lowercased() == "pending" {
                        actionSection
                    }
                }
            }
        }
        .navigationTitle("TRANSFER #\(transfer.id)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("DONE") {
                    dismiss()
                }
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.accent)
            }
        }
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
        let statusIcon = statusIcon(for: transfer.status)
        
        return VStack(spacing: 16) {
            // Large status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(statusColor.opacity(0.3), lineWidth: 2)
                    )
                
                Image(systemName: statusIcon)
                    .font(.system(size: 36))
                    .foregroundColor(statusColor)
            }
            
            // Status text
            Text(transfer.status.uppercased())
                .font(AppFonts.title)
                .foregroundColor(statusColor)
                .compatibleKerning(AppFonts.militaryTracking)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .stroke(AppColors.border, lineWidth: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Property Info Section
    private var propertyInfoSection: some View {
        VStack(spacing: 12) {
            TransferDetailRow(label: "ITEM NAME", value: transfer.propertyName ?? "Unknown Item")
            Rectangle().fill(AppColors.border).frame(height: 1)
            TransferDetailRow(label: "SERIAL NUMBER", value: transfer.propertySerialNumber ?? "Unknown", isMonospaced: true)
            Rectangle().fill(AppColors.border).frame(height: 1)
            TransferDetailRow(label: "PROPERTY ID", value: "#\(transfer.propertyId)")
        }
    }
    
    // MARK: - Transfer Info Section
    private var transferInfoSection: some View {
        VStack(spacing: 12) {
            // From User
            if let fromUser = transfer.fromUser {
                UserDetailRow(label: "FROM", user: fromUser)
                Rectangle().fill(AppColors.border).frame(height: 1)
            }
            
            // To User
            if let toUser = transfer.toUser {
                UserDetailRow(label: "TO", user: toUser)
                Rectangle().fill(AppColors.border).frame(height: 1)
            }
            
            // Timestamps
            TransferDetailRow(label: "REQUESTED", value: formatDate(transfer.requestDate))
            
            if let approvalDate = transfer.resolvedDate {
                Rectangle().fill(AppColors.border).frame(height: 1)
                TransferDetailRow(label: "COMPLETED", value: formatDate(approvalDate))
            }
        }
    }
    
    // MARK: - Action Section
    private var actionSection: some View {
        VStack(spacing: 16) {
            Text("PENDING YOUR APPROVAL")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.warning)
                .compatibleKerning(AppFonts.militaryTracking)
                .padding(.top, 24)
            
            HStack(spacing: 16) {
                Button(action: {
                    pendingAction = .reject
                    showingActionConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("REJECT")
                            .compatibleKerning(AppFonts.militaryTracking)
                    }
                    .font(AppFonts.bodyBold)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.destructive)
                .disabled(isProcessing)
                
                Button(action: {
                    pendingAction = .approve
                    showingActionConfirmation = true
                }) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("APPROVE")
                                .compatibleKerning(AppFonts.militaryTracking)
                        }
                        .font(AppFonts.bodyBold)
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.primary)
                .disabled(isProcessing)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Helper Methods
    private func sectionContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text(title)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .compatibleKerning(AppFonts.militaryTracking)
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
            
            // Section content
            content()
                .padding()
                .background(AppColors.secondaryBackground)
                .overlay(
                    Rectangle()
                        .stroke(AppColors.border, lineWidth: 1),
                    alignment: .bottom
                )
        }
    }
    
    private func performAction(_ action: TransferAction) async {
        isProcessing = true
        
        switch action {
        case .approve:
            viewModel.approveTransfer(transferId: transfer.id)
        case .reject:
            viewModel.rejectTransfer(transferId: transfer.id)
        }
        
        dismiss()
        
        // Refresh transfers
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
        case "pending":
            return AppColors.warning
        case "completed", "approved":
            return AppColors.success
        case "rejected":
            return AppColors.destructive
        default:
            return AppColors.secondaryText
        }
    }
    
    private func statusIcon(for status: String) -> String {
        switch status.lowercased() {
        case "pending":
            return "clock.fill"
        case "completed", "approved":
            return "checkmark.circle.fill"
        case "rejected":
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
}

// MARK: - Supporting Views

struct TransferDetailRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.captionBold)
                .foregroundColor(AppColors.tertiaryText)
                .compatibleKerning(AppFonts.militaryTracking)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(isMonospaced ? AppFonts.mono : AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct UserDetailRow: View {
    let label: String
    let user: UserSummary
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(AppFonts.captionBold)
                .foregroundColor(AppColors.tertiaryText)
                .compatibleKerning(AppFonts.militaryTracking)
                .frame(width: 120, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(user.rank ?? "") \(user.lastName ?? "")")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                Text("@\(user.username)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                Text("ID: #\(user.id)")
                    .font(AppFonts.caption)
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
        case .incoming:
            return "Incoming"
        case .outgoing:
            return "Outgoing"
        }
    }
    
    var icon: String {
        switch self {
        case .incoming:
            return "arrow.down"
        case .outgoing:
            return "arrow.up"
        }
    }
}

enum TransferAction {
    case approve
    case reject
}

// MARK: - AuthManager Extension (Placeholder)
extension AuthManager {
    func getCurrentUserId() -> Int? {
        // This should retrieve the actual current user ID from stored auth data
        // For now, returning nil - implement based on your auth system
        return self.getUserId()
    }
}

// MARK: - Offer Row

struct OfferRow: View {
    let offer: TransferOffer
    @State private var showingAcceptDialog = false
    @State private var showingRejectDialog = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Property Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.property?.name ?? "UNKNOWN ITEM")
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                        .compatibleKerning(AppFonts.normalTracking)
                    
                    Text("SN: \(offer.property?.serialNumber ?? "")")
                        .font(AppFonts.mono)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                // Expiration
                if let expiresAt = offer.expiresAt {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("EXPIRES")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                            .compatibleKerning(AppFonts.militaryTracking)
                        
                        Text(formatRelativeDate(expiresAt))
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.warning)
                    }
                }
            }
            
            // From User
            HStack {
                Image(systemName: "gift")
                    .font(.caption)
                    .foregroundColor(AppColors.accent)
                
                Text("Offered by \(offer.offeror?.rank ?? "") \(offer.offeror?.lastName ?? "")")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            // Notes if any
            if let notes = offer.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .italic()
                    .padding(.vertical, 4)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: { showingRejectDialog = true }) {
                    Text("DECLINE")
                        .font(AppFonts.captionBold)
                        .compatibleKerning(AppFonts.militaryTracking)
                        .foregroundColor(AppColors.destructive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppColors.destructive.opacity(0.1))
                        .overlay(
                            Rectangle()
                                .stroke(AppColors.destructive.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Button(action: { showingAcceptDialog = true }) {
                    Text("ACCEPT")
                        .font(AppFonts.captionBold)
                        .compatibleKerning(AppFonts.militaryTracking)
                        .foregroundColor(AppColors.success)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppColors.success.opacity(0.1))
                        .overlay(
                            Rectangle()
                                .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .stroke(AppColors.border, lineWidth: 1)
        )
        .padding(.horizontal)
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

// MARK: - Previews

struct TransfersView_Previews: PreviewProvider {
    static var previews: some View {
        TransfersView()
            .preferredColorScheme(.dark)
    }
} 