import SwiftUI

struct MaintenanceView: View {
    @State private var maintenanceItems: [Property] = []
    @State private var isLoading = true
    @State private var loadingError: String?
    @State private var selectedFilter: MaintenanceFilter = .all
    @State private var showingMaintenanceSheet = false
    @State private var selectedItem: Property?
    
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    enum MaintenanceFilter: String, CaseIterable {
        case all = "All"
        case due = "Due"
        case overdue = "Overdue"
        case scheduled = "Scheduled"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .due: return "clock"
            case .overdue: return "exclamationmark.triangle"
            case .scheduled: return "calendar"
            }
        }
    }
    
    var filteredItems: [Property] {
        switch selectedFilter {
        case .all:
            return maintenanceItems
        case .due:
            return maintenanceItems.filter { item in
                guard let dueDate = item.maintenanceDueDate else { return false }
                let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                return daysUntilDue <= 7 && daysUntilDue >= 0
            }
        case .overdue:
            return maintenanceItems.filter { item in
                guard let dueDate = item.maintenanceDueDate else { return false }
                return dueDate < Date()
            }
        case .scheduled:
            return maintenanceItems.filter { item in
                guard let dueDate = item.maintenanceDueDate else { return false }
                return dueDate > Date()
            }
        }
    }
    
    var dueThisWeekCount: Int {
        maintenanceItems.filter { item in
            guard let dueDate = item.maintenanceDueDate else { return false }
            let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
            return daysUntilDue <= 7 && daysUntilDue >= 0
        }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Stats Header
            VStack(spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        MaintenanceStatCard(
                            title: "Total Items",
                            value: "\(maintenanceItems.count)",
                            icon: "wrench.and.screwdriver",
                            color: .blue
                        )
                        
                        MaintenanceStatCard(
                            title: "Due This Week",
                            value: "\(dueThisWeekCount)",
                            icon: "clock.fill",
                            color: .orange
                        )
                        
                        MaintenanceStatCard(
                            title: "Overdue",
                            value: "\(maintenanceItems.filter { ($0.maintenanceDueDate ?? Date()) < Date() }.count)",
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )
                        
                        MaintenanceStatCard(
                            title: "Completed Today",
                            value: "0", // Would track actual completions
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(MaintenanceFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                icon: filter.icon,
                                isSelected: selectedFilter == filter
                            ) {
                                withAnimation {
                                    selectedFilter = filter
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .background(AppColors.secondaryBackground)
            
            if isLoading {
                Spacer()
                ProgressView("Loading maintenance items...")
                    .padding()
                Spacer()
            } else if let error = loadingError {
                Spacer()
                ErrorView(message: error) {
                    Task { await loadData() }
                }
                .padding()
                Spacer()
            } else if filteredItems.isEmpty {
                Spacer()
                EmptyMaintenanceView(filter: selectedFilter)
                Spacer()
            } else {
                List {
                    ForEach(filteredItems) { item in
                        MaintenanceItemRow(item: item) {
                            selectedItem = item
                            showingMaintenanceSheet = true
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(AppColors.appBackground)
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Schedule maintenance action
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .sheet(isPresented: $showingMaintenanceSheet) {
            if let item = selectedItem {
                MaintenanceActionSheet(item: item) {
                    showingMaintenanceSheet = false
                    Task { await loadData() }
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        loadingError = nil
        
        do {
            let allProperties = try await apiService.getMyProperties()
            maintenanceItems = allProperties.filter { $0.needsMaintenance || $0.maintenanceDueDate != nil }
            isLoading = false
        } catch {
            loadingError = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Components
struct MaintenanceStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .frame(width: 140)
        .padding()
        .background(AppColors.tertiaryBackground)
        .cornerRadius(12)
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(AppFonts.captionBold)
            }
            .foregroundColor(isSelected ? .white : AppColors.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? AppColors.accent : AppColors.tertiaryBackground)
            .cornerRadius(20)
        }
    }
}

struct MaintenanceItemRow: View {
    let item: Property
    let onTap: () -> Void
    
    var daysUntilDue: Int? {
        guard let dueDate = item.maintenanceDueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day
    }
    
    var statusColor: Color {
        guard let days = daysUntilDue else { return .gray }
        if days < 0 { return .red }
        if days <= 7 { return .orange }
        return .green
    }
    
    var statusText: String {
        guard let days = daysUntilDue else { return "No due date" }
        if days < 0 { return "Overdue by \(abs(days)) days" }
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        return "Due in \(days) days"
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.itemName)
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("SN: \(item.serialNumber)")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            Text(statusText)
                                .font(AppFonts.caption)
                                .foregroundColor(statusColor)
                        }
                        
                        if let dueDate = item.maintenanceDueDate {
                            Text(DateFormatter.shortDate.string(from: dueDate))
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                        }
                    }
                }
                
                if let location = item.location {
                    HStack {
                        Image(systemName: "location")
                            .font(.caption)
                        Text(location)
                            .font(AppFonts.caption)
                    }
                    .foregroundColor(AppColors.tertiaryText)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MaintenanceActionSheet: View {
    let item: Property
    let onComplete: () -> Void
    @State private var maintenanceNotes = ""
    @State private var selectedAction: MaintenanceAction = .complete
    
    enum MaintenanceAction: String, CaseIterable {
        case complete = "Complete Maintenance"
        case reschedule = "Reschedule"
        case requestParts = "Request Parts"
        
        var icon: String {
            switch self {
            case .complete: return "checkmark.circle"
            case .reschedule: return "calendar"
            case .requestParts: return "shippingbox"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Item Details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Maintenance Action")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primaryText)
                    
                    DetailRow(label: "Item", value: item.itemName)
                    DetailRow(label: "Serial Number", value: item.serialNumber)
                    if let dueDate = item.maintenanceDueDate {
                        DetailRow(label: "Due Date", value: DateFormatter.mediumDate.string(from: dueDate))
                    }
                }
                .padding()
                .background(AppColors.secondaryBackground)
                .cornerRadius(12)
                
                // Action Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Action")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    ForEach(MaintenanceAction.allCases, id: \.self) { action in
                        Button(action: {
                            selectedAction = action
                        }) {
                            HStack {
                                Image(systemName: action.icon)
                                    .foregroundColor(selectedAction == action ? AppColors.accent : AppColors.secondaryText)
                                Text(action.rawValue)
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.primaryText)
                                Spacer()
                                if selectedAction == action {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                            .padding()
                            .background(AppColors.tertiaryBackground)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    TextEditor(text: $maintenanceNotes)
                        .font(AppFonts.body)
                        .padding(8)
                        .background(AppColors.tertiaryBackground)
                        .cornerRadius(8)
                        .frame(height: 100)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onComplete()
                    }
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.tertiaryBackground)
                    .cornerRadius(8)
                    
                    Button("Submit") {
                        // Submit maintenance action
                        onComplete()
                    }
                    .font(AppFonts.bodyBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.accent)
                    .cornerRadius(8)
                }
                .padding()
            }
            .background(AppColors.appBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

struct EmptyMaintenanceView: View {
    let filter: MaintenanceView.MaintenanceFilter
    
    var message: String {
        switch filter {
        case .all:
            return "No items require maintenance"
        case .due:
            return "No maintenance due this week"
        case .overdue:
            return "No overdue maintenance items"
        case .scheduled:
            return "No scheduled maintenance"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 60))
                .foregroundColor(AppColors.tertiaryText)
            
            Text("No Maintenance Items")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
            
            Text(message)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Date Formatter Extensions
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

// MARK: - Preview
struct MaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MaintenanceView()
        }
        .preferredColorScheme(.dark)
    }
} 