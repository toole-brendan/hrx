import Foundation
import KeychainSwift
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    private let keychain = KeychainSwift()
    
    // Published properties for reactive UI updates
    @Published var isAuthenticated = false
    @Published var currentUser: LoginResponse.User?
    
    // Keychain keys
    private let accessTokenKey = "handreceipt_access_token"
    private let refreshTokenKey = "handreceipt_refresh_token"
    private let userIdKey = "handreceipt_user_id"
    
    // UserDefaults key for user data persistence
    private let userDataKey = "com.handreceipt.userData"
    
    private init() {
        // Configure keychain
        keychain.synchronizable = false
        
        // Load persisted user data on init
        loadPersistedUser()
    }
    
    // MARK: - Public Methods
    
    // Update login to handle user data
    func login(response: LoginResponse) async {
        // Store tokens
        if let accessToken = response.accessToken {
            keychain.set(accessToken, forKey: accessTokenKey)
        }
        if let refreshToken = response.refreshToken {
            keychain.set(refreshToken, forKey: refreshTokenKey)
        }
        keychain.set(String(response.user.id), forKey: userIdKey)
        
        // Update user state on main thread
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }
        
        // Persist user data
        persistUser(response.user)
        
        debugPrint("Stored authentication tokens and user data for user: \(response.user.id)")
    }
    
    // Store tokens after successful login (legacy method for compatibility)
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
    
    // Logout
    func logout() async {
        // Update state on main thread
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
        
        // Clear persisted data
        clearPersistedData()
        
        debugPrint("User logged out and data cleared")
    }
    
    // Clear all tokens (logout) - legacy method
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
    
    // Check auth status on app launch
    func checkAuthStatus() async {
        // Check if we have a valid token
        guard getAccessToken() != nil else {
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
            }
            return
        }
        
        // If we have persisted user data, use it temporarily
        if let user = loadPersistedUserData() {
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
            }
        }
        
        // Verify the token with the backend
        do {
            let apiService = APIService()
            let loginResponse = try await apiService.checkSession()
            
            // Token is valid, update user data
            await MainActor.run {
                self.currentUser = loginResponse.user
                self.isAuthenticated = true
            }
            persistUser(loginResponse.user)
            
        } catch {
            // Token is invalid, clear everything
            debugPrint("Token verification failed: \(error)")
            await logout()
        }
    }
    
    // MARK: - Debug Methods
    
    #if DEBUG
    func clearAllStoredCredentials() async {
        await logout()
        debugPrint("DEBUG: All stored credentials cleared")
    }
    #endif
    
    // MARK: - Persistence Methods
    
    private func persistUser(_ user: LoginResponse.User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userDataKey)
        }
    }
    
    private func loadPersistedUser() {
        if let user = loadPersistedUserData() {
            self.currentUser = user
            // Note: Don't set isAuthenticated here, wait for checkAuthStatus
        }
    }
    
    private func loadPersistedUserData() -> LoginResponse.User? {
        guard let data = UserDefaults.standard.data(forKey: userDataKey),
              let user = try? JSONDecoder().decode(LoginResponse.User.self, from: data) else {
            return nil
        }
        return user
    }
    
    private func clearPersistedData() {
        // Clear keychain
        keychain.delete(accessTokenKey)
        keychain.delete(refreshTokenKey)
        keychain.delete(userIdKey)
        
        // Clear user data
        UserDefaults.standard.removeObject(forKey: userDataKey)
        
        // Clear cookies
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
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