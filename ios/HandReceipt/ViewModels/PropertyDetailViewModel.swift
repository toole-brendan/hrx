import Foundation
import Combine

// Enum to represent the state of the data loading
enum PropertyDetailLoadingState: Equatable {
    case idle
    case loading
    case success(Property) // Hold the fetched property
    case error(String)
    
    // Implement Equatable manually
    static func == (lhs: PropertyDetailLoadingState, rhs: PropertyDetailLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.success(let lProp), .success(let rProp)): return lProp.id == rProp.id
        case (.error(let lMsg), .error(let rMsg)): return lMsg == rMsg
        default: return false
        }
    }
}

// Reuse TransferRequestState from ScanViewModel or define locally
// Assuming ScanViewModel is available or state is redefined
typealias TransferRequestState = ScanViewModel.TransferRequestState

@MainActor // Ensure UI updates happen on the main thread
class PropertyDetailViewModel: ObservableObject {

    @Published var loadingState: PropertyDetailLoadingState = .idle
    @Published var property: Property? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // State for user selection sheet
    @Published var showingUserSelection = false
    
    // State for transfer request initiated from this view
    @Published var transferRequestState: TransferRequestState = .idle

    private let apiService: APIServiceProtocol
    private let propertyId: Int
    private var cancellables = Set<AnyCancellable>()
    private var clearStateTimer: AnyCancellable? // Timer for transfer status message

    init(propertyId: Int, apiService: APIServiceProtocol = APIService()) {
        self.propertyId = propertyId
        self.apiService = apiService
        print("PropertyDetailViewModel initialized for property ID: \(propertyId)")
    }

    func loadProperty() {
        if case .loading = loadingState { return }
        print("Attempting to fetch details for property: \(propertyId)")
        
        loadingState = .loading

        Task {
            do {
                let fetchedProperty = try await apiService.getPropertyById(propertyId: propertyId)
                self.property = fetchedProperty
                loadingState = .success(fetchedProperty)
                print("Successfully fetched details for property: \(fetchedProperty.itemName)")
            } catch let apiError as APIService.APIError {
                print("API Error fetching property details: \(apiError.localizedDescription)")
                let message: String
                switch apiError {
                case .itemNotFound:
                    message = "Property not found."
                case .unauthorized:
                    message = "Unauthorized. Please check login status."
                case .networkError, .serverError:
                    message = "A network or server error occurred."
                default:
                    message = apiError.localizedDescription
                }
                loadingState = .error(message)
            } catch {
                print("Unexpected error fetching property details: \(error.localizedDescription)")
                loadingState = .error("An unexpected error occurred.")
            }
        }
    }

    func requestTransferClicked() {
        // Ensure property is loaded before showing user selection
        guard property != nil else { 
            print("PropertyDetailVM Error: Cannot request transfer, property not loaded.")
            errorMessage = "Property details must be loaded first."
            return
        }
        transferRequestState = .idle // Reset previous state
        showingUserSelection = true
    }
    
    func initiateTransfer(targetUser: UserSummary) {
        // showingUserSelection = false // Dismiss sheet implicitly handled by sheet modifier - no need to set here
        guard let propertyToTransfer = property else {
             transferRequestState = .error("Property details not available.")
             return
        }
        
        print("PropertyDetailVM: Initiating transfer for property \(propertyToTransfer.id) to user \(targetUser.id)")
        transferRequestState = .loading
        clearStateTimer?.cancel() // Cancel previous timer
        
        Task {
             do {
                 let newTransfer = try await apiService.requestTransfer(propertyId: propertyToTransfer.id, targetUserId: targetUser.id)
                 print("PropertyDetailVM: Transfer request successful - ID \(newTransfer.id)")
                 self.transferRequestState = .success(newTransfer)
                 // Schedule state reset
                 self.scheduleTransferStateReset(delay: 3.0)
                 // TODO: Optionally refresh property details or navigate away
             } catch {
                 print("PropertyDetailVM: Transfer request failed - \(error.localizedDescription)")
                 self.transferRequestState = .error("Transfer failed: \(error.localizedDescription)")
                 // Schedule state reset
                 self.scheduleTransferStateReset(delay: 5.0)
             }
        }
    }
    
    // Helper to reset transfer state after a delay
    private func scheduleTransferStateReset(delay: TimeInterval) {
        clearStateTimer?.cancel()
        clearStateTimer = Just(()) 
            .delay(for: .seconds(delay), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.transferRequestState = .idle
            }
    }
     
    deinit {
        clearStateTimer?.cancel()
    }
} 