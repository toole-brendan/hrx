import Foundation

// --- Authentication Models --- 

// Struct for the login request body
struct LoginCredentials: Encodable {
    let username: String
    let password: String // Sent plain text over HTTPS
}

// Struct for the expected successful login response
// Updated with more robust error handling
struct LoginResponse: Decodable {
    let token: String
    let user: User
    
    struct User: Decodable {
        let id: Int
        let username: String
        let name: String
        let rank: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case username
            case name
            case rank
        }
        
        // Explicit memberwise initializer (needed when custom init(from:) is present)
        init(id: Int, username: String, name: String, rank: String) {
            self.id = id
            self.username = username
            self.name = name
            self.rank = rank
        }
        
        // Custom initializer for more debugging information
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            id = try container.decode(Int.self, forKey: .id)
            username = try container.decode(String.self, forKey: .username)
            name = try container.decode(String.self, forKey: .name)
            rank = try container.decode(String.self, forKey: .rank)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case token
        case user
    }
    
    // Explicit memberwise initializer (needed when custom init(from:) is present)
    init(token: String, user: User) {
        self.token = token
        self.user = user
    }
    
    // Custom initializer for more debugging information
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        token = try container.decode(String.self, forKey: .token)
        user = try container.decode(User.self, forKey: .user)
    }
    
    // For compatibility with existing code
    var userId: Int { user.id }
    var message: String { "Login successful" } // Provide a default value
}

// New struct for /auth/me endpoint response which doesn't include token
struct UserResponse: Decodable {
    let user: LoginResponse.User
    
    enum CodingKeys: String, CodingKey {
        case user
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decode(LoginResponse.User.self, forKey: .user)
    }
    
    // Helper to convert to LoginResponse for code compatibility
    func toLoginResponse(token: String = "") -> LoginResponse {
        return LoginResponse(token: token, user: user)
    }
}

// Define other auth-related structs (e.g., for registration) if needed 