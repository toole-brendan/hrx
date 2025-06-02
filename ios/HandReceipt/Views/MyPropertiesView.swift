// MARK: - Properties List with Import Indicators

import SwiftUI
import Combine

// Enhanced Properties List View
struct MyPropertiesView: View {
    @StateObject private var viewModel: MyPropertiesViewModel
    @State private var showingUnverifiedOnly = false
    @State private var selectedProperty: Property?
    @State private var showingVerificationSheet = false
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
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // Welcome section with modern header
                    ModernSectionHeader(
                        title: "Manage Your Property",
                        subtitle: "Track and maintain your assigned property"
                    )
                    
                    // The rest of the content
                    mainContent
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
        .sheet(isPresented: $showingVerificationSheet) {
            if let property = selectedProperty {
                PropertyVerificationSheet(property: property) { updatedProperty in
                    viewModel.updateProperty(updatedProperty)
                    showingVerificationSheet = false
                }
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
    private var mainContent: some View {
        VStack(spacing: 24) {
            // Offline indicator
            if viewModel.isOffline {
                OfflineIndicator()
                    .padding(.top, -12) // Tighten up the spacing since we already have 24pt from parent
            }
            
            // Search and filters section
            VStack(spacing: 16) {
                // Search bar with sort button
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.tertiaryText)
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("Search properties...", text: $searchText)
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
                
                // Filter pills and unverified toggle
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Filter pills
                        ForEach(PropertyFilter.allCases, id: \.self) { filter in
                            PropertyFilterPill(
                                title: filter.rawValue,
                                icon: filter.icon,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                        
                        // Divider
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(width: 1, height: 20)
                        
                        // Unverified toggle as a pill
                        Button(action: { showingUnverifiedOnly.toggle() }) {
                            HStack(spacing: 6) {
                                Image(systemName: showingUnverifiedOnly ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("UNVERIFIED")
                                    .font(AppFonts.captionBold)
                                    .compatibleKerning(AppFonts.wideTracking)
                                if viewModel.unverifiedCount > 0 {
                                    Text("(\(viewModel.unverifiedCount))")
                                        .font(AppFonts.captionBold)
                                        .compatibleKerning(AppFonts.normalTracking)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .foregroundColor(showingUnverifiedOnly ? Color.black : AppColors.warning)
                            .background(showingUnverifiedOnly ? AppColors.warning : AppColors.warning.opacity(0.1))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AppColors.warning.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(
                                color: showingUnverifiedOnly ? AppColors.warning.opacity(0.3) : Color.clear,
                                radius: showingUnverifiedOnly ? 4 : 0,
                                y: showingUnverifiedOnly ? 2 : 0
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Properties list content
            VStack(spacing: 0) {
                switch viewModel.loadingState {
                case .idle, .loading:
                    PropertyLoadingView()
                        .padding(.vertical, 50)
                    
                case .success(_):
                    if filteredProperties.isEmpty {
                        PropertiesEmptyStateView(
                            filter: selectedFilter,
                            searchText: searchText,
                            onRefresh: viewModel.loadProperties
                        )
                        .padding(.vertical, 50)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredProperties) { property in
                                NavigationLink(destination: PropertyDetailView(propertyId: property.id)) {
                                    ModernPropertyCard(property: property) {
                                        if property.needsVerification {
                                            selectedProperty = property
                                            showingVerificationSheet = true
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    
                case .error(let message):
                    ErrorStateView(message: message) {
                        viewModel.loadProperties()
                    }
                    .padding(.vertical, 50)
                }
            }
            .frame(maxHeight: .infinity)
            
            // Sync status footer
            if let lastSync = viewModel.lastSyncDate {
                SyncStatusFooter(lastSync: lastSync, isSyncing: viewModel.isSyncing)
                    .padding(.top, -24) // Pull it closer since we have the VStack spacing
            }
            
            // Bottom spacer for tab bar
            Spacer()
                .frame(height: 80)
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
                    .compatibleKerning(AppFonts.militaryTracking)
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
        
        // Apply unverified filter
        if showingUnverifiedOnly {
            filtered = filtered.filter { $0.needsVerification }
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
            filtered.sort { ($0.status ?? "") < ($1.status ?? "") }
        }
        
        return filtered
    }
    
    var filteredProperties: [Property] {
        if case .success(let properties) = viewModel.loadingState {
            return filterAndSort(properties)
        }
        return []
    }
}

// MARK: - Subviews

struct OfflineIndicator: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.warning.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.warning)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("OFFLINE MODE")
                    .font(AppFonts.captionHeavy)
                    .foregroundColor(AppColors.warning)
                    .compatibleKerning(AppFonts.militaryTracking)
                
                Text("Changes will sync when connected")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
        }
        .padding(12)
        .background(AppColors.warning.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
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
                    .font(.system(size: 12, weight: .semibold))
                Text(title.uppercased())
                    .font(AppFonts.captionBold)
                    .compatibleKerning(AppFonts.wideTracking)
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
                        if let nsn = property.nsn {
                            Label(nsn, systemImage: "number")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
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
                        StatusBadge(status: property.status ?? property.currentStatus ?? "Unknown", type: statusBadgeType)
                        
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
        let status = (property.status ?? property.currentStatus ?? "").lowercased()
        switch status {
        case "operational": return AppColors.success
        case "maintenance", "non-operational": return AppColors.warning
        case "missing": return AppColors.destructive
        default: return AppColors.secondaryText
        }
    }
    
    private var statusBadgeType: StatusBadge.StatusType {
        let status = (property.status ?? property.currentStatus ?? "").lowercased()
        switch status {
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

struct PropertyLoadingView: View {
    var body: some View {
        IndustrialLoadingView(message: "LOADING PROPERTY BOOK")
    }
}

struct PropertiesEmptyStateView: View {
    let filter: MyPropertiesView.PropertyFilter
    let searchText: String
    let onRefresh: () -> Void
    
    var body: some View {
        ModernEmptyStateView(
            icon: emptyStateIcon,
            title: emptyStateTitle,
            message: emptyStateMessage,
            actionTitle: "REFRESH",
            action: onRefresh
        )
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
        HStack(spacing: 8) {
            if isSyncing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                    .scaleEffect(0.7)
                Text("SYNCING...")
                    .font(AppFonts.captionBold)
                    .foregroundColor(AppColors.accent)
                    .compatibleKerning(AppFonts.wideTracking)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                    .font(.system(size: 12, weight: .semibold))
                HStack(spacing: 4) {
                    Text("LAST SYNCED")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .compatibleKerning(AppFonts.normalTracking)
                    Text(lastSync, formatter: Self.timeFormatter)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(AppColors.tertiaryBackground)
        .overlay(
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1),
            alignment: .top
        )
    }
}

// Property row with import indicators
struct PropertyRowWithImportInfo: View {
    let property: Property
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header row with name and status icons
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(property.name)
                                .font(AppFonts.bodyBold)
                                .foregroundColor(AppColors.primaryText)
                                .lineLimit(2)
                            
                            if property.isImportedFromDA2062 {
                                Image(systemName: "doc.badge.plus")
                                    .font(.caption)
                                    .foregroundColor(AppColors.accent)
                            }
                            
                            if property.needsVerification {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(AppColors.warning)
                            }
                            
                            if property.isSensitive {
                                Image(systemName: "lock.shield.fill")
                                    .font(.caption)
                                    .foregroundColor(AppColors.warning)
                            }
                        }
                        
                        // NSN and Serial Number
                        HStack(spacing: 12) {
                            if let nsn = property.nsn {
                                HStack(spacing: 4) {
                                    Text("NSN:")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.tertiaryText)
                                    Text(nsn)
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                }
                            }
                            
                            HStack(spacing: 4) {
                                Text("S/N:")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.tertiaryText)
                                Text(property.serialNumber)
                                    .font(AppFonts.mono)
                                    .foregroundColor(AppColors.secondaryText)
                                    .strikethrough(property.isGeneratedSerial)
                                
                                if property.isGeneratedSerial {
                                    Text("(Generated)")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.warning)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    VStack(alignment: .trailing, spacing: 4) {
                        statusIndicator
                        
                        if let lastInventoryDate = property.lastInventoryDate {
                            Text(formatRelativeDate(lastInventoryDate))
                                .font(AppFonts.caption)
                                .foregroundColor(verificationDateColor(lastInventoryDate))
                        }
                    }
                }
                
                // Additional info row if needed
                if property.needsVerification || property.importMetadata != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        if property.needsVerification {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.warning)
                                Text(property.verificationReasons.first ?? "Needs verification")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.warning)
                                    .lineLimit(1)
                            }
                        }
                        
                        if let metadata = property.importMetadata,
                           let formNumber = metadata.formNumber {
                            Text("Imported from DA-2062 #\(formNumber)")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                }
            }
            .padding()
            .background(AppColors.secondaryBackground)
            .overlay(
                Rectangle()
                    .stroke(isPressed ? AppColors.accent : AppColors.border, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        let status = property.status ?? property.currentStatus ?? "unknown"
        let (color, icon) = statusInfo(for: status)
        
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(status.uppercased())
                .font(AppFonts.captionBold)
                .compatibleKerning(AppFonts.militaryTracking)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .overlay(
            Rectangle()
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func statusInfo(for status: String) -> (Color, String) {
        switch status.lowercased() {
        case "operational", "active":
            return (AppColors.success, "checkmark.circle.fill")
        case "maintenance", "non-operational":
            return (AppColors.warning, "wrench.and.screwdriver.fill")
        case "missing":
            return (AppColors.destructive, "xmark.circle.fill")
        default:
            return (AppColors.secondaryText, "questionmark.circle.fill")
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
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Verification Sheet
struct PropertyVerificationSheet: View {
    let property: Property
    let onSave: (Property) -> Void
    
    @State private var serialNumber: String
    @State private var nsn: String
    @State private var notes: String = ""
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    init(property: Property, onSave: @escaping (Property) -> Void) {
        self.property = property
        self.onSave = onSave
        self._serialNumber = State(initialValue: property.serialNumber)
        self._nsn = State(initialValue: property.nsn ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Item Information") {
                    Text(property.name)
                        .font(.headline)
                    
                    if let metadata = property.importMetadata {
                        HStack {
                            Text("Import Date")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(metadata.importDate.formatted(date: .abbreviated, time: .omitted))
                        }
                        
                        HStack {
                            Text("OCR Confidence")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(metadata.itemConfidence * 100))%")
                        }
                    }
                }
                
                Section("Verification Required") {
                    ForEach(property.verificationReasons, id: \.self) { reason in
                        Label(reason, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                
                Section("Update Information") {
                    TextField("Serial Number", text: $serialNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if property.isGeneratedSerial {
                        Text("Original: \(property.serialNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    TextField("NSN", text: $nsn)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    VStack(alignment: .leading) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $notes)
                            .frame(minHeight: 60, maxHeight: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                
                if let metadata = property.importMetadata,
                   let originalQty = metadata.originalQuantity,
                   let qtyIndex = metadata.quantityIndex {
                    Section("Multi-Item Information") {
                        Text("This is item \(qtyIndex) of \(originalQty)")
                            .font(.caption)
                        
                        Text("Other items from this set may also need verification")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Verify Property")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Verify") {
                    verifyProperty()
                }
                .disabled(isLoading || serialNumber.isEmpty)
            )
            .overlay {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
    
    private func verifyProperty() {
        isLoading = true
        
        Task {
            do {
                // Update via API - the API will return the updated property
                let result = try await APIService.shared.verifyImportedItem(
                    id: property.id,
                    serialNumber: serialNumber,
                    nsn: nsn.isEmpty ? nil : nsn,
                    notes: notes
                )
                
                onSave(result)
            } catch {
                // Handle error
                print("Verification failed: \(error)")
            }
            
            isLoading = false
        }
    }
}

// Import Summary View (shown after successful import)
struct PropertyImportSummaryView: View {
    let importResult: ImportResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Success header
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Import Successful")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Summary stats
                VStack(alignment: .leading, spacing: 12) {
                    SummaryRow(label: "Total Items Imported", 
                             value: "\(importResult.totalItems)")
                    
                    SummaryRow(label: "Verified Automatically", 
                             value: "\(importResult.verifiedCount)",
                             color: .green)
                    
                    if importResult.verificationNeeded > 0 {
                        SummaryRow(label: "Need Verification", 
                                 value: "\(importResult.verificationNeeded)",
                                 color: .orange)
                    }
                    
                    if importResult.generatedSerials > 0 {
                        SummaryRow(label: "Generated Serials", 
                                 value: "\(importResult.generatedSerials)",
                                 color: .blue)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // Category breakdown
                if !importResult.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Categories")
                            .font(.headline)
                        
                        ForEach(Array(importResult.categories.keys), id: \.self) { category in
                            HStack {
                                Text(category)
                                    .font(.caption)
                                Spacer()
                                Text("\(importResult.categories[category] ?? 0)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    if importResult.verificationNeeded > 0 {
                        Button(action: navigateToUnverified) {
                            Label("Review Unverified Items", 
                                  systemImage: "exclamationmark.triangle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    
                    Button(action: { dismiss() }) {
                        Text("View My Properties")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Import Complete")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func navigateToUnverified() {
        dismiss()
        // Navigate to properties view with unverified filter
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

struct ImportResult {
    let totalItems: Int
    let verifiedCount: Int
    let verificationNeeded: Int
    let generatedSerials: Int
    let categories: [String: Int]
}

// MARK: - Preview
struct MyPropertiesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MyPropertiesView(viewModel: {
                let vm = MyPropertiesViewModel()
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
            updatedAt: Date(),
            sourceType: nil,
            importMetadata: nil
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
            updatedAt: Date(),
            sourceType: nil,
            importMetadata: nil
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
            updatedAt: Date(),
            sourceType: nil,
            importMetadata: nil
        )
    ]
}
#endif 