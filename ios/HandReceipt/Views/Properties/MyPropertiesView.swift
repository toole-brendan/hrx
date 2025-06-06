// MARK: - Properties List with Import Indicators

import SwiftUI
import Combine

// Enhanced Properties List View
struct MyPropertiesView: View {
    @StateObject private var viewModel: MyPropertiesViewModel
    @State private var selectedProperty: Property?
    @State private var showingVerificationSheet = false
    @State private var showingCreateProperty = false
    @State private var showingSortOptions = false
    @State private var showingSearch = false
    @State private var showingDA2062Scan = false
    @State private var showingAddMenu = false
    @State private var showingDA2062Export = false
    @State private var isSelectMode = false
    @State private var selectedPropertiesForExport: Set<Int> = []
    @State private var showingTransferSheet = false
    @State private var selectedPropertyForTransfer: Property?
    
    init(viewModel: MyPropertiesViewModel? = nil) {
        let vm = viewModel ?? MyPropertiesViewModel(apiService: APIService())
        self._viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        ZStack {
            // Opaque background
            AppColors.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom minimal navigation bar - matches TransfersView
                MinimalNavigationBar(
                    title: "PROPERTY BOOK",
                    titleStyle: .mono
                )
                .background(AppColors.secondaryBackground)
                .zIndex(1)
                
                // Offline banner
                if viewModel.isOffline {
                    OfflineBanner()
                }
                
                ScrollView {
                VStack(spacing: 24) {
                    // Just the item count, no title
                    HStack {
                                            Text("\(viewModel.filteredProperties.count) items tracked")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.tertiaryText)
                    
                    Spacer()
                    
                    if !isSelectMode && !viewModel.filteredProperties.isEmpty {
                            Button("Select") {
                                isSelectMode = true
                            }
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.accent)
                        } else if isSelectMode {
                            Button("Cancel") {
                                isSelectMode = false
                                selectedPropertiesForExport.removeAll()
                            }
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Main content
                    VStack(spacing: 32) {
                        // Offline indicator
                        if viewModel.isOffline {
                            MinimalOfflineIndicator()
                                .padding(.horizontal, 24)
                        }
                        
                        // Search and filters section
                        searchAndFiltersSection
                        
                        // Properties content
                        propertiesContent
                        
                        // Sync status footer
                        if let lastSync = viewModel.lastSyncDate {
                            MinimalSyncStatusFooter(lastSync: lastSync, isSyncing: viewModel.isSyncing)
                        }
                    }
                    
                    // Bottom padding
                    Color.clear.frame(height: 80)
                }
            }
            .background(AppColors.appBackground)
            .minimalRefreshable {
                // Only allow refresh if not offline
                if !viewModel.isOffline {
                    await MainActor.run {
                        viewModel.loadProperties()
                    }
                }
            }
            .task {
                // Load from cache first (instant)
                await viewModel.loadCachedProperties()
                
                // Then try to fetch from network if online
                if !viewModel.isOffline {
                    viewModel.loadProperties()
                }
            }
            } // End of VStack containing navigation bar and content
            
            // Floating export button when items are selected
            if isSelectMode && !selectedPropertiesForExport.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            print("Export button tapped, setting showingDA2062Export to true")
                            print("Current value: \(showingDA2062Export)")
                            showingDA2062Export = true
                            print("New value: \(showingDA2062Export)")
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export DA 2062 (\(selectedPropertiesForExport.count))")
                            }
                            .padding()
                            .background(AppColors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                            .shadow(radius: 8)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCreateProperty) {
            CreatePropertyView()
                .onDisappear {
                    viewModel.refreshData()
                }
        }
        .sheet(isPresented: $showingDA2062Scan) {
            DA2062ScanView()
                .onDisappear {
                    viewModel.refreshData()
                }
        }
        .fullScreenCover(
            isPresented: $showingDA2062Export,
            onDismiss: {
                // Exit selection mode and clear selected items when modal closes
                isSelectMode = false
                selectedPropertiesForExport.removeAll()
            }
        ) {
            DA2062ExportView(preSelectedPropertyIDs: Array(selectedPropertiesForExport))
                .onAppear {
                    print("DA2062ExportView full screen cover appeared")
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
        .sheet(isPresented: $showingTransferSheet) {
            if let property = selectedPropertyForTransfer {
                PropertyTransferSheet(property: property) {
                    // Refresh properties after transfer
                    viewModel.refreshData()
                    showingTransferSheet = false
                    selectedPropertyForTransfer = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showingSearch) {
            MinimalSearchView(isPresented: $showingSearch, apiService: viewModel.apiService)
        }
        .actionSheet(isPresented: $showingSortOptions) {
            ActionSheet(
                title: Text("Sort Properties"),
                buttons: [
                    .default(Text("By Name")) { },
                    .default(Text("By Serial Number")) { },
                    .default(Text("By Status")) { },
                    .cancel()
                ]
            )
        }
        .confirmationDialog("Add Property", isPresented: $showingAddMenu) {
            Button("Create New Property") { 
                showingCreateProperty = true 
            }
            Button("Import from DA-2062") { 
                showingDA2062Scan = true 
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Search and Filters Section
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.tertiaryText)
                        .font(.system(size: 16, weight: .light))
                    
                    TextField("Search properties...", text: $viewModel.searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(AppColors.primaryText)
                        .font(AppFonts.body)
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.tertiaryText)
                                .font(.system(size: 14, weight: .light))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppColors.secondaryBackground)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                
                // Filter/Sort button
                Button(action: { showingSortOptions = true }) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundColor(AppColors.accent)
                        .font(.system(size: 16, weight: .light))
                        .frame(width: 44, height: 44)
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                }
                
                // Add button
                Button(action: { showingAddMenu = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(AppColors.accent)
                        .font(.system(size: 16, weight: .light))
                        .frame(width: 44, height: 44)
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 24)
            
                        // Filter tabs
            VStack(spacing: 12) {
                // Main filter type selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PropertyFilterType.allCases, id: \.self) { filterType in
                            FilterTypeChip(
                                filterType: filterType,
                                isSelected: viewModel.selectedFilterType == filterType,
                                action: { 
                                    viewModel.selectedFilterType = filterType
                                    // Reset sub-filters when changing main filter
                                    if filterType != .category {
                                        viewModel.selectedCategory = .all
                                    }
                                    if filterType != .status {
                                        viewModel.selectedStatus = .all
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                // Sub-filter chips
                if viewModel.selectedFilterType == .category || viewModel.selectedFilterType == .status {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if viewModel.selectedFilterType == .category {
                                ForEach(PropertyCategory.allCases, id: \.self) { category in
                                    PropertyCategoryChip(
                                        category: category,
                                        isSelected: viewModel.selectedCategory == category,
                                        action: { viewModel.selectedCategory = category }
                                    )
                                }
                            }
                            
                            if viewModel.selectedFilterType == .status {
                                ForEach(PropertyFilterStatus.allCases, id: \.self) { status in
                                    PropertyStatusChip(
                                        status: status,
                                        isSelected: viewModel.selectedStatus == status,
                                        action: { viewModel.selectedStatus = status }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
    }
    
    // MARK: - Properties Content
    
    private var propertiesContent: some View {
        VStack(spacing: 0) {
            // Show loading state only when loading and no properties and not offline
            if viewModel.isLoading && viewModel.allProperties.isEmpty && !viewModel.isOffline {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                        .scaleEffect(0.8)
                    
                    Text("LOADING PROPERTIES")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .kerning(AppFonts.wideKerning)
                }
                .padding(.vertical, 80)
            } else if let error = viewModel.error, viewModel.allProperties.isEmpty {
                // Show error only if we have no properties to display
                MinimalEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "Error Loading Properties",
                    message: error,
                    action: { 
                        Task { 
                            await MainActor.run {
                                viewModel.loadProperties()
                            }
                        }
                    },
                    actionLabel: "Retry"
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 80)
            } else if viewModel.filteredProperties.isEmpty {
                // Empty state when no properties match filters
                MinimalEmptyState(
                    icon: emptyStateIcon,
                    title: emptyStateTitle,
                    message: emptyStateMessage,
                    action: viewModel.refreshData,
                    actionLabel: "Refresh"
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 80)
            } else {
                // Properties list
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.filteredProperties) { property in
                        if isSelectMode {
                            MinimalPropertyCard(
                                property: property,
                                isSelected: selectedPropertiesForExport.contains(property.id),
                                isSelectMode: true
                            ) {
                                if selectedPropertiesForExport.contains(property.id) {
                                    selectedPropertiesForExport.remove(property.id)
                                } else {
                                    selectedPropertiesForExport.insert(property.id)
                                }
                            }
                        } else {
                            NavigationLink(destination: PropertyDetailView(propertyId: property.id)) {
                                MinimalPropertyCard(property: property) {
                                    if property.needsVerification {
                                        selectedProperty = property
                                        showingVerificationSheet = true
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                // Transfer Action
                                Button(action: {
                                    selectedPropertyForTransfer = property
                                    showingTransferSheet = true
                                }) {
                                    Label("Transfer Property", systemImage: "arrow.triangle.2.circlepath")
                                }
                                
                                // View Details Action
                                Button(action: {
                                    // Navigation is handled by NavigationLink
                                }) {
                                    Label("View Details", systemImage: "info.circle")
                                }
                                
                                // Verify Action (if needed)
                                if property.needsVerification {
                                    Button(action: {
                                        selectedProperty = property
                                        showingVerificationSheet = true
                                    }) {
                                        Label("Verify Property", systemImage: "checkmark.circle")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var emptyStateIcon: String {
        if !viewModel.searchText.isEmpty {
            return "magnifyingglass"
        }
        
        if viewModel.isOffline {
            return "wifi.slash"
        }
        
        if viewModel.selectedCategory != .all {
            return viewModel.selectedCategory.icon
        }
        
        if viewModel.selectedStatus != .all {
            return viewModel.selectedStatus.icon
        }
        
        return "shippingbox"
    }
    
    private var emptyStateTitle: String {
        if !viewModel.searchText.isEmpty {
            return "No Results Found"
        }
        
        if viewModel.isOffline {
            return "Offline Mode"
        }
        
        if viewModel.selectedCategory != .all {
            return "No \(viewModel.selectedCategory.displayName) Found"
        }
        
        if viewModel.selectedStatus != .all {
            return "No \(viewModel.selectedStatus.displayName) Items"
        }
        
        return "No Properties Found"
    }
    
    private var emptyStateMessage: String {
        if !viewModel.searchText.isEmpty {
            return "Try adjusting your search terms or filters."
        }
        
        if viewModel.isOffline {
            return "Properties will appear when connected to the network."
        }
        
        if viewModel.selectedCategory != .all {
            return "You have no \(viewModel.selectedCategory.displayName.lowercased()) assigned to you."
        }
        
        if viewModel.selectedStatus != .all {
            return "No items with \(viewModel.selectedStatus.displayName.lowercased()) status found."
        }
        
        return "Properties assigned to you will appear here."
    }
    
    // Note: Filtering and sorting logic moved to view model
}

// MARK: - Supporting Components

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(AppColors.warning)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline Mode")
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Changes will sync when connected")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.warning.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(AppColors.warning.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}



// MARK: - Minimal Components

struct MinimalOfflineIndicator: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(AppColors.warning)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Offline Mode")
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.warning)
                
                Text("Changes will sync when connected")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
        }
        .padding(20)
        .background(AppColors.warning.opacity(0.05))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(AppColors.warning.opacity(0.2), lineWidth: 1)
        )
    }
}

struct MinimalFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int?
    let action: () -> Void
    
    init(title: String, icon: String, isSelected: Bool, count: Int? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.count = count
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .light))
                
                Text(title.uppercased())
                    .font(AppFonts.caption)
                    .compatibleKerning(AppFonts.wideKerning)
                
                if let count = count {
                    Text("(\(count))")
                        .font(AppFonts.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .white : AppColors.secondaryText)
            .background(isSelected ? AppColors.primaryText : AppColors.secondaryBackground)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? AppColors.primaryText : AppColors.border, lineWidth: 1)
            )
        }
    }
}

struct MinimalPropertyCard: View {
    let property: Property
    var isSelected: Bool = false
    var isSelectMode: Bool = false
    let onTap: (() -> Void)?
    
    init(property: Property, isSelected: Bool = false, isSelectMode: Bool = false, onTap: (() -> Void)? = nil) {
        self.property = property
        self.isSelected = isSelected
        self.isSelectMode = isSelectMode
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row
            HStack(alignment: .top) {
                // Selection checkbox in select mode
                if isSelectMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.tertiaryText)
                        .padding(.trailing, 8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Item name with category and status indicators
                    HStack(spacing: 8) {
                        // Category indicator
                        let category = PropertyCategory.fromItemName(property.name)
                        if category != .other {
                            Image(systemName: category.icon)
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(category.color)
                        }
                        
                        Text(property.name)
                            .font(AppFonts.serifHeadline)
                            .foregroundColor(AppColors.primaryText)
                            .lineLimit(2)
                        
                        if property.isSensitive {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(AppColors.warning)
                        }
                        
                        if property.needsVerification {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(AppColors.destructive)
                        }
                    }
                    
                    // Serial number
                    HStack(spacing: 8) {
                        Text("S/N:")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                        Text(property.serialNumber)
                            .font(AppFonts.monoBody)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    // NSN if available
                    if let nsn = property.nsn {
                        HStack(spacing: 8) {
                            Text("NSN:")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                            Text(nsn)
                                .font(AppFonts.monoCaption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                }
                
                Spacer()
                
                // Status badge and last verification
                VStack(alignment: .trailing, spacing: 8) {
                    // Status badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text((property.status ?? "Unknown").uppercased())
                            .font(AppFonts.caption)
                            .foregroundColor(statusColor)
                            .compatibleKerning(AppFonts.wideKerning)
                    }
                    
                    // Last verification
                    if let lastInv = property.lastInventoryDate {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Last Verified")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                            Text(RelativeDateFormatter.shared.string(from: lastInv))
                                .font(AppFonts.caption)
                                .foregroundColor(verificationDateColor(lastInv))
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(isSelected ? AppColors.accent.opacity(0.1) : AppColors.secondaryBackground)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
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

struct MinimalSyncStatusFooter: View {
    let lastSync: Date
    let isSyncing: Bool
    
    var body: some View {
        HStack(spacing: 12) {
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
                    .font(.system(size: 16, weight: .light))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Synced")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                    Text(RelativeDateFormatter.shared.string(from: lastSync))
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(AppColors.tertiaryBackground)
        .overlay(
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Verification Sheet (8VC Styled)
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
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 0) {
                            HStack {
                                Button("Cancel") {
                                    dismiss()
                                }
                                .buttonStyle(TextLinkButtonStyle())
                                
                                Spacer()
                                
                                Text("Verify Property")
                                    .font(AppFonts.serifHeadline)
                                    .foregroundColor(AppColors.primaryText)
                                
                                Spacer()
                                
                                Button("Save") {
                                    verifyProperty()
                                }
                                .buttonStyle(TextLinkButtonStyle())
                                .disabled(isLoading || serialNumber.isEmpty)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            
                            Divider()
                                .background(AppColors.divider)
                        }
                        
                        // Content
                        VStack(spacing: 32) {
                            // Item information
                            VStack(spacing: 20) {
                                ElegantSectionHeader(
                                    title: "Item Information",
                                    style: .serif
                                )
                                .padding(.horizontal, 24)
                                
                                VStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Item Name")
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.tertiaryText)
                                        Text(property.name)
                                            .font(AppFonts.bodyMedium)
                                            .foregroundColor(AppColors.primaryText)
                                    }
                                    .cleanCard()
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            // Update form
                            VStack(spacing: 20) {
                                ElegantSectionHeader(
                                    title: "Update Information",
                                    style: .serif
                                )
                                .padding(.horizontal, 24)
                                
                                VStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Serial Number")
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.tertiaryText)
                                        TextField("Serial Number", text: $serialNumber)
                                            .font(AppFonts.monoBody)
                                            .textFieldStyle(MinimalTextFieldStyle())
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("NSN")
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.tertiaryText)
                                        TextField("NSN", text: $nsn)
                                            .font(AppFonts.monoBody)
                                            .textFieldStyle(MinimalTextFieldStyle())
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Notes")
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.tertiaryText)
                                        TextField("Additional notes...", text: $notes)
                                            .lineLimit(6)
                                            .textFieldStyle(MinimalTextFieldStyle())
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        // Bottom padding
                        Color.clear.frame(height: 40)
                    }
                }
                
                if isLoading {
                    VStack(spacing: 24) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                            .scaleEffect(1.2)
                        
                        Text("SAVING VERIFICATION")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .kerning(AppFonts.wideKerning)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.overlayBackground)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func verifyProperty() {
        isLoading = true
        
        Task {
            do {
                let result = try await APIService.shared.verifyImportedItem(
                    id: property.id,
                    serialNumber: serialNumber,
                    nsn: nsn.isEmpty ? nil : nsn,
                    notes: notes
                )
                
                await MainActor.run {
                    onSave(result)
                    dismiss()
                }
            } catch {
                print("Verification failed: \(error)")
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Property Transfer Sheet
struct PropertyTransferSheet: View {
    let property: Property
    let onComplete: () -> Void
    
    @StateObject private var connectionsViewModel = ConnectionsViewModel(apiService: APIService())
    @StateObject private var transferService = TransferService()
    @State private var selectedConnection: UserConnection?
    @State private var notes = ""
    @State private var isTransferring = false
    @State private var transferError: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 0) {
                            HStack {
                                Button("Cancel") {
                                    dismiss()
                                }
                                .buttonStyle(TextLinkButtonStyle())
                                
                                Spacer()
                                
                                Text("Transfer Property")
                                    .font(AppFonts.serifHeadline)
                                    .foregroundColor(AppColors.primaryText)
                                
                                Spacer()
                                
                                Button("Send") {
                                    transferProperty()
                                }
                                .buttonStyle(TextLinkButtonStyle())
                                .disabled(selectedConnection == nil || isTransferring)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            
                            Divider()
                                .background(AppColors.divider)
                        }
                        
                        // Content
                        VStack(spacing: 32) {
                            // Property information
                            VStack(spacing: 20) {
                                ElegantSectionHeader(
                                    title: "Property Details",
                                    style: .serif
                                )
                                .padding(.horizontal, 24)
                                
                                VStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Item Name")
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.tertiaryText)
                                        Text(property.name)
                                            .font(AppFonts.bodyMedium)
                                            .foregroundColor(AppColors.primaryText)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Serial Number")
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.tertiaryText)
                                        Text(property.serialNumber)
                                            .font(AppFonts.monoBody)
                                            .foregroundColor(AppColors.primaryText)
                                    }
                                    
                                    if let nsn = property.nsn {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("NSN")
                                                .font(AppFonts.caption)
                                                .foregroundColor(AppColors.tertiaryText)
                                            Text(nsn)
                                                .font(AppFonts.monoCaption)
                                                .foregroundColor(AppColors.secondaryText)
                                        }
                                    }
                                }
                                .cleanCard()
                                .padding(.horizontal, 24)
                            }
                            
                            // Transfer recipient selection
                            VStack(spacing: 20) {
                                ElegantSectionHeader(
                                    title: "Transfer To",
                                    style: .serif
                                )
                                .padding(.horizontal, 24)
                                
                                VStack(spacing: 16) {
                                    if connectionsViewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                                            .scaleEffect(0.8)
                                    } else if connectionsViewModel.connections.isEmpty {
                                        VStack(spacing: 12) {
                                            Image(systemName: "person.2.slash")
                                                .font(.system(size: 32, weight: .light))
                                                .foregroundColor(AppColors.tertiaryText)
                                            
                                            Text("No Connections")
                                                .font(AppFonts.bodyMedium)
                                                .foregroundColor(AppColors.primaryText)
                                            
                                            Text("Add connections in the Connections tab to transfer properties.")
                                                .font(AppFonts.caption)
                                                .foregroundColor(AppColors.secondaryText)
                                                .multilineTextAlignment(.center)
                                        }
                                        .padding(.vertical, 20)
                                    } else {
                                        ForEach(connectionsViewModel.connections) { connection in
                                            Button(action: {
                                                selectedConnection = connection
                                            }) {
                                                HStack(spacing: 16) {
                                                    // Avatar placeholder
                                                    Circle()
                                                        .fill(AppColors.accent.opacity(0.2))
                                                        .frame(width: 40, height: 40)
                                                        .overlay(
                                                            Text(String((connection.connectedUser?.name ?? "Unknown").prefix(1)))
                                                                .font(AppFonts.bodyMedium)
                                                                .foregroundColor(AppColors.accent)
                                                        )
                                                    
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(connection.connectedUser?.name ?? "Unknown User")
                                                            .font(AppFonts.bodyMedium)
                                                            .foregroundColor(AppColors.primaryText)
                                                        
                                                        if let rank = connection.connectedUser?.rank {
                                                            Text(rank)
                                                                .font(AppFonts.caption)
                                                                .foregroundColor(AppColors.secondaryText)
                                                        }
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: selectedConnection?.id == connection.id ? "checkmark.circle.fill" : "circle")
                                                        .foregroundColor(selectedConnection?.id == connection.id ? AppColors.accent : AppColors.tertiaryText)
                                                        .font(.system(size: 24, weight: .light))
                                                }
                                                .padding(16)
                                                .background(selectedConnection?.id == connection.id ? AppColors.accent.opacity(0.1) : AppColors.secondaryBackground)
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(selectedConnection?.id == connection.id ? AppColors.accent : AppColors.border, lineWidth: selectedConnection?.id == connection.id ? 2 : 1)
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            // Transfer notes
                            VStack(spacing: 20) {
                                ElegantSectionHeader(
                                    title: "Additional Information",
                                    style: .serif
                                )
                                .padding(.horizontal, 24)
                                
                                VStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Notes (Optional)")
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.tertiaryText)
                                        
                                        ZStack(alignment: .topLeading) {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(AppColors.secondaryBackground)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(AppColors.border, lineWidth: 1)
                                                )
                                                .frame(minHeight: 80)
                                            
                                            if notes.isEmpty {
                                                Text("Transfer notes...")
                                                    .font(AppFonts.body)
                                                    .foregroundColor(AppColors.tertiaryText)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 12)
                                            }
                                            
                                            TextEditor(text: $notes)
                                                .font(AppFonts.body)
                                                .foregroundColor(AppColors.primaryText)
                                                .background(Color.clear)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                    }
                                }
                                .cleanCard()
                                .padding(.horizontal, 24)
                            }
                            
                            // Error message
                            if let error = transferError {
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(AppColors.destructive)
                                        .font(.system(size: 24, weight: .light))
                                    
                                    Text(error)
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.destructive)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(16)
                                .background(AppColors.destructive.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppColors.destructive.opacity(0.3), lineWidth: 1)
                                )
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        // Bottom padding
                        Color.clear.frame(height: 40)
                    }
                }
                
                if isTransferring {
                    VStack(spacing: 24) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                            .scaleEffect(1.2)
                        
                        Text("CREATING TRANSFER")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .kerning(AppFonts.wideKerning)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.overlayBackground)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            connectionsViewModel.loadConnections()
        }
    }
    
    private func transferProperty() {
        guard let connection = selectedConnection,
              let connectedUser = connection.connectedUser else { return }
        
        isTransferring = true
        transferError = nil
        
        Task {
            do {
                let _ = try await transferService.createOfferToUser(
                    propertyId: property.id,
                    recipientUserId: connectedUser.id,
                    notes: notes.isEmpty ? nil : notes
                )
                
                await MainActor.run {
                    isTransferring = false
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isTransferring = false
                    transferError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Filter Chip Components
struct FilterTypeChip: View {
    let filterType: PropertyFilterType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(filterType.displayName.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(isSelected ? .white : AppColors.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.primaryText : AppColors.secondaryBackground)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? AppColors.primaryText : AppColors.border, lineWidth: 1)
                )
                .compatibleKerning(AppFonts.wideKerning)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PropertyCategoryChip: View {
    let category: PropertyCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.displayName.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(isSelected ? .white : AppColors.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.primaryText : AppColors.secondaryBackground)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? AppColors.primaryText : AppColors.border, lineWidth: 1)
                )
                .compatibleKerning(AppFonts.wideKerning)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PropertyStatusChip: View {
    let status: PropertyFilterStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(status.shortDisplayName.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(isSelected ? .white : AppColors.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.primaryText : AppColors.secondaryBackground)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? AppColors.primaryText : AppColors.border, lineWidth: 1)
                )
                .compatibleKerning(AppFonts.wideKerning)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct MyPropertiesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MyPropertiesView(viewModel: {
                let vm = MyPropertiesViewModel()
                vm.loadingState = .success(mockProperties)
                vm.allProperties = mockProperties
                return vm
            }())
        }
    }
    
    static var mockProperties: [Property] {
        return [
            Property(
                id: 1, 
                serialNumber: "SN123", 
                nsn: "1111-11-111-1111", 
                lin: "E03045", 
                name: "M4 Carbine", 
                description: "5.56mm Carbine", 
                manufacturer: "Colt", 
                imageUrl: nil, 
                status: "Operational", 
                currentStatus: "operational",
                assignedToUserId: nil, 
                location: "Armory", 
                lastInventoryDate: Date(), 
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
                importMetadata: nil,
                verified: true,
                verifiedAt: Date(),
                isAttachable: true,
                attachmentPoints: ["rail_top", "rail_side", "barrel"],
                compatibleWith: nil
            )
        ]
    }
}