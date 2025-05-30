import SwiftUI

struct SensitiveItemsView: View {
    @State private var sensitiveItems: [Property] = []
    @State private var isLoading = true
    @State private var loadingError: String?
    @State private var searchText = ""
    @State private var showingVerificationSheet = false
    @State private var selectedItem: Property?
    
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    var filteredItems: [Property] {
        if searchText.isEmpty {
            return sensitiveItems
        }
        return sensitiveItems.filter { item in
            item.itemName.localizedCaseInsensitiveContains(searchText) ||
            item.serialNumber.localizedCaseInsensitiveContains(searchText) ||
            item.nsn.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var verificationStats: (verified: Int, total: Int) {
        let total = sensitiveItems.count
        // In a real app, you'd track verification status
        let verified = sensitiveItems.filter { _ in
            // Mock: randomly mark some as verified today
            Bool.random()
        }.count
        return (verified, total)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Stats Header
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    StatCard(
                        title: "Total Sensitive Items",
                        value: "\(sensitiveItems.count)",
                        icon: "shield.fill",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Verified Today",
                        value: "\(verificationStats.verified)/\(verificationStats.total)",
                        icon: "checkmark.shield.fill",
                        color: .green
                    )
                }
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.secondaryText)
                    
                    TextField("Search by name, serial, or NSN", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(AppFonts.body)
                }
                .padding(12)
                .background(AppColors.tertiaryBackground)
                .cornerRadius(8)
            }
            .padding()
            .background(AppColors.secondaryBackground)
            
            if isLoading {
                Spacer()
                ProgressView("Loading sensitive items...")
                    .padding()
                Spacer()
            } else if let error = loadingError {
                Spacer()
                ErrorView(message: error) {
                    Task { await loadData() }
                }
                .padding()
                Spacer()
            } else if filteredItems.isEmpty {
                Spacer()
                EmptyStateView()
                Spacer()
            } else {
                List {
                    ForEach(filteredItems) { item in
                        SensitiveItemRow(item: item) {
                            selectedItem = item
                            showingVerificationSheet = true
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(AppColors.appBackground)
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Sensitive Items")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Bulk verification action
                }) {
                    Text("Verify All")
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .sheet(isPresented: $showingVerificationSheet) {
            if let item = selectedItem {
                VerificationSheet(item: item) {
                    showingVerificationSheet = false
                    // Update verification status
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        loadingError = nil
        
        do {
            let allProperties = try await apiService.getMyProperties()
            sensitiveItems = allProperties.filter { $0.isSensitive }
            isLoading = false
        } catch {
            loadingError = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Components
struct SensitiveItemRow: View {
    let item: Property
    let onVerify: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.itemName)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                    
                    HStack(spacing: 12) {
                        Label(item.serialNumber, systemImage: "number")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        if let nsn = item.nsn {
                            Label(nsn, systemImage: "tag")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onVerify) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield")
                        Text("Verify")
                    }
                    .font(AppFonts.captionBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.accent)
                    .cornerRadius(6)
                }
            }
            
            if let location = item.location {
                HStack {
                    Image(systemName: "location")
                        .font(.caption)
                    Text(location)
                        .font(AppFonts.caption)
                }
                .foregroundColor(AppColors.tertiaryText)
            }
        }
        .padding(.vertical, 8)
    }
}

struct VerificationSheet: View {
    let item: Property
    let onComplete: () -> Void
    @State private var verificationNotes = ""
    @State private var photoTaken = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Item Details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Verify Sensitive Item")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primaryText)
                    
                    DetailRow(label: "Item", value: item.itemName)
                    DetailRow(label: "Serial Number", value: item.serialNumber)
                    DetailRow(label: "NSN", value: item.nsn)
                    if let location = item.location {
                        DetailRow(label: "Location", value: location)
                    }
                }
                .padding()
                .background(AppColors.secondaryBackground)
                .cornerRadius(12)
                
                // Verification Actions
                VStack(spacing: 16) {
                    Button(action: {
                        // Open camera
                        photoTaken = true
                    }) {
                        HStack {
                            Image(systemName: photoTaken ? "checkmark.circle.fill" : "camera")
                                .foregroundColor(photoTaken ? .green : AppColors.accent)
                            Text(photoTaken ? "Photo Captured" : "Take Photo")
                                .font(AppFonts.bodyBold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.tertiaryBackground)
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        TextEditor(text: $verificationNotes)
                            .font(AppFonts.body)
                            .padding(8)
                            .background(AppColors.tertiaryBackground)
                            .cornerRadius(8)
                            .frame(height: 100)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onComplete()
                    }
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.tertiaryBackground)
                    .cornerRadius(8)
                    
                    Button("Verify") {
                        // Submit verification
                        onComplete()
                    }
                    .font(AppFonts.bodyBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.accent)
                    .cornerRadius(8)
                }
                .padding()
            }
            .background(AppColors.appBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.slash")
                .font(.system(size: 60))
                .foregroundColor(AppColors.tertiaryText)
            
            Text("No Sensitive Items")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
            
            Text("You don't have any sensitive items assigned")
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
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