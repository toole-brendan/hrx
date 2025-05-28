import Foundation
import SwiftUI // Needed for @Published

// Enum to represent the state of the data loading
enum LoadingState {
    case idle
    case loading
    case success(ReferenceItem)
    case error(String)
}

@MainActor // Ensure UI updates happen on the main thread
class ReferenceItemDetailViewModel: ObservableObject {

    // Published properties to drive the UI
    @Published var item: ReferenceItem? = nil
    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String? = nil

    // Dependency: APIServiceProtocol
    private let apiService: APIServiceProtocol
    private let itemId: String

    // Initializer with dependency injection
    init(itemId: String, apiService: APIServiceProtocol = APIService()) {
        self.itemId = itemId
        self.apiService = apiService
        print("ReferenceItemDetailViewModel initialized for item ID: \(itemId)")
        // Fetch details immediately upon initialization
        fetchDetails()
    }

    // Function to fetch item details from the API
    func fetchDetails() {
        // Prevent multiple concurrent loads using pattern matching
        if case .loading = loadingState { return }
        
        loadingState = .loading
        item = nil // Clear previous item
        print("ReferenceItemDetailViewModel: Fetching details for \(itemId)")
        
        Task {
            do {
                let fetchedItem = try await apiService.fetchReferenceItemById(itemId: itemId)
                print("ReferenceItemDetailViewModel: Successfully fetched \(fetchedItem.itemName)")
                DispatchQueue.main.async {
                    self.item = fetchedItem
                    self.loadingState = .success(fetchedItem) // Update state with fetched item
                    self.errorMessage = nil // Clear error on success
                }
            } catch let apiError as APIService.APIError {
                print("ReferenceItemDetailViewModel: API Error - \(apiError.localizedDescription)")
                 let specificMessage: String = apiError.localizedDescription // Assign the error message
                self.errorMessage = specificMessage // Set the error message
                self.loadingState = .error(specificMessage) // Update state
            } catch {
                print("ReferenceItemDetailViewModel: Unknown Error - \(error.localizedDescription)")
                let genericMessage = "An unexpected error occurred."
                self.errorMessage = genericMessage
                self.loadingState = .error(genericMessage)
            }
        }
    }
} 