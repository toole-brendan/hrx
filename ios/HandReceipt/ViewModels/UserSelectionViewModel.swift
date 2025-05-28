import Foundation
import Combine
import SwiftUI // For UUID

enum UserListState {
    case idle
    case loading
    case success([UserSummary])
    case error(String)
}

@MainActor
class UserSelectionViewModel: ObservableObject {
    @Published var userListState: UserListState = .idle
    @Published var searchQuery: String = "" 
    
    private let apiService: APIServiceProtocol // Use protocol for DI
    private var cancellables = Set<AnyCancellable>()
    private var currentFetchTask: Task<Void, Never>? = nil // Task handle to allow cancellation

    init(apiService: APIServiceProtocol = APIService()) { // Allow DI
        self.apiService = apiService
        
        // Debounce search query
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                // Use Task to handle async operation
                self?.currentFetchTask?.cancel() // Cancel previous task
                self?.currentFetchTask = Task {
                    await self?.fetchUsers(query: query)
                }
            }
            .store(in: &cancellables)
    }

    func fetchUsers(query: String) async {
        guard !Task.isCancelled else { return } // Check if task was cancelled
        
        guard !query.isEmpty else {
            self.userListState = .idle // Clear results if query is empty
            return
        }
        
        self.userListState = .loading
        print("UserSelectionViewModel: Fetching users for query '\(query)'")

        do {
            let users = try await apiService.fetchUsers(searchQuery: query)
            // Check cancellation again after await
            guard !Task.isCancelled else { 
                print("UserSelectionViewModel: Task cancelled after fetch for '\(query)'")
                return 
            }
            // Verify query hasn't changed
            guard query == self.searchQuery else { 
                print("UserSelectionViewModel: Stale result ignored for query '\(query)'")
                return
            }
            print("UserSelectionViewModel: Found \(users.count) users for '\(query)'")
            self.userListState = .success(users)
        } catch {
            // Check cancellation before updating state
            guard !Task.isCancelled else { 
                print("UserSelectionViewModel: Task cancelled after error for '\(query)'")
                return 
            }
            print("UserSelectionViewModel: Error fetching users for '\(query)' - \(error.localizedDescription)")
             // Verify query hasn't changed before showing error
             if query == self.searchQuery {
                self.userListState = .error(error.localizedDescription)
             }
        }
    }
    
    // Call when view disappears or search is cancelled
    func clearSearch() {
        currentFetchTask?.cancel()
        searchQuery = "" // This will trigger the debounce and clear the state via fetchUsers
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
        currentFetchTask?.cancel()
    }
} 