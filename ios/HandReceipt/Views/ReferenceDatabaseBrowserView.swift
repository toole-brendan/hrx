import SwiftUI

// MARK: - Reference Database Browser View
struct ReferenceDatabaseBrowserView: View {
    @State private var searchText = ""
    @State private var selectedCategory: EquipmentCategory = .all
    @State private var referenceItems: [ReferenceProperty] = []
    @State private var isLoading = false
    @State private var loadingError: String?
    @State private var showingItemDetail = false
    @State private var selectedItem: ReferenceProperty?
    
    // Services
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    var filteredItems: [ReferenceProperty] {
        let categoryFiltered = referenceItems.filter { item in
            selectedCategory == .all || item.category?.lowercased() == selectedCategory.rawValue.lowercased()
        }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.nsn.localizedCaseInsensitiveContains(searchText) ||
                (item.description ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // Welcome Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reference Database")
                            .font(AppFonts.largeTitle)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("Browse NSN/LIN catalog for standard military equipment")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Stats Section
                    statsSection
                    
                    // Search and Filter
                    searchAndFilterSection
                    
                    // Items List
                    if isLoading {
                        loadingView
                    } else if let error = loadingError {
                        errorView(error: error)
                    } else if filteredItems.isEmpty {
                        emptyStateView
                    } else {
                        itemsListSection
                    }
                    
                    // Bottom spacer
                    Spacer()
                        .frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Header
            ReferenceDBHeaderSection()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showingItemDetail) {
            if let item = selectedItem {
                ReferencePropertyDetailSheet(item: item)
            }
        }
        .task {
            await loadReferenceData()
        }
    }
    
    // MARK: - View Components
    
    private var statsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ReferenceStatCard(
                value: "\(referenceItems.count)",
                label: "Total Items",
                icon: "shippingbox.fill",
                color: .blue
            )
            
            ReferenceStatCard(
                value: "\(Set(referenceItems.map { $0.category }).count)",
                label: "Categories",
                icon: "square.grid.2x2",
                color: AppColors.accent
            )
            
            ReferenceStatCard(
                value: "2024",
                label: "Last Updated",
                icon: "clock",
                color: AppColors.success
            )
        }
        .padding(.horizontal)
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.secondaryText)
                
                TextField("Search by NSN, LIN, or name...", text: $searchText)
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
            
            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(EquipmentCategory.allCases, id: \.self) { category in
                        CategoryPill(
                            category: category,
                            isSelected: selectedCategory == category,
                            count: getCategoryCount(category),
                            action: { selectedCategory = category }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading reference data...")
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(.top, 50)
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
                    Task { await loadReferenceData() }
                }
                .buttonStyle(.primary)
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private var emptyStateView: some View {
        WebAlignedCard {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.tertiaryText)
                
                Text("No Items Found")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Try adjusting your search or filter criteria.")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }
    
    private var itemsListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(
                title: "Reference Items (\(filteredItems.count))",
                action: filteredItems.count > 10 ? { /* TODO: Show all */ } : nil,
                actionLabel: "Show All"
            )
            
            VStack(spacing: 12) {
                ForEach(filteredItems.prefix(50)) { item in
                    ReferencePropertyCard(
                        item: item,
                        onTap: {
                            selectedItem = item
                            showingItemDetail = true
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadReferenceData() async {
        isLoading = true
        loadingError = nil
        
        // TODO: Load from actual NSN API
        // For now, generate mock data
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay to simulate loading
        
        referenceItems = generateMockReferencePropertys()
        isLoading = false
    }
    
    private func getCategoryCount(_ category: EquipmentCategory) -> Int {
        if category == .all {
            return referenceItems.count
        }
        return referenceItems.filter { $0.category?.lowercased() == category.rawValue.lowercased() }.count
    }
    
    private func generateMockReferencePropertys() -> [ReferenceProperty] {
        let items = [
            ReferenceProperty(
                id: 1,
                name: "Night Vision Goggle AN/PVS-14",
                nsn: "5855-01-432-8923",
                description: "Monocular night vision device for individual soldier use",
                manufacturer: "L3Harris Technologies",
                category: "Optics",
                unitOfIssue: "EA",
                unitPrice: 3245.00,
                imageUrl: nil,
                specifications: nil
            ),
            ReferenceProperty(
                id: 2,
                name: "Radio Set AN/PRC-152A",
                nsn: "5965-01-547-3421",
                description: "Multiband handheld tactical radio with encryption",
                manufacturer: "Harris Corporation",
                category: "Communications",
                unitOfIssue: "EA",
                unitPrice: 4850.00,
                imageUrl: nil,
                specifications: nil
            ),
            ReferenceProperty(
                id: 3,
                name: "Machine Gun M240B",
                nsn: "1005-01-519-8385",
                description: "7.62mm medium machine gun",
                manufacturer: "FN Herstal",
                category: "Weapons",
                unitOfIssue: "EA",
                unitPrice: 8435.00,
                imageUrl: nil,
                specifications: nil
            ),
            ReferenceProperty(
                id: 4,
                name: "HMMWV M1151A1",
                nsn: "2350-01-438-7522",
                description: "High Mobility Multipurpose Wheeled Vehicle with armor",
                manufacturer: "AM General",
                category: "Vehicles",
                unitOfIssue: "EA",
                unitPrice: 220000.00,
                imageUrl: nil,
                specifications: nil
            ),
            ReferenceProperty(
                id: 5,
                name: "Computer Unit AN/UYK-128",
                nsn: "5895-01-521-6789",
                description: "Ruggedized tactical computer system",
                manufacturer: "Lockheed Martin",
                category: "Electronics",
                unitOfIssue: "EA",
                unitPrice: 12500.00,
                imageUrl: nil,
                specifications: nil
            )
        ]
        
        // Duplicate items with variations to create more data
        var allItems: [ReferenceProperty] = []
        for i in 0..<5 {
            for (index, baseItem) in items.enumerated() {
                let newId = i * items.count + index + 1
                let newName = i > 0 ? "\(baseItem.name) (Variant \(i))" : baseItem.name
                let newNsn = i > 0 ? String(baseItem.nsn.dropLast(4)) + String(format: "%04d", Int.random(in: 1000...9999)) : baseItem.nsn
                
                let item = ReferenceProperty(
                    id: newId,
                    name: newName,
                    nsn: newNsn,
                    description: baseItem.description,
                    manufacturer: baseItem.manufacturer,
                    category: baseItem.category,
                    unitOfIssue: baseItem.unitOfIssue,
                    unitPrice: baseItem.unitPrice,
                    imageUrl: baseItem.imageUrl,
                    specifications: baseItem.specifications
                )
                allItems.append(item)
            }
        }
        
        return allItems
    }
}

// MARK: - Supporting Types

enum EquipmentCategory: String, CaseIterable {
    case all = "All"
    case weapons = "Weapons"
    case communications = "Communications"
    case optics = "Optics"
    case vehicles = "Vehicles"
    case electronics = "Electronics"
    case medical = "Medical"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .weapons: return "scope"
        case .communications: return "antenna.radiowaves.left.and.right"
        case .optics: return "eye"
        case .vehicles: return "car.fill"
        case .electronics: return "cpu"
        case .medical: return "cross.case.fill"
        case .other: return "shippingbox.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return AppColors.accent
        case .weapons: return AppColors.weaponsCategory
        case .communications: return AppColors.communicationsCategory
        case .optics: return AppColors.opticsCategory
        case .vehicles: return AppColors.vehiclesCategory
        case .electronics: return AppColors.electronicsCategory
        case .medical: return .red
        case .other: return .gray
        }
    }
}

// ReferenceProperty struct removed - using the one from Models/ReferenceProperty.swift

// MARK: - Header Section
struct ReferenceDBHeaderSection: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppColors.secondaryBackground
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                HStack {
                    // Back button
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(AppColors.accent)
                    }
                    
                    Spacer()
                    
                    Text("REFERENCE DATABASE")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.primaryText)
                        .kerning(1.2)
                    
                    Spacer()
                    
                    // Invisible placeholder for balance
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.clear)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 36)
    }
}

// MARK: - Reference Stat Card
struct ReferenceStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        WebAlignedCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(value)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text(label.uppercased())
                    .font(AppFonts.caption2)
                    .foregroundColor(AppColors.secondaryText)
                    .kerning(0.6)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let category: EquipmentCategory
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                
                Text(category.rawValue)
                    .font(AppFonts.caption)
                
                Text("(\(count))")
                    .font(AppFonts.captionBold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .white : AppColors.primaryText)
            .background(isSelected ? category.color : AppColors.secondaryBackground)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? category.color : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Reference Item Card
struct ReferencePropertyCard: View {
    let item: ReferenceProperty
    let onTap: () -> Void
    
    private var categoryEnum: EquipmentCategory {
        guard let categoryString = item.category else { return .other }
        return EquipmentCategory.allCases.first { $0.rawValue.lowercased() == categoryString.lowercased() } ?? .other
    }
    
    var body: some View {
        Button(action: onTap) {
            WebAlignedCard {
                HStack(spacing: 16) {
                    // Category Icon
                    ZStack {
                        Rectangle()
                            .fill(categoryEnum.color.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .cornerRadius(0)
                        
                        Image(systemName: categoryEnum.icon)
                            .font(.system(size: 18))
                            .foregroundColor(categoryEnum.color)
                    }
                    
                    // Item Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.primaryText)
                            .lineLimit(1)
                        
                        HStack(spacing: 12) {
                            Label(item.nsn, systemImage: "number")
                                .font(AppFonts.mono)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        if let description = item.description {
                            Text(description)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Price (if available)
                    if let price = item.unitPrice {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatPrice(price))
                                .font(AppFonts.bodyBold)
                                .foregroundColor(AppColors.primaryText)
                            
                            if let unitOfIssue = item.unitOfIssue {
                                Text(unitOfIssue)
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.tertiaryText)
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
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$0"
    }
}

// MARK: - Reference Item Detail Sheet
struct ReferencePropertyDetailSheet: View {
    let item: ReferenceProperty
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddToInventory = false
    
    private var categoryEnum: EquipmentCategory {
        guard let categoryString = item.category else { return .other }
        return EquipmentCategory.allCases.first { $0.rawValue.lowercased() == categoryString.lowercased() } ?? .other
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Card
                    WebAlignedCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                ZStack {
                                    Rectangle()
                                        .fill(categoryEnum.color.opacity(0.15))
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(0)
                                    
                                    Image(systemName: categoryEnum.icon)
                                        .font(.title)
                                        .foregroundColor(categoryEnum.color)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    if let category = item.category {
                                        Text(category.uppercased())
                                            .font(AppFonts.caption)
                                            .foregroundColor(categoryEnum.color)
                                            .kerning(0.8)
                                    }
                                    
                                    if let price = item.unitPrice {
                                        Text(formatPrice(price))
                                            .font(AppFonts.title)
                                            .foregroundColor(AppColors.primaryText)
                                    }
                                }
                            }
                            
                            Text(item.name)
                                .font(AppFonts.headline)
                                .foregroundColor(AppColors.primaryText)
                            
                            if let description = item.description {
                                Text(description)
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                        .padding()
                    }
                    
                    // Identification Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Identification")
                        
                        WebAlignedCard {
                            VStack(spacing: 0) {
                                DetailRow(label: "NSN", value: item.nsn, isMonospaced: true)
                                
                                if let manufacturer = item.manufacturer {
                                    Divider().background(AppColors.border)
                                    DetailRow(label: "Manufacturer", value: manufacturer)
                                }
                                
                                if let unitOfIssue = item.unitOfIssue {
                                    Divider().background(AppColors.border)
                                    DetailRow(label: "Unit of Issue", value: unitOfIssue)
                                }
                            }
                        }
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: {
                            showingAddToInventory = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add to Inventory")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primary)
                        
                        Button(action: {
                            // TODO: Copy NSN to clipboard
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy NSN")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.secondary)
                    }
                }
                .padding()
            }
            .background(AppColors.appBackground)
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
        }
        .sheet(isPresented: $showingAddToInventory) {
            // TODO: Show create property form with pre-filled data
            Text("Add to Inventory - Coming Soon")
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$0"
    }
}

// MARK: - Detail Row Component
struct DetailRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(isMonospaced ? AppFonts.mono : AppFonts.bodyBold)
                .foregroundColor(AppColors.primaryText)
        }
        .padding()
    }
}

// MARK: - Preview
struct ReferenceDatabaseBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ReferenceDatabaseBrowserView()
        }
        .preferredColorScheme(.dark)
    }
} 