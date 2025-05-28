import Foundation
import Combine
import SwiftUI // Needed for UUID

@MainActor
class TransfersViewModel: ObservableObject {
    
    // MARK: - State Enums
    enum LoadingState: Equatable { // Add Equatable conformance
        case idle
        case loading
        case success([Transfer])
        case error(String)

        // Manually implement Equatable for enums with associated values
        static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.loading, .loading): return true
            // For success, we might compare based on content if needed, but for simple state checking,
            // just checking if both are .success might be enough. Comparing arrays can be complex.
            case (.success(let lTransfers), .success(let rTransfers)): return lTransfers == rTransfers // Compare transfer arrays
            case (.error(let lMsg), .error(let rMsg)): return lMsg == rMsg
            default: return false // Different cases are not equal
            }
        }
    }
    
    enum ActionState: Equatable { // Conform to Equatable for easier state comparison/animation
        case idle
        case loading
        case success(String) // Success message (e.g., "Transfer Approved")
        case error(String) // Error message
    }
    
    enum FilterDirection: String, CaseIterable, Identifiable {
        case all = "All"
        case incoming = "Incoming"
        case outgoing = "Outgoing"
        var id: String { self.rawValue }
    }
    
    enum FilterStatus: String, CaseIterable, Identifiable {
        case pending = "Pending"
        case all = "All"
        case approved = "Approved"
        case rejected = "Rejected"
        case cancelled = "Cancelled"
        var id: String { self.rawValue }
    }

    // MARK: - Published Properties
    @Published var loadingState: LoadingState = .idle
    @Published var actionState: ActionState = .idle // For approve/reject actions
    @Published var selectedDirectionFilter: FilterDirection = .all
    @Published var selectedStatusFilter: FilterStatus = .pending
    
    // MARK: - Dependencies
    private let apiService: APIServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // TODO: We need access to the current user's ID to implement direction filtering correctly.
    // This might come from an injected AuthViewModel or a shared session manager.
    // For now, the computed property will ignore the direction filter.
    var currentUserId: Int? = nil // Changed from UUID?
    
    // Computed property for filtered transfers
    var filteredTransfers: [Transfer] {
        guard case .success(let transfers) = loadingState else { return [] }
        
        return transfers.filter { transfer in
            // Status Filter
            let statusMatch = (selectedStatusFilter == .all || transfer.status.rawValue.lowercased() == selectedStatusFilter.rawValue.lowercased())
            
            // Direction Filter (requires currentUserId)
            var directionMatch = true // Default to true if no filter or ID unavailable
            if let userId = currentUserId, selectedDirectionFilter != .all {
                if selectedDirectionFilter == .incoming {
                    directionMatch = (transfer.toUserId == userId)
                } else { // .outgoing
                    directionMatch = (transfer.fromUserId == userId)
                }
            }
            
            return statusMatch && directionMatch
        }
    }

    // MARK: - Initialization
    init(apiService: APIServiceProtocol = APIService(), currentUserId: Int? = nil) { // Changed from UUID?
        self.apiService = apiService
        self.currentUserId = currentUserId // Set the current user ID
        print("TransfersViewModel initialized. Current User ID: \(currentUserId?.description ?? "N/A")") // Use .description for Int?
        
        // Reload transfers when filters change
        Publishers.CombineLatest($selectedDirectionFilter, $selectedStatusFilter)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main) // Small debounce
            .sink { [weak self] _, _ in
                self?.fetchTransfers()
            }
            .store(in: &cancellables)
        
        // Initial Fetch
        fetchTransfers()
    }

    // MARK: - API Calls
    func fetchTransfers() {
        print("TransfersViewModel: Fetching transfers (Status: \(selectedStatusFilter.rawValue), Direction: \(selectedDirectionFilter.rawValue))")
        // Always fetch ALL for now, filtering happens in computed property
        // TODO: Update API call if backend supports server-side filtering for status/direction
        let statusParam = selectedStatusFilter == .all ? nil : selectedStatusFilter.rawValue.uppercased()
        let directionParam: String? = nil // Fetch all directions, filter locally based on currentUserId

        loadingState = .loading
        actionState = .idle // Clear action state on refresh
        
        Task {
            do {
                let transfers = try await apiService.fetchTransfers(status: statusParam, direction: directionParam)
                print("TransfersViewModel: Successfully fetched \(transfers.count) transfers from API.")
                loadingState = .success(transfers)
            } catch {
                print("TransfersViewModel: Error fetching transfers - \(error.localizedDescription)")
                loadingState = .error("Failed to load transfers: \(error.localizedDescription)")
            }
        }
    }
    
    func approveTransfer(transferId: Int) { // Changed from UUID
        print("TransfersViewModel: Approving transfer ID \(transferId)")
        actionState = .loading
        clearActionTimer?.cancel() // Cancel any pending clear timer
        
        Task {
            do {
                _ = try await apiService.approveTransfer(transferId: transferId) // Pass Int
                print("TransfersViewModel: Successfully approved transfer ID \(transferId)")
                actionState = .success("Transfer Approved")
                // Refresh the list to show updated status
                fetchTransfers()
                // Schedule state clear after delay
                scheduleActionStateClear()
            } catch {
                print("TransfersViewModel: Error approving transfer ID \(transferId) - \(error.localizedDescription)")
                actionState = .error("Approval failed: \(error.localizedDescription)")
                scheduleActionStateClear()
            }
        }
    }
    
    func rejectTransfer(transferId: Int) { // Changed from UUID
        print("TransfersViewModel: Rejecting transfer ID \(transferId)")
        actionState = .loading
        clearActionTimer?.cancel()
        
        Task {
            do {
                _ = try await apiService.rejectTransfer(transferId: transferId) // Pass Int
                print("TransfersViewModel: Successfully rejected transfer ID \(transferId)")
                actionState = .success("Transfer Rejected")
                // Refresh the list to show updated status
                fetchTransfers()
                scheduleActionStateClear()
            } catch {
                print("TransfersViewModel: Error rejecting transfer ID \(transferId) - \(error.localizedDescription)")
                actionState = .error("Rejection failed: \(error.localizedDescription)")
                scheduleActionStateClear()
            }
        }
    }
    
    // MARK: - Helpers
    private var clearActionTimer: AnyCancellable?
    
    private func scheduleActionStateClear(delay: TimeInterval = 3.0) {
        clearActionTimer?.cancel()
        clearActionTimer = Just(())
            .delay(for: .seconds(delay), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                // Only clear if it's still in a success/error state
                if self?.actionState != .loading && self?.actionState != .idle {
                    print("Clearing action state.")
                    self?.actionState = .idle
                }
            }
    }
    
    deinit {
        clearActionTimer?.cancel()
        cancellables.forEach { $0.cancel() }
        print("TransfersViewModel deinitialized")
    }
} 