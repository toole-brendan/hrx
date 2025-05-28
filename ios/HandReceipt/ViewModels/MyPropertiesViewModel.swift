import Foundation
import Combine // For ObservableObject

// Enum to represent the state of loading user properties
enum MyPropertiesLoadingState: Equatable {
    case idle
    case loading
    case success([Property]) // Hold the fetched properties on success
    case error(String) // Hold the error message on failure

    // Implement == manually since Property might not be Equatable yet
    static func == (lhs: MyPropertiesLoadingState, rhs: MyPropertiesLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.success(let lProps), .success(let rProps)): return lProps.map { $0.id } == rProps.map { $0.id } // Compare by IDs
        case (.error(let lMsg), .error(let rMsg)): return lMsg == rMsg
        default: return false
        }
    }
}

@MainActor
class MyPropertiesViewModel: ObservableObject {
    
    @Published var loadingState: MyPropertiesLoadingState = .idle
    
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
        loadProperties()
    }
    
    func loadProperties() {
        guard loadingState != .loading else { return }
        
        loadingState = .loading
        print("MyPropertiesViewModel: Loading properties...")
        
        Task {
            do {
                let properties = try await apiService.getMyProperties()
                loadingState = .success(properties)
                print("MyPropertiesViewModel: Successfully loaded \(properties.count) properties.")
            } catch let apiError as APIService.APIError {
                print("MyPropertiesViewModel: API Error loading properties - \(apiError.localizedDescription)")
                let message: String
                switch apiError {
                    case .unauthorized: message = "Unauthorized. Please login again."
                    case .networkError: message = "Network error. Check connection."
                    case .serverError: message = "Server error occurred."
                    default: message = apiError.localizedDescription
                }
                loadingState = .error(message)
            } catch {
                print("MyPropertiesViewModel: Unknown error loading properties - \(error.localizedDescription)")
                loadingState = .error("An unexpected error occurred.")
            }
        }
    }
} 