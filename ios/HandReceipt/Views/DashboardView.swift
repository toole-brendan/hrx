// handreceipt/ios/HandReceipt/Views/DashboardView.swift

import SwiftUI

struct DashboardView: View {
    @State private var selectedQuickAction: QuickAction? = nil
    @State private var currentUser: LoginResponse.User?
    @EnvironmentObject var authManager: AuthManager
    
    // Navigation states
    @State private var navigateToTransfers = false
    @State private var navigateToProperties = false
    @State private var navigateToMaintenance = false
    @State private var navigateToSensitiveItems = false
    @State private var selectedTransferId: String?
    
    // Real data from API
    @State private var totalProperties = 0
    @State private var pendingTransfers = 0
    @State private var verifiedItems = (verified: 0, total: 0)
    @State private var maintenanceNeeded = 0
    @State private var recentTransfers: [Transfer] = []
    @State private var properties: [Property] = []
    @State private var connections: [UserConnection] = []
    @State private var pendingConnectionRequests = 0
    
    // Loading states
    @State private var isLoading = true
    @State private var loadingError: String?
    
    // Services
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            if isLoading {
                IndustrialLoadingView(message: "LOADING DASHBOARD")
            } else if let error = loadingError {
                ModernEmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Error Loading Dashboard",
                    message: error,
                    actionTitle: "RETRY",
                    action: { Task { await refreshData() } }
                )
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Section
                        heroSection
                        
                        // Stats Overview
                        statsSection
                        
                        // Quick Actions
                        quickActionsSection
                        
                        // Content Sections
                        VStack(spacing: 20) {
                            connectionsSection
                            recentActivitySection
                            equipmentStatusSection
                        }
                        .padding(.horizontal)
                        
                        // Bottom spacing
                        Spacer()
                            .frame(height: 100)
                    }
                }
                .refreshable {
                    await refreshData()
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .background(navigationLinks)
        .task {
            await loadData()
        }
    }
    
    // MARK: - Enhanced View Sections
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            // Header with enhanced typography
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DASHBOARD")
                        .font(AppFonts.captionHeavy)
                        .foregroundColor(AppColors.secondaryText)
                        .compatibleKerning(AppFonts.militaryTracking)
                    
                    Text(getWelcomeMessage())
                        .font(AppFonts.largeTitleHeavy)
                        .foregroundColor(AppColors.primaryText)
                }
                
                Spacer()
                
                // Optional: Add profile/settings button
                Button(action: { /* Navigate to profile */ }) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
        }
    }
    
    private var statsSection: some View {
        VStack(spacing: 16) {
            ModernSectionHeader(
                title: "Overview",
                subtitle: "Your property and transfer summary"
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ModernStatCard(
                    title: "Total Properties",
                    value: "\(totalProperties)",
                    icon: "shippingbox.fill",
                    color: AppColors.accent
                ) {
                    navigateToProperties = true
                }
                
                ModernStatCard(
                    title: "Pending Transfers", 
                    value: "\(pendingTransfers)",
                    icon: "arrow.left.arrow.right.circle.fill",
                    color: AppColors.warning
                ) {
                    navigateToTransfers = true
                }
                
                ModernStatCard(
                    title: "Items Verified",
                    value: "\(verifiedItems.verified)/\(verifiedItems.total)",
                    icon: "checkmark.shield.fill",
                    color: AppColors.success
                ) {
                    navigateToSensitiveItems = true
                }
                
                ModernStatCard(
                    title: "Need Maintenance",
                    value: "\(maintenanceNeeded)",
                    icon: "exclamationmark.triangle.fill",
                    color: AppColors.destructive
                ) {
                    navigateToMaintenance = true
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            ModernSectionHeader(
                title: "Quick Actions",
                subtitle: "Common tasks and operations"
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    QuickActionButton(
                        icon: "arrow.left.arrow.right",
                        title: "TRANSFER",
                        color: AppColors.accent,
                        action: { navigateToTransfers = true }
                    )
                    
                    QuickActionButton(
                        icon: "magnifyingglass",
                        title: "SEARCH",
                        color: AppColors.success,
                        action: { navigateToProperties = true }
                    )
                    
                    QuickActionButton(
                        icon: "person.badge.plus",
                        title: "CONNECT",
                        color: AppColors.tacticalGreen,
                        action: { /* Navigate to connections */ }
                    )
                    
                    QuickActionButton(
                        icon: "wrench.and.screwdriver",
                        title: "MAINTENANCE",
                        color: AppColors.warning,
                        action: { navigateToMaintenance = true }
                    )
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModernSectionHeader(
                title: "My Network",
                subtitle: "Connected users and pending requests",
                action: { /* Navigate to connections */ },
                actionLabel: "View All"
            )
            
            HStack(spacing: 16) {
                // Connected Users Card
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.success)
                        
                        Text("\(connections.count)")
                            .font(AppFonts.largeTitleHeavy)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    Text("CONNECTED")
                        .font(AppFonts.captionHeavy)
                        .foregroundColor(AppColors.secondaryText)
                        .compatibleKerning(AppFonts.militaryTracking)
                }
                .frame(maxWidth: .infinity)
                .modernCard()
                
                // Pending Requests Card
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.title2)
                            .foregroundColor(AppColors.warning)
                        
                        Text("\(pendingConnectionRequests)")
                            .font(AppFonts.largeTitleHeavy)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    Text("PENDING")
                        .font(AppFonts.captionHeavy)
                        .foregroundColor(AppColors.secondaryText)
                        .compatibleKerning(AppFonts.militaryTracking)
                }
                .frame(maxWidth: .infinity)
                .modernCard()
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModernSectionHeader(
                title: "Recent Activity",
                subtitle: "Latest transfers and updates",
                action: { navigateToTransfers = true },
                actionLabel: "View All"
            )
            
            if recentTransfers.isEmpty {
                ModernEmptyStateView(
                    icon: "clock",
                    title: "No Recent Activity",
                    message: "Transfer requests and property updates will appear here"
                )
                .frame(height: 200)
                .modernCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentTransfers.prefix(3).enumerated()), id: \.element.id) { index, transfer in
                        ModernActivityRow(
                            title: getTransferTitle(for: transfer),
                            subtitle: getTransferSubtitle(for: transfer),
                            time: RelativeDateFormatter.shared.string(from: transfer.requestDate),
                            icon: "arrow.left.arrow.right.circle.fill",
                            iconColor: AppColors.accent
                        ) {
                            selectedTransferId = String(transfer.id)
                            navigateToTransfers = true
                        }
                        
                        if index < min(2, recentTransfers.count - 1) {
                            IndustrialDivider()
                        }
                    }
                }
                .modernCard()
            }
        }
    }
    
    private var equipmentStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModernSectionHeader(
                title: "Property Status",
                subtitle: "Operational readiness overview"
            )
            
            VStack(spacing: 16) {
                ModernStatusProgressRow(
                    label: "Operational",
                    value: calculateOperationalPercentage(),
                    color: AppColors.success,
                    description: "Ready for use"
                )
                
                ModernStatusProgressRow(
                    label: "In Maintenance",
                    value: calculateMaintenancePercentage(),
                    color: AppColors.warning,
                    description: "Scheduled or ongoing maintenance"
                )
                
                ModernStatusProgressRow(
                    label: "Non-operational",
                    value: calculateNonOperationalPercentage(),
                    color: AppColors.destructive,
                    description: "Requires immediate attention"
                )
            }
            .modernCard()
        }
    }
    
    private var navigationLinks: some View {
        Group {
            NavigationLink(
                destination: MyPropertiesView(),
                isActive: $navigateToProperties
            ) { EmptyView() }
            
            NavigationLink(
                destination: TransfersView(),
                isActive: $navigateToTransfers
            ) { EmptyView() }
            
            NavigationLink(
                destination: MaintenanceView(),
                isActive: $navigateToMaintenance
            ) { EmptyView() }
            
            NavigationLink(
                destination: SensitiveItemsView(),
                isActive: $navigateToSensitiveItems
            ) { EmptyView() }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTransferTitle(for transfer: Transfer) -> String {
        switch transfer.status.lowercased() {
        case "pending":
            return "Transfer Requested"
        case "completed", "approved":
            return "Transfer Completed"
        case "rejected":
            return "Transfer Rejected"
        default:
            return "Transfer \(transfer.status.capitalized)"
        }
    }
    
    private func getTransferSubtitle(for transfer: Transfer) -> String {
        if let property = properties.first(where: { $0.id == transfer.propertyId }) {
            return "\(property.itemName) - SN: \(property.serialNumber)"
        } else {
            return "Property #\(transfer.propertyId)"
        }
    }
    
    private func getWelcomeMessage() -> String {
        guard let user = currentUser else {
            return "Welcome"
        }
        
        var components = ["Welcome"]
        
        if !user.rank.isEmpty {
            let rankAbbreviation = convertToRankAbbreviation(user.rank)
            components.append(rankAbbreviation)
        }
        
        if let lastName = user.lastName, !lastName.isEmpty {
            components.append(lastName)
        } else {
            let fullName = user.name
            debugPrint("DashboardView: No lastName, trying to parse from name: '\(fullName)'")
            
            if fullName.contains(",") {
                let parts = fullName.components(separatedBy: ",")
                if let firstPart = parts.first?.trimmingCharacters(in: .whitespaces) {
                    let words = firstPart.components(separatedBy: " ")
                    if words.count > 1, convertToRankAbbreviation(words[0]) != words[0] {
                        let lastName = words.dropFirst().joined(separator: " ")
                        components.append(lastName)
                    } else if words.count == 1 {
                        components.append(firstPart)
                    }
                }
            } else {
                let words = fullName.components(separatedBy: " ")
                if let lastWord = words.last, !lastWord.isEmpty {
                    components.append(lastWord)
                }
            }
        }
        
        return components.joined(separator: " ")
    }
    
    private func convertToRankAbbreviation(_ rank: String) -> String {
        let rankMappings: [String: String] = [
            "Captain": "CPT",
            "Lieutenant": "LT",
            "First Lieutenant": "1LT",
            "Second Lieutenant": "2LT",
            "Major": "MAJ",
            "Lieutenant Colonel": "LTC",
            "Colonel": "COL",
            "Brigadier General": "BG",
            "Major General": "MG",
            "Lieutenant General": "LTG",
            "General": "GEN",
            "Private": "PVT",
            "Private First Class": "PFC",
            "Specialist": "SPC",
            "Corporal": "CPL",
            "Sergeant": "SGT",
            "Staff Sergeant": "SSG",
            "Sergeant First Class": "SFC",
            "Master Sergeant": "MSG",
            "First Sergeant": "1SG",
            "Sergeant Major": "SGM",
            "Command Sergeant Major": "CSM",
            "Sergeant Major of the Army": "SMA"
        ]
        
        return rankMappings[rank] ?? rank
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        loadingError = nil
        
        do {
            if currentUser == nil {
                if let user = authManager.currentUser {
                    currentUser = user
                    debugPrint("DashboardView: Loaded user from environment - \(user.username), rank: \(user.rank), lastName: \(user.lastName ?? "nil")")
                } else if let user = AuthManager.shared.currentUser {
                    currentUser = user
                    debugPrint("DashboardView: Loaded user from singleton - \(user.username), rank: \(user.rank), lastName: \(user.lastName ?? "nil")")
                }
            }
            
            properties = try await apiService.getMyProperties()
            totalProperties = properties.count
            
            maintenanceNeeded = properties.filter { $0.needsMaintenance }.count
            
            let sensitiveItems = properties.filter { $0.isSensitive }
            verifiedItems = (verified: sensitiveItems.count, total: sensitiveItems.count)
            
            let transfers = try await apiService.fetchTransfers(status: nil, direction: nil)
            pendingTransfers = transfers.filter { $0.status.lowercased() == "pending" }.count
            recentTransfers = transfers.sorted { $0.requestDate > $1.requestDate }
            
            let allConnections = try await apiService.getConnections()
            connections = allConnections.filter { $0.connectionStatus == .accepted }
            pendingConnectionRequests = allConnections.filter { $0.connectionStatus == .pending }.count
            
            isLoading = false
        } catch {
            loadingError = error.localizedDescription
            isLoading = false
            debugPrint("Dashboard load error: \(error)")
        }
    }
    
    private func refreshData() async {
        await loadData()
    }
    
    // MARK: - Calculations
    
    private func calculateOperationalPercentage() -> Int {
        guard totalProperties > 0 else { return 0 }
        let operational = properties.filter { $0.currentStatus == "active" || $0.currentStatus == "operational" }.count
        return Int((Double(operational) / Double(totalProperties)) * 100)
    }
    
    private func calculateMaintenancePercentage() -> Int {
        guard totalProperties > 0 else { return 0 }
        return Int((Double(maintenanceNeeded) / Double(totalProperties)) * 100)
    }
    
    private func calculateNonOperationalPercentage() -> Int {
        guard totalProperties > 0 else { return 0 }
        let nonOperational = properties.filter { $0.currentStatus == "non-operational" || $0.currentStatus == "damaged" }.count
        return Int((Double(nonOperational) / Double(totalProperties)) * 100)
    }
}

// MARK: - Modern Component Implementations

struct ModernStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let onTap: (() -> Void)?
    
    init(title: String, value: String, icon: String, color: Color, onTap: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
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
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(onTap == nil)
        .modernCard()
    }
}

struct ModernActivityRow: View {
    let title: String
    let subtitle: String
    let time: String
    let icon: String
    let iconColor: Color
    let onTap: (() -> Void)?
    
    init(title: String, subtitle: String, time: String, icon: String, iconColor: Color, onTap: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.icon = icon
        self.iconColor = iconColor
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                Text(time)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(onTap == nil)
    }
}

struct ModernStatusProgressRow: View {
    let label: String
    let value: Int
    let color: Color
    let description: String?
    
    init(label: String, value: Int, color: Color, description: String? = nil) {
        self.label = label
        self.value = value
        self.color = color
        self.description = description
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased())
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.primaryText)
                        .kerning(AppFonts.wideTracking)
                    
                    if let description = description {
                        Text(description)
                            .font(AppFonts.micro)
                            .foregroundColor(AppColors.tertiaryText)
                    }
                }
                
                Spacer()
                
                Text("\(value)%")
                    .font(AppFonts.headlineBold)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.tertiaryBackground)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value) / 100, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Date Formatter Helper
class RelativeDateFormatter {
    static let shared = RelativeDateFormatter()
    
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    func string(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 86400 { // Less than 24 hours
            return relativeFormatter.localizedString(for: date, relativeTo: now)
        } else {
            return formatter.string(from: date)
        }
    }
}

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DashboardView()
        }
        .preferredColorScheme(.dark)
    }
} 