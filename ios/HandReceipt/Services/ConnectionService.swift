import Foundation

@MainActor
public class ConnectionService: ObservableObject {
    @Published public var connections: [UserConnection] = []
    @Published public var isLoading: Bool = false
    
    public init() {}
    
    public func loadConnections() async {
        isLoading = true
        
        do {
            let response = try await APIService.shared.getConnections()
            connections = response.connections
        } catch {
            print("Failed to load connections: \(error)")
        }
        
        isLoading = false
    }
    
    public func refreshConnections() async {
        await loadConnections()
    }
    
    public func sendConnectionRequest(to user: User) async throws {
        _ = try await APIService.shared.sendConnectionRequest(userId: user.id)
        await loadConnections()
    }
    
    public func acceptConnectionRequest(_ connection: UserConnection) async throws {
        _ = try await APIService.shared.acceptConnectionRequest(connectionId: connection.id)
        await loadConnections()
    }
    
    public func rejectConnectionRequest(_ connection: UserConnection) async throws {
        _ = try await APIService.shared.rejectConnectionRequest(connectionId: connection.id)
        await loadConnections()
    }
}

// MARK: - Connection Response Models

struct ConnectionsResponse: Codable {
    let connections: [UserConnection]
    let count: Int
}

struct ConnectionResponse: Codable {
    let connection: UserConnection
    let message: String
}

// MARK: - API Extensions

extension APIService {
    func getConnections() async throws -> ConnectionsResponse {
        let endpoint = "/api/connections"
        return try await makeRequest(endpoint: endpoint, method: .GET)
    }
    
    func sendConnectionRequest(userId: Int) async throws -> ConnectionResponse {
        let endpoint = "/api/connections/request"
        let body = ["user_id": userId]
        return try await makeRequest(endpoint: endpoint, method: .POST, body: body)
    }
    
    func acceptConnectionRequest(connectionId: String) async throws -> ConnectionResponse {
        let endpoint = "/api/connections/\(connectionId)/accept"
        return try await makeRequest(endpoint: endpoint, method: .POST)
    }
    
    func rejectConnectionRequest(connectionId: String) async throws -> ConnectionResponse {
        let endpoint = "/api/connections/\(connectionId)/reject"
        return try await makeRequest(endpoint: endpoint, method: .POST)
    }
} 