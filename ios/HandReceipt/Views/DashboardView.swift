import SwiftUI

struct DashboardView: View {
    // QR Scanner functionality removed
    @State private var selectedQuickAction: QuickAction? = nil
    
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
    
    // Loading states
    @State private var isLoading = true
    @State private var loadingError: String?
    
    // Services
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // Welcome text
                    Text("Welcome, CPT Rodriguez")
                        .font(AppFonts.largeTitle)
                        .foregroundColor(AppColors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    if isLoading {
                        loadingSection
                    } else if let error = loadingError {
                        errorSection(error: error)
                    } else {
                        mainContentSection
                    }
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Top bar that mirrors bottom tab bar
            headerSection
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .refreshable {
            await refreshData()
        }
        // QR Scanner sheet removed
        .background(navigationLinks)
        .task {
            await loadData()
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        ZStack {
            // Background that extends to top of screen
            AppColors.secondaryBackground
                .ignoresSafeArea()
            
            // Content positioned at bottom of header
            VStack {
                Spacer()
                Text("DASHBOARD")
                    .font(.system(size: 16, weight: .medium)) // Larger font
                    .foregroundColor(AppColors.primaryText)
                    .kerning(1.2) // Match TransfersView tracking
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12) // Bottom padding
            }
        }
        .frame(height: 36) // Very tight header
    }
    
    private var loadingSection: some View {
        ProgressView("Loading dashboard...")
            .padding(.vertical, 50)
    }
    
    private func errorSection(error: String) -> some View {
        ErrorView(message: error) {
            Task { await refreshData() }
        }
        .padding()
    }
    
    private var mainContentSection: some View {
        VStack(spacing: 24) {
            statsCardsSection
            quickActionsSection
            recentActivitySection
            equipmentStatusSection
            bottomSpacerSection
        }
    }
    
    private var statsCardsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            WebAlignedStatCard(
                                            title: "Total Properties",
                            value: "\(totalProperties)",
                icon: "shippingbox.fill",
                color: .blue
            ) {
                navigateToProperties = true
            }
            
            WebAlignedStatCard(
                title: "Pending Transfers", 
                value: "\(pendingTransfers)",
                icon: "arrow.left.arrow.right.circle.fill",
                color: AppColors.accent
            ) {
                navigateToTransfers = true
            }
            
            WebAlignedStatCard(
                title: "Items Verified",
                value: "\(verifiedItems.verified)/\(verifiedItems.total)",
                icon: "checkmark.shield.fill",
                color: .green
            ) {
                navigateToSensitiveItems = true
            }
            
            WebAlignedStatCard(
                title: "Need Maintenance",
                value: "\(maintenanceNeeded)",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            ) {
                navigateToMaintenance = true
            }
        }
        .padding(.horizontal)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Quick Actions")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // QR Scanner quick action removed
                
                WebAlignedQuickActionCard(action: .requestTransfer) {
                    navigateToTransfers = true
                }
                
                WebAlignedQuickActionCard(action: .findItem) {
                    navigateToProperties = true
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(
                title: "Recent Activity",
                action: {
                    navigateToTransfers = true
                },
                actionLabel: "View All"
            )
            
            if recentTransfers.isEmpty {
                emptyActivityCard
            } else {
                activityContentCard
            }
        }
    }
    
    private var emptyActivityCard: some View {
        WebAlignedCard {
            Text("No recent activity")
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
        }
        .padding(.horizontal)
    }
    
    private var activityContentCard: some View {
        WebAlignedCard {
            VStack(spacing: 0) {
                ForEach(Array(recentTransfers.prefix(3).enumerated()), id: \.element.id) { index, transfer in
                    WebAlignedActivityRow(
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
                        Divider()
                            .background(AppColors.border)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var equipmentStatusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(
                title: "Equipment Status",
                action: {
                    // No action needed
                },
                actionLabel: "View Details"
            )
            
            WebAlignedCard {
                VStack(spacing: 16) {
                    WebAlignedStatusProgressRow(
                        label: "Operational",
                        value: calculateOperationalPercentage(),
                        color: .green
                    )
                    
                    WebAlignedStatusProgressRow(
                        label: "In Maintenance",
                        value: calculateMaintenancePercentage(),
                        color: .orange
                    )
                    
                    WebAlignedStatusProgressRow(
                        label: "Non-operational",
                        value: calculateNonOperationalPercentage(),
                        color: .red
                    )
                }
                .padding()
            }
            .padding(.horizontal)
        }
    }
    
    private var bottomSpacerSection: some View {
        Spacer()
            .frame(height: 100)
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
    
    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        loadingError = nil
        
        do {
            // Fetch user's properties
            properties = try await apiService.getMyProperties()
                            totalProperties = properties.count
            
            // Calculate maintenance needed
            maintenanceNeeded = properties.filter { $0.needsMaintenance }.count
            
            // Calculate verified items (mock for now - will need actual verification data)
            let sensitiveItems = properties.filter { $0.isSensitive }
            verifiedItems = (verified: sensitiveItems.count, total: sensitiveItems.count)
            
            // Fetch transfers
            let transfers = try await apiService.fetchTransfers(status: nil, direction: nil)
            pendingTransfers = transfers.filter { $0.status.lowercased() == "pending" }.count
            recentTransfers = transfers.sorted { $0.requestDate > $1.requestDate }
            
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

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        WebAlignedCard {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                
                Text("Error Loading Dashboard")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text(message)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                
                Button(action: retry) {
                    Text("Retry")
                        .font(AppFonts.bodyBold)
                }
                .buttonStyle(.primary)
            }
            .padding()
        }
    }
}

// MARK: - Legacy Component Compatibility (Remove when fully migrated)
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        WebAlignedStatCard(
            title: title,
            value: value,
            icon: icon,
            color: color
        )
    }
}

struct QuickActionCard: View {
    let action: QuickAction
    let onTap: () -> Void
    
    var body: some View {
        WebAlignedQuickActionCard(action: action, onTap: onTap)
    }
}

struct ActivityRow: View {
    enum ActivityType {
        case transfer, maintenance, verification
        
        var icon: String {
            switch self {
            case .transfer: return "arrow.left.arrow.right.circle.fill"
            case .maintenance: return "wrench.and.screwdriver.fill"
            case .verification: return "checkmark.shield.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .transfer: return AppColors.accent
            case .maintenance: return .orange
            case .verification: return .green
            }
        }
    }
    
    let type: ActivityType
    let title: String
    let subtitle: String
    let time: String
    
    var body: some View {
        WebAlignedActivityRow(
            title: title,
            subtitle: subtitle,
            time: time,
            icon: type.icon,
            iconColor: type.color
        )
    }
}

// MARK: - Updated Activity Row Extension
extension ActivityRow {
    init(transfer: Transfer, properties: [Property]) {
        let property = properties.first { $0.id == transfer.propertyId }
        let title: String
        let subtitle: String
        
        switch transfer.status.lowercased() {
        case "pending":
            title = "Transfer Requested"
        case "completed", "approved":
            title = "Transfer Completed"
        case "rejected":
            title = "Transfer Rejected"
        default:
            title = "Transfer \(transfer.status.capitalized)"
        }
        
        if let property = property {
            subtitle = "\(property.itemName) - SN: \(property.serialNumber)"
        } else {
            subtitle = "Property #\(transfer.propertyId)"
        }
        
        self.init(
            type: .transfer,
            title: title,
            subtitle: subtitle,
                                        time: RelativeDateFormatter.shared.string(from: transfer.requestDate)
        )
    }
}

struct StatusProgressRow: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        WebAlignedStatusProgressRow(label: label, value: value, color: color)
    }
}

// MARK: - Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
        
        // Use relative formatting for recent dates
        if timeInterval < 86400 { // Less than 24 hours
            return relativeFormatter.localizedString(for: date, relativeTo: now)
        } else {
            return formatter.string(from: date)
        }
    }
} 