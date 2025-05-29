import SwiftUI

struct NSNSearchView: View {
    @Binding var searchQuery: String
    @Binding var searchResults: [NSNDetails]
    @Binding var isSearching: Bool
    let onSelect: (NSNDetails) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var debouncer = Debouncer(delay: 0.5)
    
    private let apiService = APIService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search by NSN, item name, or part number", text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: searchQuery) { newValue in
                            debouncer.debounce {
                                if !newValue.isEmpty {
                                    performSearch()
                                }
                            }
                        }
                    
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Results list
                if isSearching {
                    Spacer()
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer()
                } else if searchResults.isEmpty && !searchQuery.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No results found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try searching with different keywords")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Search NSN Database")
                            .font(.headline)
                        Text("Enter NSN, item name, or part number")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(searchResults, id: \.nsn) { item in
                        NSNSearchResultRow(item: item) {
                            onSelect(item)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("NSN Database")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        Task {
            do {
                let response = try await apiService.searchNSN(query: searchQuery, limit: 50)
                await MainActor.run {
                    searchResults = response.data
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                    // Show error alert
                    print("NSN search error: \(error)")
                }
            }
        }
    }
}

struct NSNSearchResultRow: View {
    let item: NSNDetails
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Item name
                Text(item.itemName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // NSN and LIN
                HStack {
                    Label(formatNSN(item.nsn), systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lin = item.lin {
                        Text("•")
                            .foregroundColor(.secondary)
                        Label(lin, systemImage: "tag")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Additional details
                HStack {
                    if let manufacturer = item.manufacturer {
                        Text(manufacturer)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let partNumber = item.partNumber {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("P/N: \(partNumber)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if let price = item.unitPrice {
                        Text("$\(String(format: "%.2f", price))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatNSN(_ nsn: String) -> String {
        let clean = nsn.replacingOccurrences(of: "-", with: "")
        guard clean.count == 13 else { return nsn }
        
        let part1 = clean.prefix(4)
        let part2 = clean.dropFirst(4).prefix(2)
        let part3 = clean.dropFirst(6).prefix(3)
        let part4 = clean.dropFirst(9)
        
        return "\(part1)-\(part2)-\(part3)-\(part4)"
    }
}

// Debouncer utility for search
class Debouncer: ObservableObject {
    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        
        workItem = DispatchWorkItem {
            action()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
} 