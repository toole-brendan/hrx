import SwiftUI

// MARK: - Connections View
struct ConnectionsView: View {
    @StateObject private var viewModel = ConnectionsViewModel()
    @State private var showingAddConnection = false
    @State private var searchText = ""
    @State private var selectedFilter: ConnectionFilter = .all
    @Environment(\.dismiss) private var dismiss
    
    enum ConnectionFilter: String, CaseIterable {
        case all = "All"
        case connected = "Connected" 
        case pending = "Pending"
        
        var icon: String {
            switch self {
            case .all: return "person.2"
            case .connected: return "person.2.fill"
            case .pending: return "clock"
            }
        }
    }
    
    var filteredConnections: [UserConnection] {
        let connections = viewModel.connections
        let filtered = switch selectedFilter {
        case .all:
            connections
        case .connected:
            connections.filter { $0.connectionStatus == .accepted }
        case .pending:
            connections.filter { $0.connectionStatus == .pending }
        }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { connection in
                let user = connection.connectedUser
                return user?.email?.localizedCaseInsensitiveContains(searchText) ?? false ||
                       user?.lastName?.localizedCaseInsensitiveContains(searchText) ?? false ||
                       user?.rank?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Opaque background
            AppColors.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom minimal navigation bar - matches MyPropertiesView
                MinimalNavigationBar(
                    title: "NETWORK",
                    titleStyle: .mono,
                    showBackButton: false,
                    trailingItems: [
                        .init(icon: "person.badge.plus", action: { showingAddConnection = true })
                    ]
                )
                .background(AppColors.secondaryBackground)
                .zIndex(1)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Main content
                        if viewModel.isLoading {
                            loadingView
                        } else {
                            mainContent
                        }
                        
                        // Bottom padding
                        Color.clear.frame(height: 80)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddConnection) {
            AddConnectionView()
                .onDisappear {
                    viewModel.loadConnections()
                }
        }
        .onAppear {
            viewModel.loadConnections()
        }
        .minimalRefreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                .scaleEffect(0.8)
            
            Text("LOADING NETWORK")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .kerning(AppFonts.wideKerning)
        }
        .padding(.top, 40)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 32) {
            // Network Overview Stats
            networkStatsSection
            
            // Search and Filter Section
            searchAndFilterSection
            
            // Connections Content
            if hasAnyConnections {
                connectionsListSection
            } else {
                emptyNetworkView
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Network Stats Section
    private var networkStatsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ModernSectionHeader(
                title: "Network Overview",
                subtitle: "Your connections and pending requests"
            )
            
            HStack(spacing: 16) {
                CleanStatCard(
                    title: "Connected",
                    value: String(format: "%02d", viewModel.connections.filter { $0.connectionStatus == .accepted }.count),
                    icon: "person.2"
                )
                
                CleanStatCard(
                    title: "Pending",
                    value: String(format: "%02d", viewModel.pendingRequests.count),
                    icon: "clock"
                )
            }
        }
    }
    
    // MARK: - Search and Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 20) {
            // Search bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.tertiaryText)
                        .font(.system(size: 16, weight: .medium))
                    
                    TextField("Search connections...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(AppColors.primaryText)
                        .font(AppFonts.body)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.tertiaryText)
                                .font(.system(size: 14))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppColors.secondaryBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
            
            // Filter pills
            HStack(spacing: 12) {
                ForEach(ConnectionFilter.allCases, id: \.self) { filter in
                    CleanFilterPill(
                        title: filter.rawValue,
                        icon: filter.icon,
                        count: getCountForFilter(filter),
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Connections List Section
    @ViewBuilder
    private var connectionsListSection: some View {
        VStack(spacing: 24) {
            // Pending Requests Section
            if !viewModel.pendingRequests.isEmpty && (selectedFilter == .all || selectedFilter == .pending) {
                VStack(alignment: .leading, spacing: 16) {
                    ModernSectionHeader(
                        title: "Pending Requests",
                        subtitle: "\(viewModel.pendingRequests.count) awaiting response"
                    )
                    
                    VStack(spacing: 12) {
                        ForEach(viewModel.pendingRequests) { request in
                            CleanPendingRequestCard(request: request) {
                                viewModel.acceptConnection(request.id)
                            } onReject: {
                                viewModel.rejectConnection(request.id)
                            }
                        }
                    }
                }
            }
            
            // Connected Users Section
            if !filteredConnections.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ModernSectionHeader(
                        title: selectedFilter == .pending ? "Outgoing Requests" : "Connected Users",
                        subtitle: "\(filteredConnections.count) in your network"
                    )
                    
                    VStack(spacing: 12) {
                        ForEach(filteredConnections) { connection in
                            CleanConnectionCard(connection: connection) {
                                // TODO: Handle connection action (view profile, message, etc.)
                            }
                        }
                    }
                }
            }
            
            // Empty filter results
            if filteredConnections.isEmpty && !viewModel.pendingRequests.isEmpty && searchText.isEmpty {
                MinimalEmptyState(
                    icon: "line.horizontal.3.decrease.circle",
                    title: "No \(selectedFilter.rawValue) Connections",
                    message: "Try adjusting your filter to see more connections."
                )
            }
        }
    }
    
    // MARK: - Empty Network View
    private var emptyNetworkView: some View {
        MinimalEmptyState(
            icon: "person.2",
            title: "No Connections Yet",
            message: "Connect with other users to share and transfer property items seamlessly.",
            action: { showingAddConnection = true },
            actionLabel: "Add Connection"
        )
        .padding(.top, 40)
    }
    
    // MARK: - Helper Properties
    private var hasAnyConnections: Bool {
        !viewModel.connections.isEmpty || !viewModel.pendingRequests.isEmpty
    }
    
    private func getCountForFilter(_ filter: ConnectionFilter) -> Int {
        switch filter {
        case .all:
            return viewModel.connections.count + viewModel.pendingRequests.count
        case .connected:
            return viewModel.connections.filter { $0.connectionStatus == .accepted }.count
        case .pending:
            return viewModel.pendingRequests.count
        }
    }
}

// MARK: - Clean Stat Card (8VC-styled)
struct CleanStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(AppColors.accent)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.primaryText)
                
                Text(title.uppercased())
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .compatibleKerning(1.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modernCard()
    }
}

// MARK: - Clean Filter Pill (8VC-styled)
struct CleanFilterPill: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                    Text(title.uppercased())
                        .font(AppFonts.captionBold)
                        .compatibleKerning(1.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.quaternaryText)
                }
                
                Rectangle()
                    .fill(isSelected ? AppColors.primaryText : Color.clear)
                    .frame(height: 2)
            }
            .foregroundColor(isSelected ? AppColors.primaryText : AppColors.tertiaryText)
            .padding(.horizontal, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Clean Connection Card (8VC-styled)
struct CleanConnectionCard: View {
    let connection: UserConnection
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // User Avatar
                Circle()
                    .fill(AppColors.success.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                                                    Text((connection.connectedUser?.lastName ?? "?").prefix(1))
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.success)
                    )
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    if let user = connection.connectedUser {
                        Text("\(user.rank ?? "") \(user.lastName ?? "Unknown")")
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(user.email ?? "No email")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                Spacer()
                
                // Connection Status
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(AppColors.success)
                        .font(.system(size: 16, weight: .light))
                    
                    Text("CONNECTED")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.success)
                        .compatibleKerning(1.2)
                }
            }
            .padding(20)
        }
        .buttonStyle(PlainButtonStyle())
        .modernCard(isElevated: false)
    }
}

// MARK: - Clean Pending Request Card (8VC-styled)
struct CleanPendingRequestCard: View {
    let request: ConnectionRequest
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                // User Avatar
                Circle()
                    .fill(AppColors.warning.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                                                    Text((request.requester.lastName ?? "?").prefix(1))
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.warning)
                    )
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                                            Text("\(request.requester.rank ?? "") \(request.requester.lastName ?? "Unknown")")
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                    
                                            Text(request.requester.email ?? "No email")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Text("Wants to connect")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.warning)
                        .italic()
                }
                
                Spacer()
                
                // Pending Indicator
                VStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(AppColors.warning)
                        .font(.system(size: 16, weight: .light))
                    
                    Text("PENDING")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.warning)
                        .compatibleKerning(1.2)
                }
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: onReject) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .regular))
                        Text("DECLINE")
                            .compatibleKerning(1.2)
                    }
                    .font(AppFonts.captionBold)
                }
                .buttonStyle(.secondary)
                
                Button(action: onAccept) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .regular))
                        Text("ACCEPT")
                            .compatibleKerning(1.2)
                    }
                    .font(AppFonts.captionBold)
                }
                .buttonStyle(.primary)
            }
        }
        .modernCard()
    }
}

// MARK: - Add Connection View (Updated with existing components)
struct AddConnectionView: View {
    @State private var searchText = ""
    @StateObject private var viewModel = AddConnectionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                AppColors.appBackground.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Spacer for header
                    Color.clear.frame(height: 36)
                    
                    // Search Section
                    VStack(spacing: 24) {
                        ModernSectionHeader(
                            title: "Find Users",
                            subtitle: "Search by name, rank, or username"
                        )
                        
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppColors.secondaryText)
                                .font(.system(size: 18))
                            
                            TextField("Name, rank, or username", text: $searchText)
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.primaryText)
                                .onSubmit {
                                    if !searchText.isEmpty {
                                        viewModel.searchUsers(query: searchText)
                                    }
                                }
                        }
                        .padding()
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Search Results
                    if viewModel.isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                                .scaleEffect(0.8)
                            
                            Text("SEARCHING USERS")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .kerning(AppFonts.wideKerning)
                        }
                    } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                        MinimalEmptyState(
                            icon: "magnifyingglass",
                            title: "No Users Found", 
                            message: "Try different search terms or check the spelling."
                        )
                        .padding(.horizontal, 24)
                    } else if !viewModel.searchResults.isEmpty {
                        VStack(spacing: 16) {
                            ModernSectionHeader(
                                title: "Search Results",
                                subtitle: "\(viewModel.searchResults.count) users found"
                            )
                            .padding(.horizontal, 24)
                            
                            VStack(spacing: 12) {
                                ForEach(viewModel.searchResults) { user in
                                    CleanUserSearchResultCard(user: user) {
                                        viewModel.sendConnectionRequest(to: user.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    } else {
                        MinimalEmptyState(
                            icon: "person.badge.plus",
                            title: "Search for Users",
                            message: "Enter a name, rank, or username to find users to connect with."
                        )
                        .padding(.horizontal, 24)
                    }
                }
                
                // Header
                UniversalHeaderView(
                    title: "Add Connection",
                    showBackButton: true,
                    backButtonAction: { dismiss() }
                )
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Clean User Search Result Card (8VC-styled)
struct CleanUserSearchResultCard: View {
    let user: UserSummary
    let onConnect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // User Avatar
            Circle()
                .fill(AppColors.accent.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                                                Text((user.lastName ?? "?").prefix(1))
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.accent)
                )
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                                    Text("\(user.rank ?? "") \(user.lastName ?? "Unknown")")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                
                                    Text(user.email ?? "No email")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            // Connect Button
            Button(action: onConnect) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14, weight: .regular))
                    Text("CONNECT")
                        .compatibleKerning(1.2)
                }
                .font(AppFonts.captionBold)
            }
            .buttonStyle(.secondary)
        }
        .modernCard(isElevated: false)
    }
}

// MARK: - Preview
struct ConnectionsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionsView()
    }
} 