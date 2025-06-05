//
//  MinimalSearchView.swift
//  HandReceipt
//
//  8VC-inspired search interface with minimal styling
//

import SwiftUI
import Combine

// MARK: - Search View
struct MinimalSearchView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel: SearchViewModel
    @FocusState private var isSearchFieldFocused: Bool
    
    init(isPresented: Binding<Bool>, apiService: APIServiceProtocol = APIService()) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: SearchViewModel(apiService: apiService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            searchHeader
            
            // Content with proper layout
            ZStack {
                Color.clear // Invisible background to maintain consistent layout
                
                if viewModel.searchText.isEmpty && viewModel.recentSearches.isEmpty {
                    // Empty state
                    emptySearchState
                } else if viewModel.searchText.isEmpty {
                    // Recent searches
                    VStack {
                        recentSearchesView
                        Spacer()
                    }
                } else if viewModel.isSearching {
                    // Loading state
                    searchLoadingState
                } else {
                    // Search results
                    searchResultsView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppColors.appBackground)
        .ignoresSafeArea(.keyboard) // Better keyboard handling
        .onAppear {
            // Slight delay to ensure view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
    }
    
    // MARK: - Search Header
    private var searchHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Search field container
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(AppColors.tertiaryText)
                    
                    TextField("Search...", text: $viewModel.searchText)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            viewModel.performSearch()
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: { 
                            viewModel.searchText = ""
                            viewModel.results = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(AppColors.tertiaryText)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColors.tertiaryBackground)
                .cornerRadius(8)
                
                // Cancel button
                Button("Cancel") {
                    isPresented = false
                }
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // Filter pills - only show when searching
            if !viewModel.searchText.isEmpty && !viewModel.results.isEmpty {
                filterPillsView
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            
            Divider()
                .background(AppColors.divider)
        }
        .background(AppColors.appBackground)
        .animation(.easeInOut(duration: 0.2), value: viewModel.searchText.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: viewModel.results.isEmpty)
    }
    
    // MARK: - Filter Pills
    private var filterPillsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SearchFilter.allCases) { filter in
                    SearchFilterPill(
                        filter: filter,
                        count: viewModel.resultCount(for: filter),
                        isSelected: viewModel.selectedFilter == filter,
                        action: { viewModel.selectedFilter = filter }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Empty Search State
    private var emptySearchState: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Spacer for top padding
                Color.clear.frame(height: 40)
                
                // Geometric pattern - smaller and more subtle
                GeometricSearchPattern()
                    .frame(width: 80, height: 80)
                    .opacity(0.05)
                
                VStack(spacing: 16) {
                    Text("SEARCH")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                        .kerning(AppFonts.ultraWideKerning)
                    
                    Text("Find properties, people, or transfers")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Quick search suggestions
                VStack(alignment: .leading, spacing: 16) {
                    Text("QUICK SEARCHES")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                        .kerning(AppFonts.ultraWideKerning)
                    
                    VStack(spacing: 12) {
                        QuickSearchItem(icon: "shippingbox", text: "Active Properties", action: {
                            viewModel.searchText = "active"
                            viewModel.performSearch()
                        })
                        
                        QuickSearchItem(icon: "arrow.left.arrow.right", text: "Recent Transfers", action: {
                            viewModel.searchText = "transfers"
                            viewModel.performSearch()
                        })
                        
                        QuickSearchItem(icon: "wrench", text: "Maintenance Due", action: {
                            viewModel.searchText = "maintenance"
                            viewModel.performSearch()
                        })
                        
                        QuickSearchItem(icon: "person.2", text: "My Team", action: {
                            viewModel.searchText = "team"
                            viewModel.performSearch()
                        })
                    }
                }
                .padding(.horizontal, 24)
                
                // Bottom spacing
                Color.clear.frame(height: 60)
            }
        }
    }
    
    // MARK: - Recent Searches
    private var recentSearchesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("RECENT")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                        .kerning(AppFonts.ultraWideKerning)
                    
                    Spacer()
                    
                    if !viewModel.recentSearches.isEmpty {
                        Button("Clear") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.clearRecentSearches()
                            }
                        }
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.accent)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                // Recent items
                VStack(spacing: 0) {
                    ForEach(viewModel.recentSearches) { recent in
                        RecentSearchRow(
                            search: recent,
                            onTap: {
                                viewModel.searchText = recent.query
                                viewModel.performSearch()
                            },
                            onRemove: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.removeRecentSearch(recent)
                                }
                            }
                        )
                        
                        if recent.id != viewModel.recentSearches.last?.id {
                            Divider()
                                .background(AppColors.divider)
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Loading State
    private var searchLoadingState: some View {
        VStack {
            // Small top padding
            Color.clear.frame(height: 60)
            
            VStack(spacing: 20) {
                // Custom geometric loader instead of standard ProgressView
                SearchGeometricLoader()
                    .frame(width: 40, height: 40)
                
                Text("SEARCHING...")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .kerning(AppFonts.wideKerning)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Search Results
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                // Results summary
                HStack {
                    Text("\(viewModel.totalResults) results for \"\(viewModel.searchText)\"")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                
                // Grouped results
                ForEach(viewModel.groupedResults) { group in
                    Section {
                        VStack(spacing: 0) {
                            ForEach(group.results) { result in
                                SearchResultRow(
                                    result: result,
                                    searchText: viewModel.searchText,
                                    onTap: {
                                        handleResultTap(result)
                                    }
                                )
                                
                                if result.id != group.results.last?.id {
                                    Divider()
                                        .background(AppColors.divider)
                                        .padding(.leading, 72)
                                }
                            }
                        }
                    } header: {
                        SearchResultSectionHeader(
                            title: group.category.title,
                            count: group.results.count
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    private func handleResultTap(_ result: SearchResult) {
        viewModel.addToRecentSearches(result)
        
        // Navigate based on result type
        switch result.type {
        case .property:
            // Navigate to property detail
            break
        case .person:
            // Navigate to person profile
            break
        case .transfer:
            // Navigate to transfer detail
            break
        case .document:
            // Open document
            break
        }
        
        isPresented = false
    }
}

// MARK: - Supporting Components

struct SearchFilterPill: View {
    let filter: SearchFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(filter.title.uppercased())
                    .font(AppFonts.caption)
                    .kerning(AppFonts.wideKerning)
                
                if count > 0 {
                    Text("\(count)")
                        .font(AppFonts.monoCaption)
                }
            }
            .foregroundColor(isSelected ? AppColors.primaryText : AppColors.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppColors.tertiaryBackground : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickSearchItem: View {
    let icon: String
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(AppColors.secondaryText)
                    .frame(width: 24)
                
                Text(text)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Image(systemName: "arrow.up.backward")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppColors.secondaryBackground)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentSearchRow: View {
    let search: RecentSearch
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(AppColors.tertiaryText)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(search.query)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                    
                    if let subtitle = search.subtitle {
                        Text(subtitle)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(AppColors.tertiaryText)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SearchResultSectionHeader: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
                .kerning(AppFonts.ultraWideKerning)
            
            Text("(\(count))")
                .font(AppFonts.monoCaption)
                .foregroundColor(AppColors.tertiaryText)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(AppColors.appBackground.opacity(0.95))
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    let searchText: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Circle()
                    .fill(result.type.backgroundColor)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: result.type.icon)
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(result.type.foregroundColor)
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HighlightedText(
                        text: result.title,
                        highlight: searchText,
                        font: AppFonts.bodyMedium,
                        color: AppColors.primaryText,
                        highlightColor: AppColors.accent
                    )
                    
                    if let subtitle = result.subtitle {
                        HighlightedText(
                            text: subtitle,
                            highlight: searchText,
                            font: AppFonts.caption,
                            color: AppColors.secondaryText,
                            highlightColor: AppColors.accent
                        )
                    }
                    
                    // Metadata
                    HStack(spacing: 8) {
                        ForEach(result.metadata) { meta in
                            HStack(spacing: 4) {
                                Image(systemName: meta.icon)
                                    .font(.system(size: 10, weight: .light))
                                
                                Text(meta.value)
                                    .font(AppFonts.monoCaption)
                            }
                            .foregroundColor(AppColors.tertiaryText)
                            
                            if meta.id != result.metadata.last?.id {
                                Circle()
                                    .fill(AppColors.tertiaryText)
                                    .frame(width: 2, height: 2)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(AppColors.appBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Highlighted Text
struct HighlightedText: View {
    let text: String
    let highlight: String
    let font: Font
    let color: Color
    let highlightColor: Color
    
    var body: some View {
        if highlight.isEmpty {
            Text(text)
                .font(font)
                .foregroundColor(color)
        } else {
            highlightedTextView
        }
    }
    
    @ViewBuilder
    private var highlightedTextView: some View {
        let parts = splitTextForHighlighting()
        
        if parts.count <= 1 {
            Text(text)
                .font(font)
                .foregroundColor(color)
        } else {
            parts.reduce(Text("")) { result, part in
                if part.isHighlighted {
                    return result + Text(part.text)
                        .font(font.weight(.semibold))
                        .foregroundColor(highlightColor)
                } else {
                    return result + Text(part.text)
                        .font(font)
                        .foregroundColor(color)
                }
            }
        }
    }
    
    private func splitTextForHighlighting() -> [TextPart] {
        guard !highlight.isEmpty else {
            return [TextPart(text: text, isHighlighted: false)]
        }
        
        var parts: [TextPart] = []
        
        // Find first occurrence case-insensitively
        if let range = text.range(of: highlight, options: .caseInsensitive) {
            let beforeHighlight = String(text[..<range.lowerBound])
            let highlightText = String(text[range])
            let afterHighlight = String(text[range.upperBound...])
            
            if !beforeHighlight.isEmpty {
                parts.append(TextPart(text: beforeHighlight, isHighlighted: false))
            }
            
            parts.append(TextPart(text: highlightText, isHighlighted: true))
            
            if !afterHighlight.isEmpty {
                parts.append(TextPart(text: afterHighlight, isHighlighted: false))
            }
        } else {
            parts.append(TextPart(text: text, isHighlighted: false))
        }
        
        return parts
    }
    
    private struct TextPart {
        let text: String
        let isHighlighted: Bool
    }
}

// MARK: - Geometric Search Pattern
struct GeometricSearchPattern: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let size = min(geometry.size.width, geometry.size.height)
                
                // Magnifying glass circle
                path.addEllipse(in: CGRect(
                    x: center.x - size * 0.35,
                    y: center.y - size * 0.35,
                    width: size * 0.7,
                    height: size * 0.7
                ))
                
                // Handle
                path.move(to: CGPoint(
                    x: center.x + size * 0.25,
                    y: center.y + size * 0.25
                ))
                path.addLine(to: CGPoint(
                    x: center.x + size * 0.45,
                    y: center.y + size * 0.45
                ))
                
                // Inner geometric pattern
                let innerSize = size * 0.4
                let vertices = 6
                for i in 0..<vertices {
                    let angle = Double(i) * (2.0 * .pi / Double(vertices)) - .pi / 2
                    let x = center.x + innerSize * cos(angle) * 0.5
                    let y = center.y + innerSize * sin(angle) * 0.5
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.closeSubpath()
            }
            .stroke(AppColors.primaryText, lineWidth: 1)
        }
    }
}

// MARK: - Models

enum SearchFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case properties = "Properties"
    case people = "People"
    case transfers = "Transfers"
    case documents = "Documents"
    
    var id: String { rawValue }
    
    var title: String { rawValue }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let type: ResultType
    let title: String
    let subtitle: String?
    let metadata: [Metadata]
    let relevanceScore: Double
    
    enum ResultType {
        case property
        case person
        case transfer
        case document
        
        var icon: String {
            switch self {
            case .property: return "shippingbox"
            case .person: return "person"
            case .transfer: return "arrow.left.arrow.right"
            case .document: return "doc"
            }
        }
        
        var backgroundColor: Color {
            AppColors.tertiaryBackground
        }
        
        var foregroundColor: Color {
            AppColors.secondaryText
        }
    }
    
    struct Metadata: Identifiable {
        let id = UUID()
        let icon: String
        let value: String
    }
}

struct RecentSearch: Identifiable {
    let id = UUID()
    let query: String
    let subtitle: String?
    let date: Date
}

struct RecentSearchData: Codable {
    let query: String
    let subtitle: String?
    let date: Date
}

struct SearchResultGroup: Identifiable {
    let id = UUID()
    let category: SearchFilter
    let results: [SearchResult]
}

// MARK: - View Model
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedFilter: SearchFilter = .all
    @Published var isSearching = false
    @Published var results: [SearchResult] = []
    @Published var recentSearches: [RecentSearch] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
        setupSearchDebounce()
        loadRecentSearches()
    }
    
    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self = self else { return }
                
                if text.isEmpty {
                    // Clear results immediately when text is cleared
                    self.results = []
                    self.isSearching = false
                } else if text.count >= 2 {
                    // Only search if we have at least 2 characters
                    self.performSearch()
                }
            }
            .store(in: &cancellables)
    }
    
    var totalResults: Int {
        results.count
    }
    
    var groupedResults: [SearchResultGroup] {
        let filtered = selectedFilter == .all ? results : results.filter { matchesFilter($0, filter: selectedFilter) }
        
        let grouped = Dictionary(grouping: filtered) { result -> SearchFilter in
            switch result.type {
            case .property: return .properties
            case .person: return .people
            case .transfer: return .transfers
            case .document: return .documents
            }
        }
        
        return grouped.map { SearchResultGroup(category: $0.key, results: $0.value) }
            .sorted { $0.category.rawValue < $1.category.rawValue }
    }
    
    func resultCount(for filter: SearchFilter) -> Int {
        guard filter != .all else { return results.count }
        return results.filter { matchesFilter($0, filter: filter) }.count
    }
    
    func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        
        Task {
            do {
                let searchResults = try await performUnifiedSearch(query: searchText)
                
                await MainActor.run {
                    self.results = searchResults
                    self.isSearching = false
                    // Add to recent searches after successful search
                    self.addSearchToRecentSearches()
                }
            } catch {
                await MainActor.run {
                    debugPrint("Search error: \(error)")
                    self.results = []
                    self.isSearching = false
                }
            }
        }
    }
    
    func addToRecentSearches(_ result: SearchResult) {
        let recent = RecentSearch(
            query: result.title,
            subtitle: result.subtitle,
            date: Date()
        )
        
        recentSearches.insert(recent, at: 0)
        if recentSearches.count > 10 {
            recentSearches.removeLast()
        }
        
        saveRecentSearches()
    }
    
    func addSearchToRecentSearches() {
        guard !searchText.isEmpty else { return }
        
        // Remove any existing search with the same query
        recentSearches.removeAll { $0.query.lowercased() == searchText.lowercased() }
        
        let recent = RecentSearch(
            query: searchText,
            subtitle: "\(totalResults) result\(totalResults == 1 ? "" : "s")",
            date: Date()
        )
        
        recentSearches.insert(recent, at: 0)
        if recentSearches.count > 10 {
            recentSearches.removeLast()
        }
        
        saveRecentSearches()
    }
    
    func removeRecentSearch(_ search: RecentSearch) {
        recentSearches.removeAll { $0.id == search.id }
        saveRecentSearches()
    }
    
    func clearRecentSearches() {
        recentSearches.removeAll()
        saveRecentSearches()
    }
    
    private func matchesFilter(_ result: SearchResult, filter: SearchFilter) -> Bool {
        switch (result.type, filter) {
        case (_, .all): return true
        case (.property, .properties): return true
        case (.person, .people): return true
        case (.transfer, .transfers): return true
        case (.document, .documents): return true
        default: return false
        }
    }
    
    private func loadRecentSearches() {
        if let data = UserDefaults.standard.data(forKey: "RecentSearches"),
           let decoded = try? JSONDecoder().decode([RecentSearchData].self, from: data) {
            recentSearches = decoded.map { data in
                RecentSearch(
                    query: data.query,
                    subtitle: data.subtitle,
                    date: data.date
                )
            }
        }
    }
    
    private func saveRecentSearches() {
        let recentSearchData = recentSearches.map { search in
            RecentSearchData(
                query: search.query,
                subtitle: search.subtitle,
                date: search.date
            )
        }
        
        if let encoded = try? JSONEncoder().encode(recentSearchData) {
            UserDefaults.standard.set(encoded, forKey: "RecentSearches")
        }
    }
    
    // MARK: - Unified Search Implementation
    
    private func performUnifiedSearch(query: String) async throws -> [SearchResult] {
        var allResults: [SearchResult] = []
        
        // Perform parallel searches across different endpoints
        async let propertiesTask = searchProperties(query: query)
        async let usersTask = searchUsers(query: query)
        async let transfersTask = searchTransfers(query: query)
        async let nsnTask = searchNSNItems(query: query)
        
        // Wait for all searches to complete
        let (properties, users, transfers, nsnItems) = await (
            try? propertiesTask,
            try? usersTask,
            try? transfersTask,
            try? nsnTask
        )
        
        // Add results from each search
        if let properties = properties {
            allResults.append(contentsOf: properties)
        }
        
        if let users = users {
            allResults.append(contentsOf: users)
        }
        
        if let transfers = transfers {
            allResults.append(contentsOf: transfers)
        }
        
        if let nsnItems = nsnItems {
            allResults.append(contentsOf: nsnItems)
        }
        
        // Sort by relevance score (highest first)
        return allResults.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    // MARK: - Individual Search Methods
    
    private func searchProperties(query: String) async throws -> [SearchResult] {
        let properties = try await apiService.getMyProperties()
        
        return properties.compactMap { property -> SearchResult? in
            let title = property.name
            let subtitle = "SN: \(property.serialNumber)"
            
            // Check if query matches property data
            let queryLower = query.lowercased()
            let titleMatch = title.lowercased().contains(queryLower)
            let serialMatch = property.serialNumber.lowercased().contains(queryLower)
            let descriptionMatch = (property.description ?? "").lowercased().contains(queryLower)
            let nsnMatch = (property.nsn ?? "").lowercased().contains(queryLower)
            
            // Return nil if no match (this is correct for compactMap)
            guard titleMatch || serialMatch || descriptionMatch || nsnMatch else {
                return nil
            }
            
            // Calculate relevance score
            var relevanceScore = 0.0
            if titleMatch { relevanceScore += 0.4 }
            if serialMatch { relevanceScore += 0.3 }
            if nsnMatch { relevanceScore += 0.2 }
            if descriptionMatch { relevanceScore += 0.1 }
            
            return SearchResult(
                type: .property,
                title: title,
                subtitle: subtitle,
                metadata: [
                    .init(icon: "person", value: property.assignedToUserId != nil ? "User #\(property.assignedToUserId!)" : "Unassigned"),
                    .init(icon: "circle", value: (property.currentStatus ?? "Unknown").capitalized)
                ],
                relevanceScore: relevanceScore
            )
        }
    }
    
    private func searchUsers(query: String) async throws -> [SearchResult] {
        let users = try await apiService.searchUsers(query: query)
        
        return users.map { user in
            SearchResult(
                type: .person,
                title: "\(user.rank ?? "") \(user.name)",
                                        subtitle: user.email ?? "No email",
                metadata: [
                                          .init(icon: "envelope", value: user.email ?? "No email"),
                    .init(icon: "building", value: user.unit ?? "Unknown Unit")
                ],
                relevanceScore: 0.8 // Fixed relevance for user results
            )
        }
    }
    
    private func searchTransfers(query: String) async throws -> [SearchResult] {
        let transfers = try await apiService.fetchTransfers(status: nil, direction: nil)
        
        return transfers.compactMap { transfer -> SearchResult? in
            let queryLower = query.lowercased()
            
            // Simple matching on transfer ID or status
            let statusMatch = transfer.status.lowercased().contains(queryLower)
            let idMatch = String(transfer.id).contains(queryLower)
            
            guard statusMatch || idMatch else {
                return nil
            }
            
            let title = "Transfer #\(transfer.id)"
            let subtitle = "Status: \(transfer.status.capitalized)"
            
            return SearchResult(
                type: .transfer,
                title: title,
                subtitle: subtitle,
                metadata: [
                    .init(icon: "calendar", value: RelativeDateFormatter.shared.string(from: transfer.requestDate)),
                    .init(icon: "arrow.right", value: "Property #\(transfer.propertyId)")
                ],
                relevanceScore: 0.6
            )
        }
    }
    
    private func searchNSNItems(query: String) async throws -> [SearchResult] {
        let response = try await apiService.universalSearchNSN(query: query, limit: 10)
        
        return response.data.map { nsnItem in
            SearchResult(
                type: .document,
                title: nsnItem.nomenclature,
                subtitle: "NSN: \(nsnItem.nsn)",
                metadata: [
                    .init(icon: "doc", value: nsnItem.fsc ?? "Unknown FSC"),
                    .init(icon: "building.2", value: nsnItem.manufacturer ?? "Unknown Mfg")
                ],
                relevanceScore: 0.7
            )
        }
    }
}

// MARK: - Search Geometric Loader
struct SearchGeometricLoader: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Outer square
            Rectangle()
                .stroke(AppColors.tertiaryText.opacity(0.3), lineWidth: 1)
                .rotationEffect(.degrees(rotation))
            
            // Inner square
            Rectangle()
                .stroke(AppColors.primaryText.opacity(0.8), lineWidth: 1)
                .scaleEffect(0.7)
                .rotationEffect(.degrees(-rotation * 1.5))
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Preview
struct MinimalSearchView_Previews: PreviewProvider {
    static var previews: some View {
        MinimalSearchView(isPresented: .constant(true))
    }
} 