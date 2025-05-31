import SwiftUI

// MARK: - Sensitive Items View
struct SensitiveItemsView: View {
    @State private var sensitiveItems: [Property] = []
    @State private var verificationStatus: [Int: VerificationStatus] = [:]
    @State private var isLoading = true
    @State private var loadingError: String?
    @State private var selectedFilter: SensitiveItemFilter = .all
    @State private var searchText = ""
    @State private var showingVerificationSheet = false
    @State private var selectedItemForVerification: Property?
    
    // Services
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    var filteredItems: [Property] {
        let filtered = sensitiveItems.filter { item in
            switch selectedFilter {
            case .all:
                return true
            case .verified:
                return verificationStatus[item.id]?.isVerified ?? false
            case .unverified:
                return !(verificationStatus[item.id]?.isVerified ?? false)
            case .overdue:
                return isVerificationOverdue(for: item)
            }
        }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { item in
                item.itemName.localizedCaseInsensitiveContains(searchText) ||
                item.serialNumber.localizedCaseInsensitiveContains(searchText) ||
                item.nsn.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var verificationStats: (verified: Int, total: Int, percentage: Int) {
        let verified = sensitiveItems.filter { verificationStatus[$0.id]?.isVerified ?? false }.count
        let total = sensitiveItems.count
        let percentage = total > 0 ? Int((Double(verified) / Double(total)) * 100) : 0
        return (verified, total, percentage)
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
            SensitiveItemsHeaderSection()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showingVerificationSheet) {
            if let item = selectedItemForVerification {
                VerificationSheet(
                    item: item,
                    onVerify: { notes in
                        verifyItem(item, notes: notes)
                    }
                )
            }
        }
        .task {
            await loadSensitiveItems()
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
            Text("Loading sensitive items...")
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
                
                Text("Error Loading Items")
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
            
            // Search and Filter
            searchAndFilterSection
            
            // Items List
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                itemsListSection
            }
            
            // Bottom spacer
            Spacer()
                .frame(height: 100)
        }
    }
    
    private var statsOverview: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Verification Status")
            
            WebAlignedCard {
                VStack(spacing: 20) {
                    // Progress Circle
                    ZStack {
                        Circle()
                            .stroke(AppColors.tertiaryBackground, lineWidth: 12)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(verificationStats.percentage) / 100)
                            .stroke(AppColors.success, lineWidth: 12)
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: verificationStats.percentage)
                        
                        VStack(spacing: 4) {
                            Text("\(verificationStats.percentage)%")
                                .font(AppFonts.largeTitle)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("VERIFIED")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .kerning(1.2)
                        }
                    }
                    
                    // Stats Grid
                    HStack(spacing: 40) {
                        VStack(spacing: 4) {
                            Text("\(verificationStats.verified)")
                                .font(AppFonts.title)
                                .foregroundColor(AppColors.success)
                            Text("Verified")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        VStack(spacing: 4) {
                            Text("\(verificationStats.total - verificationStats.verified)")
                                .font(AppFonts.title)
                                .foregroundColor(AppColors.warning)
                            Text("Unverified")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        VStack(spacing: 4) {
                            Text("\(verificationStats.total)")
                                .font(AppFonts.title)
                                .foregroundColor(AppColors.primaryText)
                            Text("Total")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
        }
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.secondaryText)
                
                TextField("Search by name, serial, or NSN...", text: $searchText)
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
                    ForEach(SensitiveItemFilter.allCases, id: \.self) { filter in
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
                Image(systemName: "shield.slash")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.tertiaryText)
                
                Text("No Items Found")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text("No sensitive items match your current filter.")
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
            SectionHeader(title: "Sensitive Items (\(filteredItems.count))")
            
            VStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    SensitiveItemCard(
                        item: item,
                        verificationStatus: verificationStatus[item.id],
                        onVerify: {
                            selectedItemForVerification = item
                            showingVerificationSheet = true
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadSensitiveItems() async {
        isLoading = true
        loadingError = nil
        
        do {
            let allProperties = try await apiService.getMyProperties()
            sensitiveItems = allProperties.filter { $0.isSensitive }
            
            // Load verification status for each item
            for item in sensitiveItems {
                // TODO: Load actual verification status from API
                // For now, mock the data
                let lastVerified = Date().addingTimeInterval(-Double.random(in: 0...7776000)) // 0-90 days ago
                let isVerified = Bool.random()
                verificationStatus[item.id] = VerificationStatus(
                    lastVerified: isVerified ? lastVerified : nil,
                    verifiedBy: isVerified ? "SGT Johnson" : nil,
                    notes: isVerified ? "Item present and accounted for" : nil
                )
            }
            
            isLoading = false
        } catch {
            loadingError = error.localizedDescription
            isLoading = false
        }
    }
    
    private func refreshData() async {
        await loadSensitiveItems()
    }
    
    private func verifyItem(_ item: Property, notes: String) {
        // TODO: Send verification to API
        verificationStatus[item.id] = VerificationStatus(
            lastVerified: Date(),
            verifiedBy: "Current User", // TODO: Get from auth
            notes: notes.isEmpty ? nil : notes
        )
        
        // Dismiss sheet
        showingVerificationSheet = false
        selectedItemForVerification = nil
    }
    
    private func isVerificationOverdue(for item: Property) -> Bool {
        guard let status = verificationStatus[item.id],
              let lastVerified = status.lastVerified else {
            return true // Never verified = overdue
        }
        
        let daysSinceVerification = Calendar.current.dateComponents([.day], from: lastVerified, to: Date()).day ?? 0
        return daysSinceVerification > 30 // Overdue if not verified in 30 days
    }
    
    private func getCountForFilter(_ filter: SensitiveItemFilter) -> Int {
        switch filter {
        case .all:
            return sensitiveItems.count
        case .verified:
            return sensitiveItems.filter { verificationStatus[$0.id]?.isVerified ?? false }.count
        case .unverified:
            return sensitiveItems.filter { !(verificationStatus[$0.id]?.isVerified ?? false) }.count
        case .overdue:
            return sensitiveItems.filter { isVerificationOverdue(for: $0) }.count
        }
    }
}

// MARK: - Supporting Types

enum SensitiveItemFilter: CaseIterable {
    case all, verified, unverified, overdue
    
    var title: String {
        switch self {
        case .all: return "All"
        case .verified: return "Verified"
        case .unverified: return "Unverified"
        case .overdue: return "Overdue"
        }
    }
}

struct VerificationStatus {
    let lastVerified: Date?
    let verifiedBy: String?
    let notes: String?
    
    var isVerified: Bool {
        return lastVerified != nil
    }
}

// MARK: - Header Section
struct SensitiveItemsHeaderSection: View {
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
                    
                    Text("SENSITIVE ITEMS")
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

// MARK: - Filter Pill Component
struct FilterPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(AppFonts.caption)
                
                Text("\(count)")
                    .font(AppFonts.captionBold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .white : AppColors.primaryText)
            .background(isSelected ? AppColors.accent : AppColors.secondaryBackground)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sensitive Item Card
struct SensitiveItemCard: View {
    let item: Property
    let verificationStatus: VerificationStatus?
    let onVerify: () -> Void
    
    private var statusColor: Color {
        guard let status = verificationStatus else { return AppColors.destructive }
        
        if let lastVerified = status.lastVerified {
            let daysSince = Calendar.current.dateComponents([.day], from: lastVerified, to: Date()).day ?? 0
            if daysSince <= 7 {
                return AppColors.success
            } else if daysSince <= 30 {
                return AppColors.warning
            }
        }
        return AppColors.destructive
    }
    
    private var statusText: String {
        guard let status = verificationStatus, let lastVerified = status.lastVerified else {
            return "Never Verified"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Verified \(formatter.localizedString(for: lastVerified, relativeTo: Date()))"
    }
    
    var body: some View {
        WebAlignedCard {
            VStack(spacing: 0) {
                // Main Content
                HStack(spacing: 16) {
                    // Status Indicator
                    Rectangle()
                        .fill(statusColor)
                        .frame(width: 4)
                    
                    // Item Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.itemName)
                            .font(AppFonts.headline)
                            .foregroundColor(AppColors.primaryText)
                        
                        HStack(spacing: 16) {
                            Label(item.serialNumber, systemImage: "number")
                                .font(AppFonts.mono)
                                .foregroundColor(AppColors.secondaryText)
                            
                            Label(item.nsn, systemImage: "barcode")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                        }
                        
                        HStack {
                            Text(statusText)
                                .font(AppFonts.caption)
                                .foregroundColor(statusColor)
                            
                            if let verifiedBy = verificationStatus?.verifiedBy {
                                Text("by \(verifiedBy)")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.tertiaryText)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Verify Button
                    Button(action: onVerify) {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.title2)
                                .foregroundColor(AppColors.accent)
                            
                            Text("VERIFY")
                                .font(AppFonts.caption2)
                                .foregroundColor(AppColors.accent)
                                .kerning(0.8)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                
                // Notes (if any)
                if let notes = verificationStatus?.notes, !notes.isEmpty {
                    Divider()
                        .background(AppColors.border)
                    
                    HStack {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundColor(AppColors.tertiaryText)
                        
                        Text(notes)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .lineLimit(2)
                        
                        Spacer()
                    }
                    .padding()
                    .background(AppColors.tertiaryBackground.opacity(0.5))
                }
            }
        }
    }
}

// MARK: - Verification Sheet
struct VerificationSheet: View {
    let item: Property
    let onVerify: (String) -> Void
    @State private var notes = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Item Info
                WebAlignedCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.itemName)
                            .font(AppFonts.headline)
                            .foregroundColor(AppColors.primaryText)
                        
                        HStack(spacing: 20) {
                            Label(item.serialNumber, systemImage: "number")
                                .font(AppFonts.mono)
                                .foregroundColor(AppColors.secondaryText)
                            
                            Label(item.nsn, systemImage: "barcode")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                        }
                    }
                    .padding()
                }
                
                // Verification Form
                VStack(alignment: .leading, spacing: 16) {
                    Text("VERIFICATION NOTES")
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
                        .frame(minHeight: 120)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.secondary)
                    
                    Button("Verify Item") {
                        onVerify(notes)
                    }
                    .buttonStyle(.primary)
                }
            }
            .padding()
            .background(AppColors.appBackground)
            .navigationTitle("Verify Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

// MARK: - Preview
struct SensitiveItemsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SensitiveItemsView()
        }
        .preferredColorScheme(.dark)
    }
} 