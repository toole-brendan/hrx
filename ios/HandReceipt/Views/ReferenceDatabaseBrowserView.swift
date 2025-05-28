import SwiftUI

// REMOVE Placeholder Data Models and ViewModel - they are now in separate files
// struct ReferenceCategory: Identifiable { ... } // REMOVED
// struct ReferenceItem: Identifiable { ... } // REMOVED
// @MainActor class ReferenceDBViewModel: ObservableObject { ... } // REMOVED

struct ReferenceDatabaseBrowserView: View {
    @StateObject private var viewModel = ReferenceDBViewModel()
    
    // State to control sheet presentation for Manual SN Entry
    @State private var showingManualSNEntry = false

    var body: some View {
        // No need for explicit NavigationView here if it's already in a Tab
        // The NavigationView is added in AuthenticatedTabView
        // NavigationView {
            VStack {
                // Search Bar (Optional - can be added later)
                // TextField("Search...", text: $viewModel.searchQuery)
                //    .textFieldStyle(.industrial) // Use themed text field style
                //    .padding(.horizontal)

                if viewModel.isLoading {
                    ProgressView {
                        Text("Loading Items...")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.primaryText)
                    }
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.appBackground.ignoresSafeArea())
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40) // Slightly smaller icon
                            .foregroundColor(AppColors.destructive) // Use destructive color
                        Text("Error Loading Data")
                            .font(AppFonts.headline)
                            .foregroundColor(AppColors.primaryText)
                            .padding(.top, 5)
                        Text(errorMessage)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            viewModel.loadReferenceItems()
                        }
                        .buttonStyle(.primary) // Use themed button style
                        .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(AppColors.appBackground.ignoresSafeArea())
                } else {
                    List {
                        if viewModel.referenceItems.isEmpty {
                            Text("No reference items found.")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .listRowBackground(AppColors.appBackground) // Match background
                        } else {
                            ForEach(viewModel.referenceItems) { item in
                                NavigationLink {
                                     ReferenceItemDetailView(itemId: item.id.uuidString)
                                } label: {
                                     ReferenceItemRow(item: item)
                                }
                                // Apply row background color
                                .listRowBackground(AppColors.secondaryBackground)
                                .listRowSeparatorTint(AppColors.secondaryText.opacity(0.3))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(AppColors.appBackground.ignoresSafeArea()) // Set overall background
                    .refreshable {
                        viewModel.loadReferenceItems()
                    }
                }
                 // Removed Spacer() - List should fill available space
            }
            .navigationTitle("Reference Database") // This is handled by the NavigationView in AuthenticatedTabView
            .toolbar { 
                 ToolbarItem(placement: .navigationBarTrailing) {
                     Button {
                         showingManualSNEntry = true 
                     } label: {
                         // Label should pick up global tint color
                         Label("Enter SN", systemImage: "plus.magnifyingglass")
                             // .font(AppFonts.body) // Font applied via global appearance
                     }
                 }
            }
            .sheet(isPresented: $showingManualSNEntry) { 
                 NavigationView { 
                     ManualSNEntryView(
                        onItemConfirmed: { property in
                             print("Item confirmed from sheet: \(property.serialNumber)")
                            showingManualSNEntry = false
                        }
                     )
                     // Apply theme colors to the sheet's nav bar explicitly if needed
                     // .navigationBarTitleDisplayMode(.inline)
                     // .toolbarBackground(AppColors.secondaryBackground, for: .navigationBar)
                     // .toolbarBackground(.visible, for: .navigationBar)
                 }
                 .accentColor(AppColors.accent)
            }
            .onAppear {
                if viewModel.referenceItems.isEmpty {
                    viewModel.loadReferenceItems()
                }
            }
        // } // End NavigationView - Removed
    }
}

// Row View for the Reference Item List
struct ReferenceItemRow: View {
    let item: ReferenceItem

    var body: some View {
        HStack(spacing: 12) { // Added spacing
             AsyncImage(url: URL(string: item.imageUrl ?? "")) { phase in
                 if let image = phase.image {
                     image.resizable()
                          .aspectRatio(contentMode: .fill)
                          .frame(width: 44, height: 44) // Slightly larger image
                          .clipShape(RoundedRectangle(cornerRadius: 4))
                 } else if phase.error != nil {
                     Image(systemName: "photo.fill.on.rectangle.fill") // More indicative error placeholder
                          .font(.title3)
                          .foregroundColor(AppColors.secondaryText)
                          .frame(width: 44, height: 44, alignment: .center)
                          .background(AppColors.secondaryBackground.opacity(0.5))
                          .cornerRadius(4)
                 } else {
                     Image(systemName: "photo") // Loading placeholder
                         .font(.title3)
                         .foregroundColor(AppColors.secondaryText)
                         .frame(width: 44, height: 44, alignment: .center)
                         .background(AppColors.secondaryBackground.opacity(0.5))
                         .cornerRadius(4)
                 }
             }

            VStack(alignment: .leading) {
                Text(item.itemName)
                    .font(AppFonts.bodyBold) // Use bold body font
                    .foregroundColor(AppColors.primaryText)
                Text("NSN: \(item.nsn)")
                    .font(AppFonts.caption) // Use caption font
                    .foregroundColor(AppColors.secondaryText)
            }
            Spacer() // Push content to the left
        }
        .padding(.vertical, 6) // Add some vertical padding to the row
    }
}

// Keep Placeholder Detail View (ensure it uses the correct ReferenceItem model properties) - DEFINITION REMOVED
// struct ReferenceItemDetailView: View {
//     // ... Contents removed ... 
// }

struct ReferenceDatabaseBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        // Wrap preview in NavigationView to see title/toolbar
        NavigationView {
             ReferenceDatabaseBrowserView()
        }
        .preferredColorScheme(.dark) // Ensure preview uses dark scheme
        .previewDisplayName("Browser View - Dark")
    }
}

// Add a MockAPIService for Previews (optional but recommended)
/*
class MockAPIService: APIServiceProtocol {
    var mockItems: [ReferenceItem]?
    var shouldThrowError = false
    var simulatedDelay: TimeInterval = 0.5 // Simulate network delay

    func fetchReferenceItems() async throws -> [ReferenceItem] {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))

        if shouldThrowError {
            throw APIService.APIError.serverError(statusCode: 500)
        }
        return mockItems ?? []
    }
}
*/ 