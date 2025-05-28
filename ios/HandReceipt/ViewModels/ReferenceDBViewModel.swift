import Foundation
import Combine // Needed for ObservableObject

// ViewModel for the Reference Database Browser View
@MainActor // Ensure UI updates happen on the main thread
class ReferenceDBViewModel: ObservableObject {

    @Published var referenceItems: [ReferenceItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Dependency injection for the API service
    private let apiService: APIServiceProtocol

    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }

    // Function to fetch reference items from the API
    func loadReferenceItems() {
        // Don't fetch if already loading
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil // Clear previous errors

        Task {
            do {
                let items = try await apiService.fetchReferenceItems()
                self.referenceItems = items
            } catch let apiError as APIService.APIError {
                 print("API Error loading reference items: \(apiError.localizedDescription)")
                 // Provide more specific user-facing messages
                 switch apiError {
                 case .unauthorized:
                     self.errorMessage = "Unauthorized. Please log in again."
                 case .networkError:
                     self.errorMessage = "Network error. Please check your connection."
                 case .serverError(let code, _):
                     self.errorMessage = "Server error (Code: \(code)). Please try again later."
                 default:
                     self.errorMessage = "Failed to load items: \(apiError.localizedDescription)"
                 }
            } catch {
                // Handle other unexpected errors
                 print("Unexpected error loading reference items: \(error)")
                self.errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            }
            // Ensure isLoading is set to false regardless of success or failure
            self.isLoading = false
        }
    }
} 