import SwiftUI

// MARK: - Maintenance View
struct MaintenanceView: View {
    @State private var maintenanceItems: [MaintenanceItem] = []
    @State private var properties: [Property] = []
    @State private var isLoading = true
    @State private var loadingError: String?
    @State private var selectedFilter: MaintenanceFilter = .all
    @State private var searchText = ""
    @State private var showingMaintenanceForm = false
    @State private var selectedProperty: Property?
    @State private var selectedMaintenanceItem: MaintenanceItem?
    @Environment(\.dismiss) private var dismiss
    
    // Services
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    var filteredItems: [MaintenanceItem] {
        let filtered = maintenanceItems.filter { item in
            switch selectedFilter {
            case .all:
                return true
            case .scheduled:
                return item.status == .scheduled
            case .inProgress:
                return item.status == .inProgress
            case .completed:
                return item.status == .completed
            case .overdue:
                return item.isOverdue
            }
        }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { item in
                let property = properties.first { $0.id == item.propertyId }
                return property?.itemName.localizedCaseInsensitiveContains(searchText) ?? false ||
                       property?.serialNumber.localizedCaseInsensitiveContains(searchText) ?? false ||
                       item.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var maintenanceStats: MaintenanceStats {
        let scheduled = maintenanceItems.filter { $0.status == .scheduled }.count
        let inProgress = maintenanceItems.filter { $0.status == .inProgress }.count
        let overdue = maintenanceItems.filter { $0.isOverdue }.count
        let completed30Days = maintenanceItems.filter { item in
            guard item.status == .completed,
                  let completedDate = item.completedDate else { return false }
            let daysSince = Calendar.current.dateComponents([.day], from: completedDate, to: Date()).day ?? 0
            return daysSince <= 30
        }.count
        
        return MaintenanceStats(
            scheduled: scheduled,
            inProgress: inProgress,
            overdue: overdue,
            completedLast30Days: completed30Days
        )
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    if isLoading {
                        loadingView
                    } else if let error = loadingError {
                        errorView(error: error)
                    } else {
                        mainContent
                    }
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Header
            UniversalHeaderView(title: "Maintenance")
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showingMaintenanceForm) {
            MaintenanceFormSheet(
                property: selectedProperty,
                maintenanceItem: selectedMaintenanceItem,
                onSave: { item in
                    saveMaintenanceItem(item)
                }
            )
        }
        .task {
            await loadData()
        }
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading maintenance data...")
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private func errorView(error: String) -> some View {
        WebAlignedCard {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                
                Text("Error Loading Data")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text(error)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                
                Button("Retry") {
                    Task { await refreshData() }
                }
                .buttonStyle(.primary)
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private var mainContent: some View {
        VStack(spacing: 24) {
            // Stats Overview
            statsOverview
            
            // Quick Actions
            quickActionsSection
            
            // Search and Filter
            searchAndFilterSection
            
            // Maintenance List
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                maintenanceListSection
            }
            
            // Bottom spacer
            Spacer()
                .frame(height: 100)
        }
    }
    
    private var statsOverview: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Maintenance Overview")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MaintenanceStatCard(
                    title: "Scheduled",
                    value: "\(maintenanceStats.scheduled)",
                    icon: "calendar",
                    color: .blue
                )
                
                MaintenanceStatCard(
                    title: "In Progress",
                    value: "\(maintenanceStats.inProgress)",
                    icon: "wrench.and.screwdriver",
                    color: AppColors.warning
                )
                
                MaintenanceStatCard(
                    title: "Overdue",
                    value: "\(maintenanceStats.overdue)",
                    icon: "exclamationmark.triangle",
                    color: AppColors.destructive
                )
                
                MaintenanceStatCard(
                    title: "Completed (30d)",
                    value: "\(maintenanceStats.completedLast30Days)",
                    icon: "checkmark.circle",
                    color: AppColors.success
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                selectedProperty = nil
                selectedMaintenanceItem = nil
                showingMaintenanceForm = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Schedule Maintenance")
                }
                .font(AppFonts.bodyBold)
            }
            .buttonStyle(.primary)
        }
        .padding(.horizontal)
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.secondaryText)
                
                TextField("Search equipment or maintenance...", text: $searchText)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                    .autocapitalization(.none)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.secondaryText)
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
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MaintenanceFilter.allCases, id: \.self) { filter in
                        FilterPill(
                            title: filter.title,
                            count: getCountForFilter(filter),
                            isSelected: selectedFilter == filter,
                            action: { selectedFilter = filter }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var emptyStateView: some View {
        WebAlignedCard {
            VStack(spacing: 16) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.tertiaryText)
                
                Text("No Maintenance Records")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text("No maintenance items match your current filter.")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                
                Button("Schedule Maintenance") {
                    selectedProperty = nil
                    selectedMaintenanceItem = nil
                    showingMaintenanceForm = true
                }
                .buttonStyle(.primary)
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }
    
    private var maintenanceListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Maintenance Items (\(filteredItems.count))")
            
            VStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    if let property = properties.first(where: { $0.id == item.propertyId }) {
                        MaintenanceItemCard(
                            item: item,
                            property: property,
                            onTap: {
                                selectedProperty = property
                                selectedMaintenanceItem = item
                                showingMaintenanceForm = true
                            }
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadData() async {
        isLoading = true
        loadingError = nil
        
        do {
            // Load properties
            properties = try await apiService.getMyProperties()
            
            // TODO: Load actual maintenance items from API
            // For now, generate mock data
            maintenanceItems = generateMockMaintenanceItems()
            
            isLoading = false
        } catch {
            loadingError = error.localizedDescription
            isLoading = false
        }
    }
    
    private func refreshData() async {
        await loadData()
    }
    
    private func saveMaintenanceItem(_ item: MaintenanceItem) {
        // TODO: Save to API
        if let index = maintenanceItems.firstIndex(where: { $0.id == item.id }) {
            maintenanceItems[index] = item
        } else {
            maintenanceItems.append(item)
        }
        
        showingMaintenanceForm = false
        selectedProperty = nil
        selectedMaintenanceItem = nil
    }
    
    private func getCountForFilter(_ filter: MaintenanceFilter) -> Int {
        switch filter {
        case .all:
            return maintenanceItems.count
        case .scheduled:
            return maintenanceItems.filter { $0.status == .scheduled }.count
        case .inProgress:
            return maintenanceItems.filter { $0.status == .inProgress }.count
        case .completed:
            return maintenanceItems.filter { $0.status == .completed }.count
        case .overdue:
            return maintenanceItems.filter { $0.isOverdue }.count
        }
    }
    
    private func generateMockMaintenanceItems() -> [MaintenanceItem] {
        guard !properties.isEmpty else { return [] }
        
        return (0..<10).compactMap { index in
            let property = properties.randomElement()!
            let status = MaintenanceStatus.allCases.randomElement()!
            let scheduledDate = Date().addingTimeInterval(Double.random(in: -2592000...2592000)) // -30 to +30 days
            
            return MaintenanceItem(
                id: UUID().uuidString,
                propertyId: property.id,
                type: MaintenanceType.allCases.randomElement()!,
                description: "Regular maintenance check #\(index + 1)",
                status: status,
                priority: MaintenancePriority.allCases.randomElement()!,
                scheduledDate: scheduledDate,
                completedDate: status == .completed ? scheduledDate.addingTimeInterval(3600) : nil,
                technician: status == .completed ? "SGT Williams" : nil,
                notes: status == .completed ? "Maintenance completed successfully" : nil,
                createdBy: "CPT Rodriguez",
                createdDate: scheduledDate.addingTimeInterval(-86400)
            )
        }
    }
}

// MARK: - Supporting Types

struct MaintenanceStats {
    let scheduled: Int
    let inProgress: Int
    let overdue: Int
    let completedLast30Days: Int
}

enum MaintenanceFilter: CaseIterable {
    case all, scheduled, inProgress, completed, overdue
    
    var title: String {
        switch self {
        case .all: return "All"
        case .scheduled: return "Scheduled"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .overdue: return "Overdue"
        }
    }
}

struct MaintenanceItem: Identifiable {
    let id: String
    let propertyId: Int
    let type: MaintenanceType
    let description: String
    var status: MaintenanceStatus
    let priority: MaintenancePriority
    let scheduledDate: Date
    var completedDate: Date?
    var technician: String?
    var notes: String?
    let createdBy: String
    let createdDate: Date
    
    var isOverdue: Bool {
        status != .completed && scheduledDate < Date()
    }
}

enum MaintenanceType: String, CaseIterable {
    case preventive = "Preventive"
    case corrective = "Corrective"
    case inspection = "Inspection"
    case calibration = "Calibration"
    case cleaning = "Cleaning"
    
    var icon: String {
        switch self {
        case .preventive: return "shield.checkered"
        case .corrective: return "wrench.and.screwdriver"
        case .inspection: return "magnifyingglass"
        case .calibration: return "gauge"
        case .cleaning: return "sparkles"
        }
    }
}

enum MaintenanceStatus: String, CaseIterable {
    case scheduled = "Scheduled"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
    
    var color: Color {
        switch self {
        case .scheduled: return .blue
        case .inProgress: return AppColors.warning
        case .completed: return AppColors.success
        case .cancelled: return AppColors.tertiaryText
        }
    }
}

enum MaintenancePriority: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .low: return AppColors.tertiaryText
        case .medium: return .blue
        case .high: return AppColors.warning
        case .critical: return AppColors.destructive
        }
    }
}



// MARK: - Maintenance Stat Card
struct MaintenanceStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        WebAlignedCard {
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
                
                Text(title.uppercased())
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .kerning(0.8)
            }
            .padding()
        }
    }
}

// MARK: - Maintenance Item Card
struct MaintenanceItemCard: View {
    let item: MaintenanceItem
    let property: Property
    let onTap: () -> Void
    
    private var statusIndicatorColor: Color {
        if item.isOverdue {
            return AppColors.destructive
        }
        return item.status.color
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        switch item.status {
        case .completed:
            if let completedDate = item.completedDate {
                return "Completed: \(formatter.string(from: completedDate))"
            }
        case .inProgress:
            return "Started: \(formatter.string(from: item.scheduledDate))"
        default:
            return "Scheduled: \(formatter.string(from: item.scheduledDate))"
        }
        
        return formatter.string(from: item.scheduledDate)
    }
    
    var body: some View {
        Button(action: onTap) {
            WebAlignedCard {
                HStack(spacing: 16) {
                    // Status Indicator
                    Rectangle()
                        .fill(statusIndicatorColor)
                        .frame(width: 4)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        // Header Row
                        HStack {
                            Label(item.type.rawValue, systemImage: item.type.icon)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                            
                            Spacer()
                            
                            // Priority Badge
                            Text(item.priority.rawValue.uppercased())
                                .font(AppFonts.caption2)
                                .foregroundColor(item.priority.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(item.priority.color.opacity(0.15))
                                .cornerRadius(0)
                        }
                        
                        // Equipment Info
                        Text(property.itemName)
                            .font(AppFonts.headline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("SN: \(property.serialNumber)")
                            .font(AppFonts.mono)
                            .foregroundColor(AppColors.secondaryText)
                        
                        // Maintenance Info
                        Text(item.description)
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.primaryText)
                            .lineLimit(2)
                        
                        // Date and Status
                        HStack {
                            Text(dateText)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                            
                            Spacer()
                            
                            if item.isOverdue {
                                Label("OVERDUE", systemImage: "exclamationmark.triangle.fill")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.destructive)
                            } else {
                                Text(item.status.rawValue.uppercased())
                                    .font(AppFonts.caption)
                                    .foregroundColor(item.status.color)
                            }
                        }
                    }
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.tertiaryText)
                }
                .padding()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Maintenance Form Sheet
struct MaintenanceFormSheet: View {
    let property: Property?
    let maintenanceItem: MaintenanceItem?
    let onSave: (MaintenanceItem) -> Void
    
    @State private var selectedPropertyId: Int?
    @State private var type: MaintenanceType = .preventive
    @State private var description = ""
    @State private var priority: MaintenancePriority = .medium
    @State private var scheduledDate = Date()
    @State private var notes = ""
    
    @Environment(\.dismiss) private var dismiss
    
    init(property: Property?, maintenanceItem: MaintenanceItem?, onSave: @escaping (MaintenanceItem) -> Void) {
        self.property = property
        self.maintenanceItem = maintenanceItem
        self.onSave = onSave
        
        if let item = maintenanceItem {
            _selectedPropertyId = State(initialValue: item.propertyId)
            _type = State(initialValue: item.type)
            _description = State(initialValue: item.description)
            _priority = State(initialValue: item.priority)
            _scheduledDate = State(initialValue: item.scheduledDate)
            _notes = State(initialValue: item.notes ?? "")
        } else if let property = property {
            _selectedPropertyId = State(initialValue: property.id)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Equipment Selection
                    if let property = property {
                        WebAlignedCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("EQUIPMENT")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                    .kerning(1.2)
                                
                                Text(property.itemName)
                                    .font(AppFonts.headline)
                                    .foregroundColor(AppColors.primaryText)
                                
                                Text("SN: \(property.serialNumber)")
                                    .font(AppFonts.mono)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .padding()
                        }
                    }
                    
                    // Maintenance Type
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MAINTENANCE TYPE")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .kerning(1.2)
                        
                        Picker("Type", selection: $type) {
                            ForEach(MaintenanceType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DESCRIPTION")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .kerning(1.2)
                        
                        TextField("Enter maintenance description...", text: $description)
                            .textFieldStyle(.industrial)
                    }
                    
                    // Priority
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PRIORITY")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .kerning(1.2)
                        
                        Picker("Priority", selection: $priority) {
                            ForEach(MaintenancePriority.allCases, id: \.self) { priority in
                                Text(priority.rawValue)
                                    .tag(priority)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Scheduled Date
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SCHEDULED DATE")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .kerning(1.2)
                        
                        DatePicker("", selection: $scheduledDate)
                            .datePickerStyle(CompactDatePickerStyle())
                            .labelsHidden()
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NOTES")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .kerning(1.2)
                        
                        TextEditor(text: $notes)
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.primaryText)
                            .padding(12)
                            .background(AppColors.secondaryBackground)
                            .overlay(
                                Rectangle()
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                            .frame(minHeight: 100)
                    }
                }
                .padding()
            }
            .background(AppColors.appBackground)
            .navigationTitle(maintenanceItem == nil ? "Schedule Maintenance" : "Edit Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMaintenanceItem()
                    }
                    .foregroundColor(AppColors.accent)
                    .disabled(description.isEmpty || selectedPropertyId == nil)
                }
            }
        }
    }
    
    private func saveMaintenanceItem() {
        guard let propertyId = selectedPropertyId ?? property?.id else { return }
        
        let item = MaintenanceItem(
            id: maintenanceItem?.id ?? UUID().uuidString,
            propertyId: propertyId,
            type: type,
            description: description,
            status: maintenanceItem?.status ?? .scheduled,
            priority: priority,
            scheduledDate: scheduledDate,
            completedDate: maintenanceItem?.completedDate,
            technician: maintenanceItem?.technician,
            notes: notes.isEmpty ? nil : notes,
            createdBy: maintenanceItem?.createdBy ?? "Current User", // TODO: Get from auth
            createdDate: maintenanceItem?.createdDate ?? Date()
        )
        
        onSave(item)
    }
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