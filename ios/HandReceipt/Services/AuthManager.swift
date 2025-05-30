import Foundation
import KeychainSwift

class AuthManager {
    static let shared = AuthManager()
    private let keychain = KeychainSwift()
    
    private let accessTokenKey = "handreceipt_access_token"
    private let refreshTokenKey = "handreceipt_refresh_token"
    private let userIdKey = "handreceipt_user_id"
    
    private init() {
        // Configure keychain
        keychain.synchronizable = false
    }
    
    // Store tokens after successful login
    func storeTokens(accessToken: String, refreshToken: String?, userId: Int) {
        keychain.set(accessToken, forKey: accessTokenKey)
        if let refreshToken = refreshToken {
            keychain.set(refreshToken, forKey: refreshTokenKey)
        }
        keychain.set(String(userId), forKey: userIdKey)
        
        debugPrint("Stored authentication tokens for user: \(userId)")
    }
    
    // Get access token
    func getAccessToken() -> String? {
        return keychain.get(accessTokenKey)
    }
    
    // Get refresh token
    func getRefreshToken() -> String? {
        return keychain.get(refreshTokenKey)
    }
    
    // Get user ID
    func getUserId() -> Int? {
        guard let userIdString = keychain.get(userIdKey),
              let userId = Int(userIdString) else {
            return nil
        }
        return userId
    }
    
    // Clear all tokens (logout)
    func clearTokens() {
        keychain.delete(accessTokenKey)
        keychain.delete(refreshTokenKey)
        keychain.delete(userIdKey)
        
        // Also clear URLSession cookies
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
        
        debugPrint("Cleared all authentication tokens and cookies")
    }
    
    // Check if user is authenticated
    var isAuthenticated: Bool {
        return getAccessToken() != nil
    }
}

// Extension to APIService to use JWT tokens
extension APIService {
    
    // Modified performRequest to include JWT token
    func performAuthenticatedRequest<T: Decodable>(request: URLRequest) async throws -> T {
        var modifiedRequest = request
        
        // Add JWT token to header if available
        if let accessToken = AuthManager.shared.getAccessToken() {
            modifiedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            debugPrint("Added JWT token to request headers")
        }
        
        return try await performRequest(request: modifiedRequest)
    }
    
    // Modified login to store JWT tokens
    func loginWithTokenStorage(credentials: LoginCredentials) async throws -> LoginResponse {
        debugPrint("Attempting to login user: \(credentials.username)")
        let endpoint = baseURL.appendingPathComponent("/api/auth/login")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try encoder.encode(credentials)
            debugPrint("Successfully encoded login credentials")
        } catch {
            debugPrint("ERROR: Failed to encode login credentials: \(error)")
            throw APIError.encodingError(error)
        }

        // Expect LoginResponse with tokens
        let response = try await performRequest(request: request) as LoginResponse
        
        // Store tokens if available
        if let accessToken = response.accessToken,
           let refreshToken = response.refreshToken {
            AuthManager.shared.storeTokens(
                accessToken: accessToken,
                refreshToken: refreshToken,
                userId: response.user.id
            )
        }
        
        debugPrint("Login successful for user: \(response.user.username)")
        return response
    }
    
    // Add method to refresh access token
    func refreshAccessToken() async throws -> TokenPair {
        guard let refreshToken = AuthManager.shared.getRefreshToken() else {
            throw APIError.unauthorized
        }
        
        let endpoint = baseURL.appendingPathComponent("/api/auth/refresh")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let refreshRequest = RefreshTokenRequest(refreshToken: refreshToken)
        request.httpBody = try encoder.encode(refreshRequest)
        
        let response = try await performRequest(request: request) as TokenRefreshResponse
        
        // Update stored tokens
        AuthManager.shared.storeTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            userId: AuthManager.shared.getUserId() ?? 0
        )
        
        return TokenPair(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: response.expiresAt,
            tokenType: "Bearer"
        )
    }
}

// Add request/response models
struct RefreshTokenRequest: Encodable {
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case tokenType = "token_type"
    }
}

struct TokenPair: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case tokenType = "token_type"
    }
} 