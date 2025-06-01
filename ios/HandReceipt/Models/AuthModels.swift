import Foundation

// --- Authentication Models --- 

// Struct for the login request body
public struct LoginCredentials: Encodable {
    public let username: String
    public let password: String // Sent plain text over HTTPS
    
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

// Struct for the expected successful login response
// Updated with JWT token support
public struct LoginResponse: Decodable {
    public let accessToken: String?
    public let refreshToken: String?
    public let expiresAt: Date?
    public let user: User
    
    // For backward compatibility with existing code
    public var token: String {
        return accessToken ?? ""
    }
    
    public struct User: Codable {
        public let id: Int
        public let uuid: String?
        public let username: String
        public let email: String?
        public let firstName: String?
        public let lastName: String?
        public let rank: String
        public let unit: String?
        public let role: String?
        public let status: String?
        
        // Computed property for backward compatibility
        public var name: String {
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
        public init(id: Int, uuid: String? = nil, username: String, email: String? = nil, 
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
        public init(from decoder: Decoder) throws {
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
    public init(accessToken: String? = nil, refreshToken: String? = nil, expiresAt: Date? = nil, user: User) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.user = user
    }
    
    // Custom initializer for decoding
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        user = try container.decode(User.self, forKey: .user)
    }
    
    // For compatibility with existing code
    public var userId: Int { user.id }
    public var message: String { "Login successful" }
}

// New struct for /auth/me endpoint response which doesn't include token
public struct UserResponse: Decodable {
    public let user: LoginResponse.User
    
    enum CodingKeys: String, CodingKey {
        case user
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decode(LoginResponse.User.self, forKey: .user)
    }
    
    // Helper to convert to LoginResponse for code compatibility
    public func toLoginResponse(token: String = "") -> LoginResponse {
        return LoginResponse(accessToken: token, user: user)
    }
}

// Define other auth-related structs (e.g., for registration) if needed 

// Add registration request model
public struct RegisterCredentials: Encodable {
    public let username: String
    public let email: String
    public let password: String
    public let first_name: String
    public let last_name: String
    public let rank: String
    public let unit: String
    public let role: String
    
    public init(username: String, email: String, password: String, 
                first_name: String, last_name: String, rank: String, 
                unit: String, role: String = "user") {
        self.username = username
        self.email = email
        self.password = password
        self.first_name = first_name
        self.last_name = last_name
        self.rank = rank
        self.unit = unit
        self.role = role
    }
    
    enum CodingKeys: String, CodingKey {
        case username, email, password
        case first_name = "first_name"
        case last_name = "last_name"
        case rank, unit, role
    }
} 