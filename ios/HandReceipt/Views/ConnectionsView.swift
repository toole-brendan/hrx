import SwiftUI

// MARK: - Connections View
struct ConnectionsView: View {
    @StateObject private var viewModel = ConnectionsViewModel()
    @State private var showingAddConnection = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ConnectionsLoadingView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            
                            // Connections Section
                            if !viewModel.connections.isEmpty {
                                VStack(spacing: 12) {
                                    NetworkSectionHeader(
                                        title: "MY NETWORK",
                                        subtitle: "\(viewModel.connections.count) connected",
                                        icon: "person.2.fill"
                                    )
                                    
                                    ForEach(viewModel.connections) { connection in
                                        ConnectionRow(connection: connection) {
                                            // TODO: Handle connection action
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // Pending Requests Section
                            if !viewModel.pendingRequests.isEmpty {
                                VStack(spacing: 12) {
                                    NetworkSectionHeader(
                                        title: "PENDING REQUESTS",
                                        subtitle: "\(viewModel.pendingRequests.count) waiting",
                                        icon: "clock"
                                    )
                                    
                                    ForEach(viewModel.pendingRequests) { request in
                                        PendingRequestRow(request: request) {
                                            viewModel.acceptConnection(request.id)
                                        } onReject: {
                                            viewModel.rejectConnection(request.id)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // Empty State
                            if viewModel.connections.isEmpty && viewModel.pendingRequests.isEmpty {
                                EmptyNetworkView {
                                    showingAddConnection = true
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 40)
                            }
                            
                            Spacer(minLength: 100)
                        }
                        .padding(.top, 16)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("My Network")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddConnection = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.title3)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAddConnection) {
                AddConnectionView()
            }
            .onAppear {
                viewModel.loadConnections()
            }
        }
    }
}

// MARK: - Network Section Header
struct NetworkSectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.accent)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                        .tracking(AppFonts.militaryTracking)
                    
                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Connection Row
struct ConnectionRow: View {
    let connection: UserConnection
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // User Avatar
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Text((connection.connectedUser?.lastName ?? connection.connectedUser?.username ?? "?").prefix(1))
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.accent)
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
                
                Text("CONNECTED")
                    .font(AppFonts.micro)
                    .foregroundColor(AppColors.success)
                    .tracking(AppFonts.militaryTracking)
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .stroke(AppColors.border, lineWidth: 1)
        )
        .onTapGesture(perform: action)
    }
}

// MARK: - Pending Request Row
struct PendingRequestRow: View {
    let request: ConnectionRequest
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
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
                    
                    Text("Wants to connect")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.warning)
                }
                
                Spacer()
                
                // Pending Indicator
                Image(systemName: "clock")
                    .foregroundColor(AppColors.warning)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: onReject) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("DECLINE")
                            .tracking(AppFonts.militaryTracking)
                    }
                    .font(AppFonts.captionBold)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.destructive)
                
                Button(action: onAccept) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("ACCEPT")
                            .tracking(AppFonts.militaryTracking)
                    }
                    .font(AppFonts.captionBold)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Empty Network View
struct EmptyNetworkView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.2")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.accent)
            }
            
            // Text
            VStack(spacing: 8) {
                Text("NO CONNECTIONS YET")
                    .font(AppFonts.title)
                    .foregroundColor(AppColors.primaryText)
                    .tracking(AppFonts.militaryTracking)
                
                Text("Connect with other users to request and transfer property items")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Action Button
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                    Text("ADD CONNECTION")
                        .tracking(AppFonts.militaryTracking)
                }
                .font(AppFonts.bodyBold)
                .frame(width: 200)
            }
            .buttonStyle(.primary)
        }
    }
}

// MARK: - Add Connection View
struct AddConnectionView: View {
    @State private var searchText = ""
    @StateObject private var viewModel = AddConnectionViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Search Bar
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SEARCH USERS")
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.tertiaryText)
                            .tracking(AppFonts.militaryTracking)
                        
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppColors.secondaryText)
                            
                            TextField("Name, rank, or phone number", text: $searchText)
                                .font(AppFonts.body)
                                .onSubmit {
                                    viewModel.searchUsers(query: searchText)
                                }
                        }
                        .padding()
                        .background(AppColors.secondaryBackground)
                        .overlay(
                            Rectangle()
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Search Results
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        Spacer()
                    } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                        Spacer()
                        Text("NO USERS FOUND")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                            .tracking(AppFonts.militaryTracking)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.searchResults) { user in
                                    UserSearchResultRow(user: user) {
                                        viewModel.sendConnectionRequest(to: user.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .navigationTitle("Add Connection")
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

// MARK: - User Search Result Row
struct UserSearchResultRow: View {
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
                    .font(AppFonts.body)
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
                        .font(.caption)
                    Text("CONNECT")
                        .tracking(AppFonts.militaryTracking)
                }
                .font(AppFonts.captionBold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.secondary)
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Loading View
struct ConnectionsLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                .scaleEffect(1.2)
            
            Text("LOADING NETWORK...")
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
                .tracking(AppFonts.militaryTracking)
        }
    }
}

// MARK: - Preview
struct ConnectionsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionsView()
            .preferredColorScheme(.dark)
    }
} 