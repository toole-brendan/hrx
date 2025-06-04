import Foundation

@MainActor
public class ConnectionService: ObservableObject {
    @Published public var connections: [UserConnection] = []
    @Published public var isLoading: Bool = false
    
    public init() {}
    
    public func loadConnections() async {
        isLoading = true
        
        do {
            connections = try await APIService.shared.getConnections()
        } catch {
            print("Failed to load connections: \(error)")
        }
        
        isLoading = false
    }
    
    public func refreshConnections() async {
        await loadConnections()
    }
    
    public func sendConnectionRequest(to user: UserSummary) async throws {
        _ = try await APIService.shared.sendConnectionRequest(targetUserId: user.id)
        await loadConnections()
    }
    
    public func acceptConnectionRequest(_ connection: UserConnection) async throws {
        _ = try await APIService.shared.updateConnectionStatus(connectionId: connection.id, status: "accepted")
        await loadConnections()
    }
    
    public func rejectConnectionRequest(_ connection: UserConnection) async throws {
        _ = try await APIService.shared.updateConnectionStatus(connectionId: connection.id, status: "rejected")
        await loadConnections()
    }
}

// MARK: - Connection Response Models

struct ConnectionResponse: Codable {
    let connection: UserConnection
    let message: String
} 