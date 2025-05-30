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