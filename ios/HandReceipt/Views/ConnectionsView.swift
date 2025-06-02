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
                return user?.username.localizedCaseInsensitiveContains(searchText) ?? false ||
                       user?.lastName?.localizedCaseInsensitiveContains(searchText) ?? false ||
                       user?.rank?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            AppColors.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    if viewModel.isLoading {
                        ConnectionsLoadingView()
                            .padding(.top, 40)
                    } else {
                        mainContent
                    }
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Header
            UniversalHeaderView(
                title: "Network",
                showBackButton: false,
                trailingButton: {
                    AnyView(
                        Button(action: { showingAddConnection = true }) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }
                    )
                }
            )
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
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 24) {
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
            
            // Bottom spacer
            Spacer()
                .frame(height: 100)
        }
    }
    
    // MARK: - Network Stats Section
    
    private var networkStatsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ModernSectionHeader(
                title: "Network Overview",
                subtitle: "Your connections and pending requests"
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                NetworkStatCard(
                    title: "Connected",
                    value: "\(viewModel.connections.filter { $0.connectionStatus == .accepted }.count)",
                    icon: "person.2.fill",
                    color: AppColors.success
                )
                
                NetworkStatCard(
                    title: "Pending",
                    value: "\(viewModel.pendingRequests.count)",
                    icon: "clock.fill",
                    color: AppColors.warning
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Search and Filter Section
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 16) {
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
            .padding(.horizontal)
            
            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ConnectionFilter.allCases, id: \.self) { filter in
                        ConnectionFilterPill(
                            title: filter.rawValue,
                            icon: filter.icon,
                            count: getCountForFilter(filter),
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Connections List Section
    
    @ViewBuilder
    private var connectionsListSection: some View {
        VStack(spacing: 20) {
            // Pending Requests Section
            if !viewModel.pendingRequests.isEmpty && (selectedFilter == .all || selectedFilter == .pending) {
                VStack(alignment: .leading, spacing: 16) {
                    ModernSectionHeader(
                        title: "Pending Requests",
                        subtitle: "\(viewModel.pendingRequests.count) waiting for your response"
                    )
                    
                    VStack(spacing: 12) {
                        ForEach(viewModel.pendingRequests) { request in
                            ModernPendingRequestRow(request: request) {
                                viewModel.acceptConnection(request.id)
                            } onReject: {
                                viewModel.rejectConnection(request.id)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Active Connections Section
            if !filteredConnections.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ModernSectionHeader(
                        title: selectedFilter == .pending ? "Pending Connections" : "Connected Users",
                        subtitle: "\(filteredConnections.count) in your network"
                    )
                    
                    VStack(spacing: 12) {
                        ForEach(filteredConnections) { connection in
                            ModernConnectionRow(connection: connection) {
                                // TODO: Handle connection action (view profile, message, etc.)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Empty filter results
            if filteredConnections.isEmpty && !viewModel.pendingRequests.isEmpty && searchText.isEmpty {
                ModernEmptyStateView(
                    icon: "line.horizontal.3.decrease.circle",
                    title: "No \(selectedFilter.rawValue) Connections",
                    message: "Try adjusting your filter to see more connections."
                )
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Empty Network View
    
    private var emptyNetworkView: some View {
        ModernEmptyStateView(
            icon: "person.2",
            title: "No Connections Yet",
            message: "Connect with other users to request and transfer property items",
            actionTitle: "ADD CONNECTION",
            action: { showingAddConnection = true }
        )
        .padding(.horizontal)
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

// MARK: - Network Stat Card
struct NetworkStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(AppFonts.largeTitleHeavy)
                .foregroundColor(AppColors.primaryText)
            
            Text(title.uppercased())
                .font(AppFonts.captionBold)
                .foregroundColor(AppColors.secondaryText)
                .compatibleKerning(AppFonts.wideTracking)
        }
        .modernCard()
    }
}

// MARK: - Connection Filter Pill
struct ConnectionFilterPill: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title.uppercased())
                    .font(AppFonts.captionBold)
                    .compatibleKerning(AppFonts.wideTracking)
                if count > 0 {
                    Text("(\(count))")
                        .font(AppFonts.captionBold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? Color.black : AppColors.secondaryText)
            .background(
                Group {
                    if isSelected {
                        AppColors.accent
                    } else {
                        AppColors.secondaryBackground
                    }
                }
            )
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
            )
            .shadow(
                color: isSelected ? AppColors.accent.opacity(0.3) : Color.clear,
                radius: isSelected ? 4 : 0,
                y: isSelected ? 2 : 0
            )
        }
    }
}

// MARK: - Modern Connection Row
struct ModernConnectionRow: View {
    let connection: UserConnection
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // User Avatar
                ZStack {
                    Circle()
                        .fill(AppColors.success.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Text((connection.connectedUser?.lastName ?? connection.connectedUser?.username ?? "?").prefix(1))
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.success)
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    if let user = connection.connectedUser {
                        Text("\(user.rank ?? "") \(user.lastName ?? user.username)")
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("@\(user.username)")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                Spacer()
                
                // Connection Status
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.success)
                        .font(.system(size: 16))
                    
                    Text("CONNECTED")
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.success)
                        .compatibleKerning(AppFonts.militaryTracking)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .modernCard(isElevated: false)
    }
}

// MARK: - Modern Pending Request Row
struct ModernPendingRequestRow: View {
    let request: ConnectionRequest
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // User Avatar
                ZStack {
                    Circle()
                        .fill(AppColors.warning.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Text((request.requester.lastName ?? request.requester.username).prefix(1))
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.warning)
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(request.requester.rank ?? "") \(request.requester.lastName ?? request.requester.username)")
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("@\(request.requester.username)")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("Wants to connect")
                            .font(AppFonts.caption)
                    }
                    .foregroundColor(AppColors.warning)
                }
                
                Spacer()
                
                // Pending Indicator
                VStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(AppColors.warning)
                        .font(.system(size: 16))
                    
                    Text("PENDING")
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.warning)
                        .compatibleKerning(AppFonts.militaryTracking)
                }
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: onReject) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text("DECLINE")
                            .compatibleKerning(AppFonts.militaryTracking)
                    }
                    .font(AppFonts.captionBold)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.destructive)
                
                Button(action: onAccept) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text("ACCEPT")
                            .compatibleKerning(AppFonts.militaryTracking)
                    }
                    .font(AppFonts.captionBold)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Add Connection View
struct AddConnectionView: View {
    @State private var searchText = ""
    @StateObject private var viewModel = AddConnectionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                AppColors.appBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // Search Section
                    VStack(alignment: .leading, spacing: 16) {
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
                        .padding(.horizontal)
                    }
                    
                    // Search Results
                    if viewModel.isLoading {
                        Spacer()
                        IndustrialLoadingView(message: "SEARCHING USERS")
                        Spacer()
                    } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                        ModernEmptyStateView(
                            icon: "magnifyingglass",
                            title: "No Users Found", 
                            message: "Try different search terms or check the spelling."
                        )
                        .padding(.horizontal)
                        .padding(.top, 40)
                    } else if !viewModel.searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            ModernSectionHeader(
                                title: "Search Results",
                                subtitle: "\(viewModel.searchResults.count) users found"
                            )
                            
                            ScrollView {
                                VStack(spacing: 12) {
                                    ForEach(viewModel.searchResults) { user in
                                        ModernUserSearchResultRow(user: user) {
                                            viewModel.sendConnectionRequest(to: user.id)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    } else {
                        ModernEmptyStateView(
                            icon: "person.badge.plus",
                            title: "Search for Users",
                            message: "Enter a name, rank, or username to find users to connect with."
                        )
                        .padding(.horizontal)
                        .padding(.top, 40)
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

// MARK: - Modern User Search Result Row
struct ModernUserSearchResultRow: View {
    let user: UserSummary
    let onConnect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // User Avatar
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Text((user.lastName ?? user.username).prefix(1))
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.accent)
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text("\(user.rank ?? "") \(user.lastName ?? user.username)")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                
                Text("@\(user.username)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            // Connect Button
            Button(action: onConnect) {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("CONNECT")
                        .compatibleKerning(AppFonts.militaryTracking)
                }
                .font(AppFonts.captionBold)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.secondary)
        }
        .padding()
        .modernCard(isElevated: false)
    }
}

// MARK: - Loading View
struct ConnectionsLoadingView: View {
    var body: some View {
        IndustrialLoadingView(message: "LOADING NETWORK")
    }
}

// MARK: - Preview
struct ConnectionsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionsView()
            .preferredColorScheme(.dark)
    }
} 