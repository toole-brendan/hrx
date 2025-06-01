import Foundation
import Combine

// MARK: - Connection Request Model
struct ConnectionRequest: Identifiable {
    let id: Int
    let requester: UserSummary
    let requestedAt: Date
}

// MARK: - Connections View Model
@MainActor
class ConnectionsViewModel: ObservableObject {
    @Published var connections: [UserConnection] = []
    @Published var pendingRequests: [ConnectionRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    func loadConnections() {
        Task {
            await fetchConnections()
        }
    }
    
    func refresh() async {
        await fetchConnections()
    }
    
    private func fetchConnections() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let allConnections = try await apiService.getConnections()
            
            // Filter accepted connections
            connections = allConnections.filter { $0.connectionStatus == .accepted }
            
            // Filter pending requests (where current user is the target)
            let pendingConnections = allConnections.filter { $0.connectionStatus == .pending }
            
            // Convert to ConnectionRequest format
            pendingRequests = pendingConnections.compactMap { connection in
                guard let connectedUser = connection.connectedUser else { return nil }
                return ConnectionRequest(
                    id: connection.id,
                    requester: connectedUser,
                    requestedAt: connection.createdAt
                )
            }
            
        } catch {
            errorMessage = "Failed to load connections: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func acceptConnection(_ connectionId: Int) {
        Task {
            do {
                _ = try await apiService.updateConnectionStatus(connectionId: connectionId, status: "accepted")
                await fetchConnections()
            } catch {
                errorMessage = "Failed to accept connection: \(error.localizedDescription)"
            }
        }
    }
    
    func rejectConnection(_ connectionId: Int) {
        Task {
            do {
                _ = try await apiService.updateConnectionStatus(connectionId: connectionId, status: "rejected")
                await fetchConnections()
            } catch {
                errorMessage = "Failed to reject connection: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Add Connection View Model
@MainActor
class AddConnectionViewModel: ObservableObject {
    @Published var searchResults: [UserSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    func searchUsers(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                searchResults = try await apiService.searchUsers(query: query)
            } catch {
                errorMessage = "Failed to search users: \(error.localizedDescription)"
                searchResults = []
            }
            
            isLoading = false
        }
    }
    
    func sendConnectionRequest(to userId: Int) {
        Task {
            do {
                _ = try await apiService.sendConnectionRequest(targetUserId: userId)
                // TODO: Show success message or navigate back
            } catch {
                errorMessage = "Failed to send connection request: \(error.localizedDescription)"
            }
        }
    }
} 