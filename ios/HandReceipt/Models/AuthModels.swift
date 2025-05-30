import Foundation

// --- Authentication Models --- 

// Struct for the login request body
struct LoginCredentials: Encodable {
    let username: String
    let password: String // Sent plain text over HTTPS
}

// Struct for the expected successful login response
// Updated with JWT token support
struct LoginResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: Date?
    let user: User
    
    // For backward compatibility with existing code
    var token: String {
        return accessToken ?? ""
    }
    
    struct User: Decodable {
        let id: Int
        let uuid: String?
        let username: String
        let email: String?
        let firstName: String?
        let lastName: String?
        let rank: String
        let unit: String?
        let role: String?
        let status: String?
        
        // Computed property for backward compatibility
        var name: String {
            if let firstName = firstName, let lastName = lastName {
                return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            } else if let firstName = firstName {
                return firstName
            } else if let lastName = lastName {
                return lastName
            } else {
                return username
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case id
            case uuid
            case username
            case email
            case firstName = "first_name"
            case lastName = "last_name"
            case rank
            case unit
            case role
            case status
        }
        
        // Explicit memberwise initializer
        init(id: Int, uuid: String? = nil, username: String, email: String? = nil, 
             firstName: String? = nil, lastName: String? = nil, rank: String, 
             unit: String? = nil, role: String? = nil, status: String? = nil) {
            self.id = id
            self.uuid = uuid
            self.username = username
            self.email = email
            self.firstName = firstName
            self.lastName = lastName
            self.rank = rank
            self.unit = unit
            self.role = role
            self.status = status
        }
        
        // Custom initializer for decoding
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            id = try container.decode(Int.self, forKey: .id)
            uuid = try container.decodeIfPresent(String.self, forKey: .uuid)
            username = try container.decode(String.self, forKey: .username)
            email = try container.decodeIfPresent(String.self, forKey: .email)
            firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
            lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
            rank = try container.decode(String.self, forKey: .rank)
            unit = try container.decodeIfPresent(String.self, forKey: .unit)
            role = try container.decodeIfPresent(String.self, forKey: .role)
            status = try container.decodeIfPresent(String.self, forKey: .status)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }
    
    // Explicit memberwise initializer
    init(accessToken: String? = nil, refreshToken: String? = nil, expiresAt: Date? = nil, user: User) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.user = user
    }
    
    // Custom initializer for decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        user = try container.decode(User.self, forKey: .user)
    }
    
    // For compatibility with existing code
    var userId: Int { user.id }
    var message: String { "Login successful" }
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
        return LoginResponse(accessToken: token, user: user)
    }
}

// Define other auth-related structs (e.g., for registration) if needed 

// Add registration request model
struct RegisterCredentials: Encodable {
    let username: String
    let email: String
    let password: String
    let first_name: String
    let last_name: String
    let rank: String
    let unit: String
    let role: String = "user"
    
    enum CodingKeys: String, CodingKey {
        case username, email, password
        case first_name = "first_name"
        case last_name = "last_name"
        case rank, unit, role
    }
} 