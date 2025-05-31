import SwiftUI
import Combine

struct MyPropertiesView: View {
    @StateObject private var viewModel: MyPropertiesViewModel
    @State private var searchText = ""
    @State private var selectedFilter: PropertyFilter = .all
    @State private var showingCreateProperty = false
    @State private var showingSortOptions = false
    @State private var selectedSortOption: SortOption = .name
    
    enum PropertyFilter: String, CaseIterable {
        case all = "All"
        case operational = "Operational"
        case maintenance = "Maintenance"
        case sensitive = "Sensitive"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .operational: return "checkmark.circle"
            case .maintenance: return "wrench.and.screwdriver"
            case .sensitive: return "lock.shield"
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case serialNumber = "Serial Number"
        case lastVerification = "Last Verification"
        case status = "Status"
    }
    
    init(viewModel: MyPropertiesViewModel? = nil) {
        let vm = viewModel ?? MyPropertiesViewModel(apiService: APIService())
        self._viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollView {
                VStack(spacing: 0) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // The rest of the content
                    contentView
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Top bar that mirrors bottom tab bar
            headerSection
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCreateProperty) {
            CreatePropertyView()
                .onDisappear {
                    viewModel.loadProperties()
                }
        }
        .actionSheet(isPresented: $showingSortOptions) {
            ActionSheet(
                title: Text("Sort Properties"),
                buttons: SortOption.allCases.map { option in
                    .default(Text(option.rawValue)) {
                        selectedSortOption = option
                    }
                } + [.cancel()]
            )
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            // Welcome text
            Text("Manage Your Equipment")
                .font(AppFonts.largeTitle)
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            // Offline indicator
            if viewModel.isOffline {
                OfflineIndicator()
            }
            
            // Search and filters
            VStack(spacing: 12) {
                // Search bar with sort button
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.secondaryText)
                        
                        TextField("Search properties...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(AppColors.primaryText)
                            .font(AppFonts.body)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(8)
                    
                    // Sort button
                    Button(action: { showingSortOptions = true }) {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(AppColors.accent)
                            .font(.body)
                            .frame(width: 44, height: 44)
                            .background(AppColors.secondaryBackground)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PropertyFilter.allCases, id: \.self) { filter in
                            PropertyFilterPill(
                                title: filter.rawValue,
                                icon: filter.icon,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
            .background(AppColors.appBackground)
            
            // Properties list
            switch viewModel.loadingState {
            case .idle, .loading:
                LoadingView()
                
            case .success(let properties):
                let filteredProperties = filterAndSort(properties)
                
                if filteredProperties.isEmpty {
                    PropertiesEmptyStateView(
                        filter: selectedFilter,
                        searchText: searchText,
                        onRefresh: viewModel.loadProperties
                    )
                } else {
                    PropertyListView(
                        properties: filteredProperties,
                        viewModel: viewModel,
                        onRefresh: viewModel.loadProperties
                    )
                }
                
            case .error(let message):
                ErrorStateView(message: message) {
                    viewModel.loadProperties()
                }
            }
            
            // Sync status footer
            if let lastSync = viewModel.lastSyncDate {
                SyncStatusFooter(lastSync: lastSync, isSyncing: viewModel.isSyncing)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        ZStack {
            // Background that extends to top of screen
            AppColors.secondaryBackground
                .ignoresSafeArea()
            
            // Content positioned at bottom of header
            VStack {
                Spacer()
                Text("PROPERTY BOOK")
                    .font(.system(size: 16, weight: .medium)) // Larger font
                    .foregroundColor(AppColors.primaryText)
                    .kerning(1.2) // Match TransfersView tracking
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12) // Bottom padding
            }
        }
        .frame(height: 36) // Very tight header
    }
    
    // Filter and sort logic
    private func filterAndSort(_ properties: [Property]) -> [Property] {
        var filtered = properties
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { property in
                property.itemName.localizedCaseInsensitiveContains(searchText) ||
                property.serialNumber.localizedCaseInsensitiveContains(searchText) ||
                (property.nsn ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .operational:
            filtered = filtered.filter { ($0.status ?? "").lowercased() == "operational" }
        case .maintenance:
            filtered = filtered.filter { $0.needsMaintenance }
        case .sensitive:
            filtered = filtered.filter { $0.isSensitive }
        }
        
        // Apply sorting
        switch selectedSortOption {
        case .name:
            filtered.sort { $0.itemName < $1.itemName }
        case .serialNumber:
            filtered.sort { $0.serialNumber < $1.serialNumber }
        case .lastVerification:
            filtered.sort { ($0.lastInventoryDate ?? Date.distantPast) > ($1.lastInventoryDate ?? Date.distantPast) }
        case .status:
            filtered.sort { $0.status < $1.status }
        }
        
        return filtered
    }
}

// MARK: - Subviews

struct OfflineIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("OFFLINE MODE")
                .font(AppFonts.captionBold)
            Text("• Changes will sync when connected")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
        }
        .foregroundColor(AppColors.warning)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(AppColors.warning.opacity(0.1))
    }
}

struct PropertyFilterPill: View {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(isSelected ? .white : AppColors.secondaryText)
            .background(isSelected ? AppColors.accent : AppColors.secondaryBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
            )
        }
    }
}

struct PropertyListView: View {
    let properties: [Property]
    @ObservedObject var viewModel: MyPropertiesViewModel
    let onRefresh: () -> Void
    
    var body: some View {
        List {
            ForEach(properties) { property in
                NavigationLink(destination: PropertyDetailView(propertyId: property.id)) {
                    PropertyRowEnhanced(property: property)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            onRefresh()
        }
    }
}

struct PropertyRowEnhanced: View {
    let property: Property
    
    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Status indicator
                VStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(statusColor.opacity(0.3), lineWidth: 2)
                        )
                    
                    if property.isSensitive {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.warning)
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
                
                // Main content
                VStack(alignment: .leading, spacing: 6) {
                    // Item name and NSN
                    Text(property.itemName)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label(property.nsn, systemImage: "number")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        if let lin = property.lin {
                            Text("LIN: \(lin)")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    
                    // Serial number
                    HStack {
                        Text("S/N:")
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.tertiaryText)
                        Text(property.serialNumber)
                            .font(AppFonts.mono)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    // Bottom row: status and last verification
                    HStack {
                        StatusBadge(status: property.status, type: statusBadgeType)
                        
                        Spacer()
                        
                        if let lastInv = property.lastInventoryDate {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Last Verification")
                                    .font(AppFonts.caption2)
                                    .foregroundColor(AppColors.tertiaryText)
                                Text(lastInv, formatter: Self.dateFormatter)
                                    .font(AppFonts.caption)
                                    .foregroundColor(verificationDateColor(lastInv))
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.tertiaryText)
                    .padding(.top, 4)
            }
            .padding()
            .background(AppColors.secondaryBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
    
    private var statusColor: Color {
        switch property.status.lowercased() {
        case "operational": return AppColors.success
        case "maintenance", "non-operational": return AppColors.warning
        case "missing": return AppColors.destructive
        default: return AppColors.secondaryText
        }
    }
    
    private var statusBadgeType: StatusBadge.StatusType {
        switch property.status.lowercased() {
        case "operational": return .success
        case "maintenance", "non-operational": return .warning
        case "missing": return .error
        default: return .neutral
        }
    }
    
    private func verificationDateColor(_ date: Date) -> Color {
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if daysSince > 90 {
            return AppColors.destructive
        } else if daysSince > 30 {
            return AppColors.warning
        } else {
            return AppColors.secondaryText
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                .scaleEffect(1.5)
            
            Text("Loading property book...")
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(.vertical, 50)
    }
}

struct PropertiesEmptyStateView: View {
    let filter: MyPropertiesView.PropertyFilter
    let searchText: String
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: emptyStateIcon)
                .font(.system(size: 64))
                .foregroundColor(AppColors.secondaryText)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text(emptyStateMessage)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button("Refresh", action: onRefresh)
                .buttonStyle(.primary)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
    
    private var emptyStateIcon: String {
        if !searchText.isEmpty {
            return "magnifyingglass"
        }
        switch filter {
        case .all: return "archivebox"
        case .operational: return "checkmark.circle"
        case .maintenance: return "wrench.and.screwdriver"
        case .sensitive: return "lock.shield"
        }
    }
    
    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No Results Found"
        }
        switch filter {
        case .all: return "No Properties Assigned"
        case .operational: return "No Operational Items"
        case .maintenance: return "No Maintenance Required"
        case .sensitive: return "No Sensitive Items"
        }
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try adjusting your search terms or filters."
        }
        switch filter {
        case .all: return "Properties assigned to you will appear here."
                    case .operational: return "You have no operational properties assigned to you."
        case .maintenance: return "Good news! No items require maintenance."
        case .sensitive: return "You have no sensitive items assigned."
        }
    }
}

struct SyncStatusFooter: View {
    let lastSync: Date
    let isSyncing: Bool
    
    private static let timeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    var body: some View {
        HStack {
            if isSyncing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                    .scaleEffect(0.8)
                Text("Syncing...")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.accent)
            } else {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(AppColors.success)
                    .font(.caption)
                Text("Last synced \(lastSync, formatter: Self.timeFormatter)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(AppColors.secondaryBackground)
    }
}

// MARK: - Preview
struct MyPropertiesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MyPropertiesView(viewModel: {
                let vm = MyPropertiesViewModel(apiService: MockAPIService())
                vm.loadingState = .success(Property.mockList)
                return vm
            }())
        }
        .preferredColorScheme(.dark)
    }
}

// Add MockAPIService and mock data for previews
#if DEBUG
// MockAPIService is now imported from Services/MockAPIService.swift
// No need to duplicate it here

extension Property {
    static let mockList = [
        Property(
            id: 1, 
            serialNumber: "SN123", 
            nsn: "1111-11-111-1111", 
            lin: "E03045", 
            name: "Test Prop 1", 
            description: "Mock Description 1", 
            manufacturer: "Mock Manu", 
            imageUrl: nil, 
            status: "Operational", 
            currentStatus: "operational",
            assignedToUserId: nil, 
            location: "Bldg 1", 
            lastInventoryDate: Date(), 
            acquisitionDate: nil, 
            notes: nil,
            maintenanceDueDate: nil,
            isSensitiveItem: false,
            propertyModelId: nil,
            lastVerifiedAt: nil,
            lastMaintenanceAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Property(
            id: 2, 
            serialNumber: "SN456", 
            nsn: "2222-22-222-2222", 
            lin: "E03046", 
            name: "Test Prop 2", 
            description: "Mock Description 2", 
            manufacturer: "Mock Manu", 
            imageUrl: nil, 
            status: "Maintenance", 
            currentStatus: "maintenance",
            assignedToUserId: nil, 
            location: "Bldg 2", 
            lastInventoryDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()), 
            acquisitionDate: nil, 
            notes: nil,
            maintenanceDueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
            isSensitiveItem: false,
            propertyModelId: nil,
            lastVerifiedAt: nil,
            lastMaintenanceAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Property(
            id: 3, 
            serialNumber: "SN789", 
            nsn: "3333-33-333-3333", 
            lin: "E03047", 
            name: "Test Prop 3", 
            description: "Mock Description 3", 
            manufacturer: "Mock Manu", 
            imageUrl: nil, 
            status: "Operational", 
            currentStatus: "operational",
            assignedToUserId: nil, 
            location: "Bldg 1", 
            lastInventoryDate: Calendar.current.date(byAdding: .month, value: -1, to: Date()), 
            acquisitionDate: nil, 
            notes: nil,
            maintenanceDueDate: nil,
            isSensitiveItem: true,
            propertyModelId: nil,
            lastVerifiedAt: nil,
            lastMaintenanceAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
}
#endif 