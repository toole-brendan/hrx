import Foundation
import Combine

// Enum to represent the state of the property lookup
enum PropertyLookupState: Equatable {
    case idle // Initial state, nothing entered or searched yet
    case loading // Currently fetching data for the entered serial number
    case success(Property) // Successfully found the property
    case notFound // Serial number was searched, but no property found (404)
    case error(String) // An error occurred during the lookup

    // Add Equatable conformance
    static func == (lhs: PropertyLookupState, rhs: PropertyLookupState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.success(let lProp), .success(let rProp)): return lProp.id == rProp.id // Compare by ID or relevant fields
        case (.notFound, .notFound): return true
        case (.error(let lMsg), .error(let rMsg)): return lMsg == rMsg
        default: return false
        }
    }
}

@MainActor // Ensure UI updates happen on the main thread
class ManualSNViewModel: ObservableObject {

    // Published properties for the UI to bind to
    @Published var serialNumberInput: String = ""
    @Published var lookupState: PropertyLookupState = .idle

    // Debounce mechanism to avoid searching on every keystroke
    @Published private var debouncedSerialNumber: String = ""
    private var cancellables = Set<AnyCancellable>()

    // Dependency injection for the API service
    private let apiService: APIServiceProtocol

    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
        setupDebounce()
    }

    // Set up Combine pipeline to debounce serial number input
    private func setupDebounce() {
        $serialNumberInput
            // Debounce for 500 milliseconds after the user stops typing
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            // Remove duplicates to avoid searching the same SN multiple times
            .removeDuplicates()
             // Don't trigger search for empty strings after debounce
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            // Assign the debounced value
            .assign(to: &$debouncedSerialNumber)

        // Observe the debounced value and trigger the search
        $debouncedSerialNumber
            .sink { [weak self] debouncedSN in
                guard let self = self, !debouncedSN.isEmpty else { return }
                self.findProperty()
            }
            .store(in: &cancellables)

        // Reset state if input becomes empty
        $serialNumberInput
             .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sink { [weak self] _ in
                self?.resetState()
            }
            .store(in: &cancellables)
    }

    // Function called to initiate the property lookup
    // Usually triggered automatically by the debouncer
    func findProperty() {
        let serialToSearch = serialNumberInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !serialToSearch.isEmpty else {
            // Reset if the search was triggered with empty/whitespace string
            resetState()
            return
        }

        print("Attempting to find property with SN: \(serialToSearch)")
        lookupState = .loading // Set state to loading

        Task {
            do {
                let property = try await apiService.fetchPropertyBySerialNumber(serialNumber: serialToSearch)
                self.lookupState = .success(property)
                print("Successfully found property: \(property.itemName)")
            } catch let apiError as APIService.APIError {
                 switch apiError {
                 case .itemNotFound:
                     print("Property with SN \(serialToSearch) not found (404).")
                    self.lookupState = .notFound
                 case .decodingError(let error):
                     print("Decoding Error: \(error)")
                    self.lookupState = .error("Failed to process server response.")
                 case .networkError(let error):
                     print("Network Error: \(error)")
                    self.lookupState = .error("Network problem. Check connection.")
                 case .serverError(let statusCode, let message):
                     print("Server Error: \(statusCode) - \(message ?? "No message")")
                    self.lookupState = .error("Server error occurred (Code: \(statusCode)).")
                 default:
                    print("Other API Error: \(apiError)")
                    self.lookupState = .error("An unexpected API error occurred.")
                 }
            } catch {
                // Catch any other non-API errors
                print("Unknown Error fetching property: \(error)")
                self.lookupState = .error("An unexpected error occurred: \(error.localizedDescription)")
            }
        }
    }

    // Function to manually clear the input and reset the state
    func clearAndReset() {
        serialNumberInput = ""
        resetState()
    }

    // Resets the state to idle (e.g., when input is cleared)
    private func resetState() {
         // Check if state is already idle to avoid unnecessary UI updates
        if case .idle = lookupState { return }
        lookupState = .idle
        print("State reset to idle")
    }
} 