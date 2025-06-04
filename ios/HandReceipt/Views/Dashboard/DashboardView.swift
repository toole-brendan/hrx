// handreceipt/ios/HandReceipt/Views/DashboardView.swift

import SwiftUI

struct DashboardView: View {
    @State private var selectedQuickAction: QuickAction? = nil
    @State private var currentUser: LoginResponse.User?
    @EnvironmentObject var authManager: AuthManager
    
    // Navigation states
    @State private var navigateToMaintenance = false
    @State private var navigateToSensitiveItems = false
    @State private var showingSearch = false
    @State private var showingDA2062Scan = false
    
    // Tab switching callback
    var onTabSwitch: ((Int) -> Void)?
    
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
    @ObservedObject private var documentService = DocumentService.shared
    
    init(apiService: APIServiceProtocol = APIService(), onTabSwitch: ((Int) -> Void)? = nil) {
        self.apiService = apiService
        self.onTabSwitch = onTabSwitch
    }
    
    var body: some View {
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()
            
            if isLoading {
                DashboardLoadingView(message: "Loading dashboard")
            } else if let error = loadingError {
                MinimalEmptyState(
                    icon: "exclamationmark.circle",
                    title: "Unable to Load",
                    message: error,
                    action: { Task { await refreshData() } },
                    actionLabel: "Retry"
                )
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Section
                        heroSection
                        
                        // Main content
                        VStack(spacing: 40) {
                            statsOverview
                            quickActions
                            
                            // Documents Inbox card if there are unread documents
                            if documentService.unreadCount > 0 {
                                documentsInboxCard
                            }
                            
                            networkSection
                            activitySection
                            propertyStatusSection
                        }
                        .padding(.horizontal, 24)
                        
                        // Bottom padding
                        Color.clear.frame(height: 80)
                    }
                }
                .minimalRefreshable {
                    await refreshData()
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .background(navigationLinks)
        .fullScreenCover(isPresented: $showingSearch) {
            MinimalSearchView(isPresented: $showingSearch, apiService: apiService)
        }
        .sheet(isPresented: $showingDA2062Scan) {
            DA2062ScanView()
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - 8VC Styled Sections
    
    private var heroSection: some View {
        VStack(spacing: 0) {
            // Top navigation bar
            HStack {
                Text("HandReceipt")
                    .font(AppFonts.monoBody)
                    .foregroundColor(AppColors.secondaryText)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: { showingSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(AppColors.primaryText)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
                .background(AppColors.divider)
            
            // Welcome section
            Text(getWelcomeMessage())
                .font(AppFonts.serifHero)
                .foregroundColor(AppColors.primaryText)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
        }
    }
    
    private var statsOverview: some View {
        VStack(spacing: 24) {
            ElegantSectionHeader(
                title: "Overview",
                subtitle: "Current system status",
                style: .serif
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MinimalStatCard(
                    title: "Total Properties",
                    value: String(format: "%04d", totalProperties),
                    subtitle: "Items tracked",
                    trend: .neutral
                )
                .onTapGesture { onTabSwitch?(1) }
                
                MinimalStatCard(
                    title: "Pending Transfers",
                    value: String(format: "%02d", pendingTransfers),
                    subtitle: "Awaiting approval",
                    trend: pendingTransfers > 0 ? .up("\(pendingTransfers)") : .neutral
                )
                .onTapGesture { onTabSwitch?(2) }
                
                MinimalStatCard(
                    title: "Verified Items",
                    value: "\(verifiedItems.verified)/\(verifiedItems.total)",
                    subtitle: "Verification rate",
                    trend: .up("98%")
                )
                .onTapGesture { navigateToSensitiveItems = true }
                
                MinimalStatCard(
                    title: "Maintenance Due",
                    value: String(format: "%02d", maintenanceNeeded),
                    subtitle: "Items requiring service",
                    trend: maintenanceNeeded > 0 ? .down("\(maintenanceNeeded)") : .neutral
                )
                .onTapGesture { navigateToMaintenance = true }
            }
        }
    }
    
    private var quickActions: some View {
        VStack(spacing: 24) {
            ElegantSectionHeader(
                title: "Quick Actions",
                style: .serif
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ActionButton(
                    icon: "arrow.left.arrow.right",
                    title: "Transfer",
                    action: { onTabSwitch?(2) }
                )
                
                ActionButton(
                    icon: "magnifyingglass",
                    title: "Search",
                    action: { showingSearch = true }
                )
                
                ActionButton(
                    icon: "person.badge.plus",
                    title: "Connect",
                    action: {}
                )
                
                ActionButton(
                    icon: "wrench",
                    title: "Maintain",
                    action: { navigateToMaintenance = true }
                )
                
                ActionButton(
                    icon: "doc.text.viewfinder",
                    title: "Import DA-2062",
                    action: { showingDA2062Scan = true }
                )
                
                NavigationLink(destination: DocumentsView()) {
                    VStack(spacing: 12) {
                        ZStack {
                            Image(systemName: "tray")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(AppColors.primaryText)
                            
                            // Unread badge
                            if documentService.unreadCount > 0 {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Text("\(documentService.unreadCount)")
                                            .font(AppFonts.caption2)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(AppColors.accent)
                                            .clipShape(Capsule())
                                            .offset(x: 8, y: -8)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        
                        Text("Documents".uppercased())
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .compatibleKerning(AppFonts.wideKerning)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var networkSection: some View {
        VStack(spacing: 24) {
            ElegantSectionHeader(
                title: "Network",
                subtitle: "Connected users",
                style: .serif,
                action: {},
                actionLabel: "View All"
            )
            
            HStack(spacing: 16) {
                NetworkCard(
                    value: connections.count,
                    label: "Connected",
                    icon: "person.2"
                )
                
                NetworkCard(
                    value: pendingConnectionRequests,
                    label: "Pending",
                    icon: "clock"
                )
            }
        }
    }
    
    private var activitySection: some View {
        VStack(spacing: 24) {
            ElegantSectionHeader(
                title: "Recent Activity",
                style: .serif,
                action: { onTabSwitch?(2) },
                actionLabel: "See All"
            )
            
            if recentTransfers.isEmpty {
                MinimalEmptyState(
                    icon: "clock",
                    title: "No Recent Activity",
                    message: "Transfer activity will appear here"
                )
                .cleanCard(showShadow: false)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentTransfers.prefix(5).enumerated()), id: \.element.id) { index, transfer in
                        ActivityRow(transfer: transfer, properties: properties)
                        
                        if index < min(4, recentTransfers.count - 1) {
                            Divider()
                                .background(AppColors.divider)
                                .padding(.leading, 56)
                        }
                    }
                }
                .cleanCard(padding: 0)
            }
        }
    }
    
    private var propertyStatusSection: some View {
        VStack(spacing: 24) {
            ElegantSectionHeader(
                title: "Property Status",
                subtitle: "Operational readiness",
                style: .serif
            )
            
            VStack(spacing: 20) {
                StatusRow(
                    label: "Operational",
                    percentage: calculateOperationalPercentage(),
                    color: AppColors.success
                )
                
                StatusRow(
                    label: "In Maintenance",
                    percentage: calculateMaintenancePercentage(),
                    color: AppColors.warning
                )
                
                StatusRow(
                    label: "Non-operational",
                    percentage: calculateNonOperationalPercentage(),
                    color: AppColors.destructive
                )
            }
            .cleanCard()
        }
    }
    
    // MARK: - Supporting Components
    
    struct ActionButton: View {
        let icon: String
        let title: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(title.uppercased())
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .compatibleKerning(AppFonts.wideKerning)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(AppColors.secondaryBackground)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    struct NetworkCard: View {
        let value: Int
        let label: String
        let icon: String
        
        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .thin))
                    .foregroundColor(AppColors.tertiaryText)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(value)")
                        .font(AppFonts.monoHeadline)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(label.uppercased())
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .compatibleKerning(AppFonts.wideKerning)
                }
                
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(AppColors.secondaryBackground)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
    
    struct ActivityRow: View {
        let transfer: Transfer
        let properties: [Property]
        
        var body: some View {
            HStack(spacing: 16) {
                Circle()
                    .fill(AppColors.tertiaryBackground)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(AppColors.secondaryText)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(getTransferTitle())
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(getTransferSubtitle())
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                Text(RelativeDateFormatter.shared.string(from: transfer.requestDate))
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding(16)
        }
        
        private func getTransferTitle() -> String {
            switch transfer.status.lowercased() {
            case "pending": return "Transfer Requested"
            case "completed", "approved": return "Transfer Completed"
            case "rejected": return "Transfer Rejected"
            default: return "Transfer \(transfer.status.capitalized)"
            }
        }
        
        private func getTransferSubtitle() -> String {
            if let property = properties.first(where: { $0.id == transfer.propertyId }) {
                return "\(property.itemName) • \(property.serialNumber)"
            }
            return "Property #\(transfer.propertyId)"
        }
    }
    
    struct StatusRow: View {
        let label: String
        let percentage: Int
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(label)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                    
                    Text("\(percentage)%")
                        .font(AppFonts.monoBody)
                        .foregroundColor(color)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(AppColors.tertiaryBackground)
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(percentage) / 100, height: 4)
                    }
                }
                .frame(height: 4)
                .cornerRadius(2)
            }
        }
    }
    
    // MARK: - Documents Inbox Card
    private var documentsInboxCard: some View {
        NavigationLink(destination: DocumentsView()) {
            HStack(spacing: 16) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 48, height: 48)
                    .background(AppColors.accent.opacity(0.1))
                    .cornerRadius(4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Documents Inbox")
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(AppColors.primaryText)
                    Text("\(documentService.unreadCount) unread")
                        .font(AppFonts.monoCaption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding(20)
            .background(AppColors.secondaryBackground)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Navigation Links
    private var navigationLinks: some View {
        Group {
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
    private func getWelcomeMessage() -> String {
        guard let user = currentUser else { return "Welcome" }
        return "Welcome, \(user.name)"
    }
    
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
    
    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        loadingError = nil
        
        do {
            if currentUser == nil {
                if let user = authManager.currentUser {
                    currentUser = user
                    debugPrint("DashboardView: Loaded user from environment - \(user.username)")
                } else if let user = AuthManager.shared.currentUser {
                    currentUser = user
                    debugPrint("DashboardView: Loaded user from singleton - \(user.username)")
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
}

// MARK: - Minimal Stat Card Component
public struct MinimalStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let trend: Trend?
    
    public enum Trend {
        case up(String)
        case down(String)
        case neutral
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
                .compatibleKerning(AppFonts.wideKerning)
            
            Text(value)
                .font(AppFonts.monoHeadline)
                .foregroundColor(AppColors.primaryText)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            if let trend = trend {
                trendView(trend)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cleanCard(padding: 20)
    }
    
    @ViewBuilder
    private func trendView(_ trend: Trend) -> some View {
        HStack(spacing: 4) {
            switch trend {
            case .up(let value):
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .medium))
                Text(value)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.success)
            case .down(let value):
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .medium))
                Text(value)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.destructive)
            case .neutral:
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .medium))
                Text("No change")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }
}

// MARK: - Geometric Pattern View
public struct GeometricPatternView: View {
    public var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let size = min(width, height) * 0.8
                let offsetX = (width - size) / 2
                let offsetY = (height - size) / 2
                
                // Outer cube
                let points = [
                    CGPoint(x: offsetX + size * 0.2, y: offsetY + size * 0.3),
                    CGPoint(x: offsetX + size * 0.8, y: offsetY + size * 0.3),
                    CGPoint(x: offsetX + size * 0.8, y: offsetY + size * 0.7),
                    CGPoint(x: offsetX + size * 0.2, y: offsetY + size * 0.7)
                ]
                
                // Draw outer rectangle
                path.move(to: points[0])
                for i in 1..<4 {
                    path.addLine(to: points[i])
                }
                path.closeSubpath()
                
                // Inner nested rectangles
                for scale in stride(from: 0.8, to: 0.2, by: -0.2) {
                    let innerPoints = points.map { point in
                        let centerX = offsetX + size / 2
                        let centerY = offsetY + size / 2
                        let dx = point.x - centerX
                        let dy = point.y - centerY
                        return CGPoint(
                            x: centerX + dx * scale,
                            y: centerY + dy * scale
                        )
                    }
                    
                    path.move(to: innerPoints[0])
                    for i in 1..<4 {
                        path.addLine(to: innerPoints[i])
                    }
                    path.closeSubpath()
                }
            }
            .stroke(AppColors.border, lineWidth: 1)
        }
    }
}

// MARK: - Dashboard Loading View
struct DashboardLoadingView: View {
    let message: String?
    
    var body: some View {
        VStack(spacing: 24) {
            // Geometric loading animation
            GeometricLoader()
            
            if let message = message {
                Text(message.uppercased())
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .kerning(AppFonts.wideKerning)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.appBackground)
    }
}

// MARK: - Geometric Loader
struct GeometricLoader: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(AppColors.primaryText.opacity(0.2), lineWidth: 2)
                .frame(width: 60, height: 60)
            
            // Inner rotating shapes
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primaryText.opacity(0.8 - Double(index) * 0.2))
                    .frame(width: 4, height: 16)
                    .offset(y: -20)
                    .rotationEffect(.degrees(rotation + Double(index * 120)))
            }
        }
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                scale = 1.1
            }
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
            DashboardView(onTabSwitch: nil)
        }
    }
} 