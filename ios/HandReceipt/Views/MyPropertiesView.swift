import SwiftUI

struct MyPropertiesView: View {
    @StateObject private var viewModel: MyPropertiesViewModel
    
    // TODO: Define navigation action for property detail
     // var navigateToPropertyDetail: (String) -> Void

    init(viewModel: MyPropertiesViewModel? = nil) {
        let vm = viewModel ?? MyPropertiesViewModel(apiService: APIService())
        self._viewModel = StateObject(wrappedValue: vm)
        // Configure list appearance if needed (might be handled globally or per-list)
        // configureListAppearance()
    }

    var body: some View {
        // Remove the redundant NavigationView wrapper
        // The NavigationView is provided by AuthenticatedTabView
        content
             // Apply navigation title directly to the content
            .navigationTitle("My Properties")
            // Background is handled within content's ZStack
    }

    @ViewBuilder
    private var content: some View {
        ZStack { 
            AppColors.appBackground.ignoresSafeArea() // Apply background to ZStack, ignore safe area

            switch viewModel.loadingState {
            case .idle, .loading:
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent)) // Use accent color
                    Text("Loading Properties...")
                        .font(AppFonts.body) // Use theme font
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .success(let properties):
                if properties.isEmpty {
                    // Pass themed colors/fonts into EmptyStateView if needed, or apply inside
                    EmptyPropertiesStateView { viewModel.loadProperties() }
                } else {
                    // Pass themed colors/fonts into PropertyList if needed, or apply inside
                    PropertyList(properties: properties, viewModel: viewModel)
                }

            case .error(let message):
                 // Pass themed colors/fonts into ErrorStateView if needed, or apply inside
                ErrorStateView(message: message) { viewModel.loadProperties() }
            }
        }
        // Ignore safe area on the ZStack level
        // .ignoresSafeArea() - Applied above
    }
    
    // Optional: Helper for specific list config if needed
    // private func configureListAppearance() {
    //     List {}.listStyle(.plain) // example
    // }
}

// MARK: - Subviews

struct PropertyList: View {
    let properties: [Property]
    @ObservedObject var viewModel: MyPropertiesViewModel

    init(properties: [Property], viewModel: MyPropertiesViewModel) {
        self.properties = properties
        self.viewModel = viewModel
        // REMOVED: UITableView.appearance() modifications
    }

    var body: some View {
        List {
            ForEach(properties) { property in
                ZStack {
                    NavigationLink {
                        PropertyDetailView(propertyId: property.id)
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        EmptyView()
                    }
                    .opacity(0)

                    PropertyRow(property: property)
                }
                .listRowInsets(EdgeInsets()) 
                .padding(.horizontal) 
                .padding(.vertical, 8) 
                .listRowBackground(AppColors.secondaryBackground) // Use secondary background for rows
                .listRowSeparator(.hidden) // Hide default separators, rely on spacing/background
            }
        }
        .listStyle(.plain)
        // .scrollContentBackground(.hidden) // Make list background transparent - Removed for iOS < 16 compatibility
        // .background(AppColors.appBackground) // Background provided by parent ZStack
        .refreshable { 
            viewModel.loadProperties()
        }
    }
}

struct PropertyRow: View {
    let property: Property
    
    // Shared Date Formatter
    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) { // Added spacing
            VStack(alignment: .leading, spacing: 4) {
                Text(property.itemName)
                    .font(AppFonts.bodyBold) // Use themed font
                    .foregroundColor(AppColors.primaryText)
                Text("SN: \(property.serialNumber)")
                    .font(AppFonts.caption) // Use themed font
                    .foregroundColor(AppColors.secondaryText)
                 if let lastInv = property.lastInventoryDate {
                     Text("Last Inv: \(lastInv, formatter: Self.dateFormatter)")
                        .font(AppFonts.caption) // Use themed font
                        .foregroundColor(AppColors.secondaryText.opacity(0.8))
                 }
            }
            
            Spacer()
            
            // Status Badge
            Text(property.status.capitalized)
                .font(AppFonts.captionBold) // Use themed font
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundColor(statusTextColor(property.status)) // Use helper for text color
                .background(statusBackgroundColor(property.status)) // Use helper for background
                .clipShape(Capsule())
        }
        // No need for background here, handled by listRowBackground
        // .background(AppColors.appBackground)
    }

    // Helper to determine status BACKGROUND color (themed)
    private func statusBackgroundColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "operational", "available":
            return AppColors.accent.opacity(0.2) // Muted accent
        case "maintenance", "repair", "non-operational":
            return Color.orange.opacity(0.2) // Muted orange
        case "transfer pending", "pending":
            return Color.blue.opacity(0.2) // Muted blue (or another distinct color)
        default:
            return AppColors.secondaryText.opacity(0.2) // Muted gray
        }
    }
    
    // Helper to determine status TEXT color (themed)
    private func statusTextColor(_ status: String) -> Color {
         switch status.lowercased() {
        case "operational", "available":
            return AppColors.accent
        case "maintenance", "repair", "non-operational":
            return Color.orange
        case "transfer pending", "pending":
            return Color.blue
        default:
            return AppColors.secondaryText
        }
    }
}

struct EmptyPropertiesStateView: View {
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40) // Slightly smaller
                .foregroundColor(AppColors.secondaryText)
            Text("No Properties Assigned")
                .font(AppFonts.headline) // Use themed font
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryText)
            Text("Your assigned property list is currently empty.")
                .font(AppFonts.body) // Use themed font
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal) // Add horizontal padding for text
            
            Button("Refresh", action: onRefresh)
                .buttonStyle(.primary) // Use primary button style
                .padding(.top)
        }
        .padding() 
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Background is handled by parent ZStack
        // .background(AppColors.appBackground.ignoresSafeArea())
    }
}

struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40) // Slightly smaller
                .foregroundColor(AppColors.destructive)
            Text("Error Loading Data")
                .font(AppFonts.headline) // Use themed font
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryText)
            Text(message)
                .font(AppFonts.body) // Use themed font
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal) // Add horizontal padding for text
            
            Button("Retry", action: onRetry)
                .buttonStyle(.primary) // Use primary button style
                .padding(.top)
        }
        .padding(.horizontal) 
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Background handled by parent ZStack
    }
}

// MARK: - Preview

struct MyPropertiesView_Previews: PreviewProvider {
    static var previews: some View {
        // Example with success state
        Group {
            NavigationView { // Wrap preview in NavigationView for realistic context
                MyPropertiesView(viewModel: {
                    let vm = MyPropertiesViewModel(apiService: MockAPIService())
                    vm.loadingState = .success(Property.mockList)
                    return vm
                }())
            }
            .preferredColorScheme(.dark) // Apply dark mode
            .previewDisplayName("Success State - Dark")

            NavigationView {
                MyPropertiesView(viewModel: {
                    let vm = MyPropertiesViewModel(apiService: MockAPIService())
                    vm.loadingState = .success([])
                    return vm
                }())
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Empty State - Dark")

            NavigationView {
                MyPropertiesView(viewModel: {
                    let vm = MyPropertiesViewModel(apiService: MockAPIService())
                    vm.loadingState = .error("Network connection lost. Please try again.")
                    return vm
                }())
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Error State - Dark")
        }
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
            itemName: "Test Prop 1", 
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
            isSensitiveItem: false
        ),
        Property(
            id: 2, 
            serialNumber: "SN456", 
            nsn: "2222-22-222-2222", 
            lin: "E03046", 
            itemName: "Test Prop 2", 
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
            isSensitiveItem: false
        ),
        Property(
            id: 3, 
            serialNumber: "SN789", 
            nsn: "3333-33-333-3333", 
            lin: "E03047", 
            itemName: "Test Prop 3", 
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
            isSensitiveItem: true
        )
    ]
}
#endif 