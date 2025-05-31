struct UserConnection: Codable, Identifiable {
    let id: Int
    let userId: Int
    let connectedUserId: Int
    let connectionStatus: ConnectionStatus
    let connectedUser: User?
    let createdAt: Date
    
    enum ConnectionStatus: String, Codable {
        case pending = "pending"
        case accepted = "accepted"
        case blocked = "blocked"
    }
} 