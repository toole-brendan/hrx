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
class MockAPIService: APIServiceProtocol {
    var mockProperties: [Property]?
    var mockReferenceItems: [ReferenceItem]? // Add for other potential mocks
    var mockProperty: Property? // Add for single property fetch
    var mockLoginResponse: LoginResponse? // Add for auth mocks
    var shouldThrowError = false
    var simulatedDelay: TimeInterval = 0.1

    // Helper to create mock LoginResponse
    private func createMockLoginResponse(userId: Int, username: String, message: String) -> LoginResponse {
        let mockResponseData = """
        {
            "token": "mock_token_\(UUID().uuidString)",
            "user": {
                "id": \(userId),
                "username": "\(username)",
                "name": "Mock Name",
                "rank": "MCK"
            }
        }
        """.data(using: .utf8)!
        
        do {
            return try JSONDecoder().decode(LoginResponse.self, from: mockResponseData)
        } catch {
            // In a real mock, you might want to handle this error differently,
            // maybe fatalError or return a specific error response.
            // For preview purposes, creating a default might be okay,
            // but it hides potential decoding issues in the main struct.
            print("Error creating mock LoginResponse: \(error)")
            // Fallback - This will likely fail if LoginResponse can't be initialized this way
            // Try creating a very basic default if decoding fails, though this might not be ideal
            let defaultUser = LoginResponse.User(id: 0, username: "error_user", name: "Error", rank: "ERR")
            return LoginResponse(token: "error_token", user: defaultUser)
        }
    }

    func getMyProperties() async throws -> [Property] {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        if shouldThrowError { throw APIService.APIError.serverError(statusCode: 500) }
        return mockProperties ?? []
    }
    
    // Implement other protocol methods to return mock data or throw errors
     func fetchReferenceItems() async throws -> [ReferenceItem] { 
         try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
         if shouldThrowError { throw APIService.APIError.networkError(URLError(.notConnectedToInternet)) }
         return mockReferenceItems ?? []
     }
    func fetchPropertyBySerialNumber(serialNumber: String) async throws -> Property { 
         try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        if shouldThrowError { throw APIService.APIError.itemNotFound }        
         if let prop = mockProperty, prop.serialNumber == serialNumber { return prop }
         throw APIService.APIError.itemNotFound
    }
    func login(credentials: LoginCredentials) async throws -> LoginResponse { 
         try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        if shouldThrowError { throw APIService.APIError.unauthorized }
         return mockLoginResponse ?? createMockLoginResponse(userId: 123, username: credentials.username, message: "Mock login successful")
    }
    func checkSession() async throws -> LoginResponse { 
         try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
         if shouldThrowError { throw APIService.APIError.unauthorized }
         return mockLoginResponse ?? createMockLoginResponse(userId: 456, username: "mockSessionUser", message: "Mock session")
    }
    func fetchReferenceItemById(itemId: String) async throws -> ReferenceItem { 
         try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        if shouldThrowError { throw APIService.APIError.itemNotFound }        
         if let item = mockReferenceItems?.first(where: { $0.id.uuidString == itemId }) { return item }
         throw APIService.APIError.itemNotFound
    }
    // Add missing methods required by protocol
     func getPropertyById(propertyId: Int) async throws -> Property {
         try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
         if shouldThrowError { throw APIService.APIError.itemNotFound }
         if let prop = mockProperty, prop.id == propertyId { return prop }
         if let prop = mockProperties?.first(where: { $0.id == propertyId }) { return prop }
         throw APIService.APIError.itemNotFound
     }
     func logout() async throws {
         try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
         if shouldThrowError { throw APIService.APIError.serverError(statusCode: 500) }
         // No return value needed
     }
     // Add baseURLString requirement
     var baseURLString: String { "http://mock.api" }

     // Add missing stubs for protocol conformance
     func fetchTransfers(status: String?, direction: String?) async throws -> [Transfer] {
         if shouldThrowError { throw APIService.APIError.serverError(statusCode: 500) }
         return [] // Return empty array for mock
     }
     func requestTransfer(propertyId: Int, targetUserId: Int) async throws -> Transfer {
         if shouldThrowError { throw APIService.APIError.serverError(statusCode: 500) }
         // Need to create a mock Transfer or throw an error appropriate for previews
         // Ensure UserSummary and Transfer use the correct initializers or are Decodable
         let mockFromUser = UserSummary(id: 123, username: "mockFromUser", rank: "PVT", lastName: "Mock")
         let mockToUser = UserSummary(id: targetUserId, username: "mockToUser", rank: "PVT", lastName: "Target")
         let mockTransfer = Transfer(
            id: Int.random(in: 1000...9999),
            propertyId: propertyId,
            propertySerialNumber: "MOCKSN123",
            propertyName: "Mock Property",
            fromUserId: 123,
            toUserId: targetUserId,
            status: .PENDING,
            requestTimestamp: Date(),
            approvalTimestamp: nil,
            fromUser: mockFromUser,
            toUser: mockToUser,
            notes: nil
         )
         return mockTransfer
     }
     func approveTransfer(transferId: Int) async throws -> Transfer {
         if shouldThrowError { throw APIService.APIError.serverError(statusCode: 500) }
         // TODO: Return a mock transfer based on the ID if needed for previews
         throw APIService.APIError.unknownError // Placeholder
     }
     func rejectTransfer(transferId: Int) async throws -> Transfer {
         if shouldThrowError { throw APIService.APIError.serverError(statusCode: 500) }
         // TODO: Return a mock transfer based on the ID if needed for previews
         throw APIService.APIError.unknownError // Placeholder
     }
     func fetchUsers(searchQuery: String?) async throws -> [UserSummary] {
         if shouldThrowError { throw APIService.APIError.serverError(statusCode: 500) }
         // Create mock users ensuring UserSummary initializer is correct
         return [
             UserSummary(id: 101, username: "user1", rank: "SGT", lastName: "One"),
             UserSummary(id: 102, username: "user2", rank: "CPL", lastName: "Two")
         ]
     }

}

extension Property {
    static let mockList = [
        Property(id: 1, serialNumber: "SN123", nsn: "1111-11-111-1111", itemName: "Test Prop 1", description: "Mock Description 1", manufacturer: "Mock Manu", imageUrl: nil, status: "Operational", assignedToUserId: nil, location: "Bldg 1", lastInventoryDate: Date(), acquisitionDate: nil, notes: nil),
        Property(id: 2, serialNumber: "SN456", nsn: "2222-22-222-2222", itemName: "Test Prop 2", description: "Mock Description 2", manufacturer: "Mock Manu", imageUrl: nil, status: "Maintenance", assignedToUserId: nil, location: "Bldg 2", lastInventoryDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()), acquisitionDate: nil, notes: nil),
        Property(id: 3, serialNumber: "SN789", nsn: "3333-33-333-3333", itemName: "Test Prop 3", description: "Mock Description 3", manufacturer: "Mock Manu", imageUrl: nil, status: "Operational", assignedToUserId: nil, location: "Bldg 1", lastInventoryDate: Calendar.current.date(byAdding: .month, value: -1, to: Date()), acquisitionDate: nil, notes: nil)
    ]
}
#endif 