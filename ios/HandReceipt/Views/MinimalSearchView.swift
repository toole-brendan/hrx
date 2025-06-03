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
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            searchHeader
            
            // Content
            if viewModel.searchText.isEmpty && viewModel.recentSearches.isEmpty {
                // Empty state
                emptySearchState
            } else if viewModel.searchText.isEmpty {
                // Recent searches
                recentSearchesView
            } else if viewModel.isSearching {
                // Loading state
                searchLoadingState
            } else {
                // Search results
                searchResultsView
            }
        }
        .background(AppColors.appBackground)
        .onAppear {
            isSearchFieldFocused = true
        }
    }
    
    // MARK: - Search Header
    private var searchHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Search field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(AppColors.tertiaryText)
                    
                    TextField("Search properties, people, or transfers", text: $viewModel.searchText)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            viewModel.performSearch()
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .light))
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
                .foregroundColor(AppColors.secondaryText)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .animation(.easeInOut(duration: 0.2), value: viewModel.searchText.isEmpty)
            
            // Filter pills
            if !viewModel.searchText.isEmpty {
                filterPillsView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider()
                .background(AppColors.divider)
        }
        .animation(.easeInOut(duration: 0.3), value: !viewModel.searchText.isEmpty)
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
        VStack(spacing: 32) {
            Spacer()
            
            // Geometric pattern
            GeometricSearchPattern()
                .frame(width: 120, height: 120)
                .opacity(0.1)
            
            VStack(spacing: 16) {
                Text("SEARCH HANDRECEIPT")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                    .kerning(AppFonts.wideKerning)
                
                Text("Find properties, people, transfers, and more")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Quick search suggestions
            VStack(alignment: .leading, spacing: 16) {
                Text("TRY SEARCHING FOR")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.tertiaryText)
                    .kerning(AppFonts.ultraWideKerning)
                
                VStack(spacing: 12) {
                    QuickSearchItem(icon: "shippingbox", text: "M4 Carbine", action: {
                        viewModel.searchText = "M4 Carbine"
                    })
                    
                    QuickSearchItem(icon: "person", text: "Recent transfers", action: {
                        viewModel.searchText = "transfers"
                    })
                    
                    QuickSearchItem(icon: "wrench", text: "Maintenance due", action: {
                        viewModel.searchText = "maintenance"
                    })
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Recent Searches
    private var recentSearchesView: some View {
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
                        viewModel.clearRecentSearches()
                    }
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
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
                            viewModel.removeRecentSearch(recent)
                        }
                    )
                    
                    if recent.id != viewModel.recentSearches.last?.id {
                        Divider()
                            .background(AppColors.divider)
                            .padding(.leading, 56)
                    }
                }
            }
        }
    }
    
    // MARK: - Loading State
    private var searchLoadingState: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                    .scaleEffect(0.8)
                
                Text("SEARCHING")
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
    
    init() {
        // Debounce search
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                if !text.isEmpty {
                    self?.performSearch()
                }
            }
            .store(in: &cancellables)
        
        loadRecentSearches()
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
        isSearching = true
        
        // Simulate search
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.generateMockResults()
            self?.isSearching = false
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
        // Load from UserDefaults or Core Data
        recentSearches = [
            RecentSearch(query: "M4 Carbine", subtitle: "3 results", date: Date().addingTimeInterval(-3600)),
            RecentSearch(query: "maintenance", subtitle: "12 results", date: Date().addingTimeInterval(-7200))
        ]
    }
    
    private func saveRecentSearches() {
        // Save to UserDefaults or Core Data
    }
    
    private func generateMockResults() {
        // Generate mock search results for demo
        results = [
            SearchResult(
                type: .property,
                title: "M4 Carbine",
                subtitle: "SN: M4-12345",
                metadata: [
                    .init(icon: "location", value: "Building A"),
                    .init(icon: "person", value: "CPT Smith")
                ],
                relevanceScore: 0.95
            ),
            SearchResult(
                type: .person,
                title: "CPT John Smith",
                subtitle: "Current holder of 12 items",
                metadata: [
                    .init(icon: "envelope", value: "john.smith@army.mil")
                ],
                relevanceScore: 0.85
            ),
            SearchResult(
                type: .transfer,
                title: "Transfer #T-2024-001",
                subtitle: "M4 Carbine to CPT Smith",
                metadata: [
                    .init(icon: "calendar", value: "2 days ago"),
                    .init(icon: "checkmark.circle", value: "Completed")
                ],
                relevanceScore: 0.75
            )
        ]
    }
}

// MARK: - Preview
struct MinimalSearchView_Previews: PreviewProvider {
    static var previews: some View {
        MinimalSearchView(isPresented: .constant(true))
    }
} 