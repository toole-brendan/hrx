import SwiftUI

struct TransfersView: View {
    @StateObject private var viewModel: TransfersViewModel
    @State private var selectedTab = TransferTab.incoming
    @State private var showingTransferOptions = false
    @State private var showingSerialRequest = false
    @State private var activeOffers: [TransferOffer] = []
    @State private var selectedTransfer: Transfer?
    @State private var showingFilterOptions = false
    @State private var isLoadingOffers = true
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
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom minimal navigation bar - matches MyPropertiesView
                MinimalNavigationBar(
                    title: "TRANSFERS",
                    titleStyle: .mono,
                    trailingItems: [
                        .init(text: "New", style: .text, action: { showingTransferOptions = true })
                    ]
                )
                
                // Tab selector with proper styling
                tabSelector
                
                // Main content - fill all available space
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Content with proper spacing
                        transferMainContent
                        
                        // Reduced bottom padding for tab bar
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
    

    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        VStack(spacing: 0) {
            HStack(spacing: 40) {
                ForEach(TransferTab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.title,
                        isSelected: selectedTab == tab,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppColors.tertiaryBackground)
            
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
        }
    }
    
    // MARK: - Tab Button Component
    struct TabButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Text(title.uppercased())
                        .font(AppFonts.captionMedium)
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.tertiaryText)
                        .compatibleKerning(AppFonts.wideKerning)
                    
                    Rectangle()
                        .fill(isSelected ? AppColors.accent : Color.clear)
                        .frame(height: 2)
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Transfer Main Content
    @ViewBuilder
    private var transferMainContent: some View {
        let transfers = viewModel.filteredTransfers.filter { transfer in
            guard let currentUserId = viewModel.currentUserId else { return false }
            
            if selectedTab == .incoming {
                // Incoming: transfers TO you or transfers initiated BY others affecting you
                if transfer.transferType?.lowercased() == "request" {
                    // For requests: incoming means someone else requested something from you
                    return transfer.initiatorId != currentUserId && transfer.fromUserId == currentUserId
                } else {
                    // For direct transfers: incoming means transfers coming to you
                    return transfer.toUserId == currentUserId
                }
            } else {
                // Outgoing: transfers FROM you or transfers initiated BY you
                if transfer.transferType?.lowercased() == "request" {
                    // For requests: outgoing means you requested something from someone
                    return transfer.initiatorId == currentUserId
                } else {
                    // For direct transfers: outgoing means transfers going from you
                    return transfer.fromUserId == currentUserId
                }
            }
        }
        
        if case .loading = viewModel.loadingState {
            loadingView
        } else {
            VStack(spacing: 32) {
                // Active offers section (only for incoming tab)
                if selectedTab == .incoming {
                    offersSection
                }
                
                // Transfer requests section
                transfersSection(transfers: transfers)
            }
            .refreshable {
                await MainActor.run {
                    viewModel.fetchTransfers()
                }
                await loadActiveOffers()
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                .scaleEffect(0.8)
            
            Text("Loading transfers...")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        MinimalEmptyState(
            icon: selectedTab == .incoming ? "arrow.down.circle" : "arrow.up.circle",
            title: "No \(selectedTab.title) Transfers",
            message: selectedTab == .incoming ?
                "Transfer requests from your connections will appear here." :
                "Your outgoing transfer requests will appear here.",
            action: selectedTab == .outgoing ? { showingTransferOptions = true } : nil,
            actionLabel: selectedTab == .outgoing ? "Create Transfer" : nil
        )
    }
    
    // MARK: - Offers Section
    @ViewBuilder
    private var offersSection: some View {
        VStack(spacing: 12) {
            if isLoadingOffers {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                        .scaleEffect(0.7)
                    
                    Text("Loading offers...")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .cleanCard(showShadow: false)
            } else if activeOffers.isEmpty {
                HStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 24, weight: .thin))
                        .foregroundColor(AppColors.tertiaryText)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Property Offers")
                            .font(AppFonts.bodyMedium)
                            .foregroundColor(AppColors.secondaryText)
                        
                        Text("Offers from connections will appear here")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .cleanCard(showShadow: false)
            } else {
                VStack(spacing: 12) {
                    ForEach(activeOffers) { offer in
                        ElegantOfferCard(offer: offer)
                    }
                }
            }
        }
    }
    
    // MARK: - Transfers Section
    @ViewBuilder
    private func transfersSection(transfers: [Transfer]) -> some View {
        if !transfers.isEmpty {
            VStack(spacing: 12) {
                ForEach(transfers) { transfer in
                    ElegantTransferCard(
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
        } else if !isLoadingOffers && activeOffers.isEmpty {
            emptyStateView
        }
    }
    
    private func loadActiveOffers() async {
        isLoadingOffers = true
        do {
            let offers = try await TransferService.shared.getActiveOffers()
            await MainActor.run {
                activeOffers = offers
                isLoadingOffers = false
            }
        } catch {
            print("Failed to load offers: \(error)")
            await MainActor.run {
                activeOffers = []
                isLoadingOffers = false
            }
        }
    }
}

// MARK: - Elegant Transfer Card (8VC-styled)
struct ElegantTransferCard: View {
    let transfer: Transfer
    let isIncoming: Bool
    let onTap: () -> Void
    let onQuickApprove: () -> Void
    let onQuickReject: () -> Void
    
    @State private var isPressed = false
    
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
                    // Property header with serif font
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transfer.propertyName ?? "Unknown Item")
                            .font(AppFonts.serifHeadline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("SN: \(transfer.propertySerialNumber ?? "Unknown")")
                            .font(AppFonts.monoCaption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    // Transfer participants with improved layout
                    HStack(spacing: 32) {
                        // From
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FROM")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                                .compatibleKerning(AppFonts.wideKerning)
                            
                            if let fromUser = transfer.fromUser {
                                Text("\(fromUser.rank ?? "") \(fromUser.lastName ?? "")")
                                    .font(AppFonts.bodyMedium)
                                    .foregroundColor(AppColors.primaryText)
                                Text(fromUser.email ?? "No email")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(AppColors.tertiaryText)
                        
                        // To
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TO")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                                .compatibleKerning(AppFonts.wideKerning)
                            
                            if let toUser = transfer.toUser {
                                Text("\(toUser.rank ?? "") \(toUser.lastName ?? "")")
                                    .font(AppFonts.bodyMedium)
                                    .foregroundColor(AppColors.primaryText)
                                Text(toUser.email ?? "No email")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                    }
                    
                    // Status and timestamp
                    HStack {
                        Text(transfer.status.uppercased())
                            .font(AppFonts.captionMedium)
                            .foregroundColor(statusColor)
                            .compatibleKerning(AppFonts.wideKerning)
                        
                        Spacer()
                        
                        Text(formatDate(transfer.requestDate))
                            .font(AppFonts.monoCaption)
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
                                    .compatibleKerning(AppFonts.wideKerning)
                            }
                            .font(AppFonts.captionMedium)
                            .foregroundColor(AppColors.destructive)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(width: 1)
                        
                        Button(action: onQuickApprove) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .regular))
                                Text("APPROVE")
                                    .compatibleKerning(AppFonts.wideKerning)
                            }
                            .font(AppFonts.captionMedium)
                            .foregroundColor(AppColors.success)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                    }
                    .background(AppColors.tertiaryBackground)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .cleanCard()
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM HH:mm"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Elegant Offer Card (8VC-styled)
struct ElegantOfferCard: View {
    let offer: TransferOffer
    @State private var showingAcceptDialog = false
    @State private var showingRejectDialog = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Property info with serif heading
            VStack(alignment: .leading, spacing: 8) {
                Text(offer.property?.name ?? "Unknown Item")
                    .font(AppFonts.serifHeadline)
                    .foregroundColor(AppColors.primaryText)
                
                Text("SN: \(offer.property?.serialNumber ?? "")")
                    .font(AppFonts.monoCaption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            // Offer details with improved typography
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SENT BY")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                        .compatibleKerning(AppFonts.wideKerning)
                    
                    Text(offer.offeringUserDisplayName)
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(AppColors.primaryText)
                }
                
                Spacer()
                
                if let expiresAt = offer.expiresAt {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("EXPIRES")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                            .compatibleKerning(AppFonts.wideKerning)
                        
                        Text(formatRelativeDate(expiresAt))
                            .font(AppFonts.captionMedium)
                            .foregroundColor(AppColors.warning)
                    }
                }
            }
            
            // Notes with serif italic
            if let notes = offer.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .italic()
            }
            
            // Action buttons with 8VC styling
            HStack(spacing: 16) {
                Button(action: { showingRejectDialog = true }) {
                    Text("DECLINE")
                        .font(AppFonts.captionMedium)
                        .compatibleKerning(AppFonts.wideKerning)
                        .foregroundColor(AppColors.destructive)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppColors.destructive, lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { showingAcceptDialog = true }) {
                    Text("ACCEPT")
                        .font(AppFonts.captionMedium)
                        .compatibleKerning(AppFonts.wideKerning)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(AppColors.success)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .cleanCard()
        .alert("Accept Offer?", isPresented: $showingAcceptDialog) {
            Button("Cancel", role: .cancel) { }
            Button("Accept") {
                Task {
                    try? await TransferService.shared.acceptOffer(offer.id)
                }
            }
        } message: {
            Text("Accept this property transfer offer from \(offer.offeringUserDisplayName)?")
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