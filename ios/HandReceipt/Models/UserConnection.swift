import Foundation

public struct UserConnection: Codable, Identifiable {
    public let id: Int
    public let userId: Int
    public let connectedUserId: Int
    public let connectionStatus: ConnectionStatus
    public let connectedUser: UserSummary?
    public let createdAt: Date
    
    public enum ConnectionStatus: String, Codable {
        case pending = "pending"
        case accepted = "accepted"
        case blocked = "blocked"
    }
} 