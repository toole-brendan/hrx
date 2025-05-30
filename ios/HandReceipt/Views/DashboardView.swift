import SwiftUI

struct DashboardView: View {
    @State private var showQRScanner = false
    @State private var selectedQuickAction: QuickAction? = nil
    
    // Real data from API
    @State private var totalInventory = 0
    @State private var pendingTransfers = 0
    @State private var verifiedItems = (verified: 0, total: 0)
    @State private var maintenanceNeeded = 0
    @State private var recentTransfers: [Transfer] = []
    @State private var properties: [Property] = []
    
    // Loading states
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var loadingError: String?
    
    // Services
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    var body: some View {
        ScrollView {
            // Pull to refresh
            RefreshControl(isRefreshing: $isRefreshing) {
                await refreshData()
            }
            
            VStack(spacing: 0) {
                // Welcome Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("DASHBOARD")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .tracking(1.2)
                    
                    Text("Welcome, CPT Rodriguez")
                        .font(AppFonts.largeTitle)
                        .foregroundColor(AppColors.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                if isLoading && !isRefreshing {
                    ProgressView("Loading dashboard...")
                        .padding(.vertical, 50)
                } else if let error = loadingError {
                    ErrorView(message: error) {
                        Task { await refreshData() }
                    }
                    .padding()
                } else {
                    // Summary Stats Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        StatCard(
                            title: "Total Inventory",
                            value: "\(totalInventory)",
                            icon: "shippingbox.fill",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Pending Transfers", 
                            value: "\(pendingTransfers)",
                            icon: "arrow.left.arrow.right.circle.fill",
                            color: AppColors.accent
                        )
                        
                        StatCard(
                            title: "Items Verified",
                            value: "\(verifiedItems.verified)/\(verifiedItems.total)",
                            icon: "checkmark.shield.fill",
                            color: .green
                        )
                        
                        StatCard(
                            title: "Need Maintenance",
                            value: "\(maintenanceNeeded)",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                    
                    // Quick Actions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("QUICK ACTIONS")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .tracking(1.2)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            QuickActionCard(
                                action: .scanQR,
                                onTap: { showQRScanner = true }
                            )
                            
                            QuickActionCard(
                                action: .requestTransfer,
                                onTap: { selectedQuickAction = .requestTransfer }
                            )
                            
                            QuickActionCard(
                                action: .findItem,
                                onTap: { selectedQuickAction = .findItem }
                            )
                            
                            QuickActionCard(
                                action: .exportReport,
                                onTap: { selectedQuickAction = .exportReport }
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                    
                    // Recent Activity Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("RECENT ACTIVITY")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .tracking(1.2)
                            
                            Spacer()
                            
                            Button(action: {
                                // Navigate to full activity view
                            }) {
                                Text("VIEW ALL")
                                    .font(AppFonts.captionBold)
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(.horizontal)
                        
                        if recentTransfers.isEmpty {
                            Text("No recent activity")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                                .background(AppColors.secondaryBackground)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(recentTransfers.prefix(3).enumerated()), id: \.element.id) { index, transfer in
                                    ActivityRow(
                                        transfer: transfer,
                                        properties: properties
                                    )
                                    
                                    if index < min(2, recentTransfers.count - 1) {
                                        Divider()
                                            .background(AppColors.tertiaryBackground)
                                    }
                                }
                            }
                            .background(AppColors.secondaryBackground)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                    
                    // Equipment Status Overview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EQUIPMENT STATUS")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .tracking(1.2)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            StatusProgressRow(
                                label: "Operational",
                                value: calculateOperationalPercentage(),
                                color: .green
                            )
                            
                            StatusProgressRow(
                                label: "In Maintenance",
                                value: calculateMaintenancePercentage(),
                                color: .orange
                            )
                            
                            StatusProgressRow(
                                label: "Non-operational",
                                value: calculateNonOperationalPercentage(),
                                color: .red
                            )
                        }
                        .padding()
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 100) // Account for tab bar
                }
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showQRScanner) {
            QRScannerView()
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        loadingError = nil
        
        do {
            // Fetch user's properties
            properties = try await apiService.getMyProperties()
            totalInventory = properties.count
            
            // Calculate maintenance needed
            maintenanceNeeded = properties.filter { $0.needsMaintenance }.count
            
            // Calculate verified items (mock for now - will need actual verification data)
            let sensitiveItems = properties.filter { $0.isSensitive }
            verifiedItems = (verified: sensitiveItems.count, total: sensitiveItems.count)
            
            // Fetch transfers
            let transfers = try await apiService.fetchTransfers(status: nil, direction: nil)
            pendingTransfers = transfers.filter { $0.status == .PENDING }.count
            recentTransfers = transfers.sorted { $0.requestTimestamp > $1.requestTimestamp }
            
            isLoading = false
        } catch {
            loadingError = error.localizedDescription
            isLoading = false
            debugPrint("Dashboard load error: \(error)")
        }
    }
    
    private func refreshData() async {
        isRefreshing = true
        await loadData()
        isRefreshing = false
    }
    
    // MARK: - Calculations
    private func calculateOperationalPercentage() -> Int {
        guard totalInventory > 0 else { return 0 }
        let operational = properties.filter { $0.currentStatus == "active" || $0.currentStatus == "operational" }.count
        return Int((Double(operational) / Double(totalInventory)) * 100)
    }
    
    private func calculateMaintenancePercentage() -> Int {
        guard totalInventory > 0 else { return 0 }
        return Int((Double(maintenanceNeeded) / Double(totalInventory)) * 100)
    }
    
    private func calculateNonOperationalPercentage() -> Int {
        guard totalInventory > 0 else { return 0 }
        let nonOperational = properties.filter { $0.currentStatus == "non-operational" || $0.currentStatus == "damaged" }.count
        return Int((Double(nonOperational) / Double(totalInventory)) * 100)
    }
}

// MARK: - RefreshControl
struct RefreshControl: UIViewRepresentable {
    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Void
    
    func makeUIView(context: Context) -> UIRefreshControl {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh), for: .valueChanged)
        return refreshControl
    }
    
    func updateUIView(_ uiView: UIRefreshControl, context: Context) {
        if isRefreshing {
            uiView.beginRefreshing()
        } else {
            uiView.endRefreshing()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: RefreshControl
        
        init(_ parent: RefreshControl) {
            self.parent = parent
        }
        
        @objc func handleRefresh() {
            Task {
                await parent.onRefresh()
            }
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
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
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - Updated Activity Row
extension ActivityRow {
    init(transfer: Transfer, properties: [Property]) {
        let property = properties.first { $0.id == transfer.propertyId }
        let title: String
        let subtitle: String
        
        switch transfer.status {
        case .PENDING:
            title = "Transfer Requested"
        case .APPROVED:
            title = "Transfer Completed"
        case .REJECTED:
            title = "Transfer Rejected"
        default:
            title = "Transfer \(transfer.status.rawValue.capitalized)"
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
            time: RelativeDateFormatter.shared.string(from: transfer.requestTimestamp)
        )
    }
}

// MARK: - Supporting Types
enum QuickAction {
    case scanQR, requestTransfer, findItem, exportReport
    
    var title: String {
        switch self {
        case .scanQR: return "Scan QR"
        case .requestTransfer: return "Request Transfer"
        case .findItem: return "Find Item"
        case .exportReport: return "Export Report"
        }
    }
    
    var icon: String {
        switch self {
        case .scanQR: return "qrcode.viewfinder"
        case .requestTransfer: return "arrow.left.arrow.right"
        case .findItem: return "magnifyingglass"
        case .exportReport: return "doc.text"
        }
    }
    
    var color: Color {
        switch self {
        case .scanQR: return .blue
        case .requestTransfer: return .orange
        case .findItem: return .green
        case .exportReport: return .red
        }
    }
}

// MARK: - Component Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(AppFonts.title)
                .foregroundColor(AppColors.primaryText)
            
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
    }
}

struct QuickActionCard: View {
    let action: QuickAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(action.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: action.icon)
                        .font(.title3)
                        .foregroundColor(action.color)
                }
                
                Text(action.title)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.secondaryBackground)
            .cornerRadius(12)
        }
        .buttonStyle(ScaleButtonStyle())
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
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title3)
                .foregroundColor(type.color)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(subtitle)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Text(time)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
        }
        .padding()
    }
}

struct StatusProgressRow: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Text("\(value)%")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.tertiaryBackground)
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value) / 100, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
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