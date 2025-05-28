import Foundation
import Combine

@MainActor // Ensure UI updates happen on the main thread
class AuthViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isAuthenticated: Bool = false // Tracks if a user is logged in
    @Published var currentUser: LoginResponse? = nil // Holds logged-in user details (adjust LoginResponse if needed)
    @Published var isLoading: Bool = false // Indicates if an auth operation is in progress
    @Published var errorMessage: String? = nil // Holds error messages for UI display

    // MARK: - Dependencies

    private let apiService: APIServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
        checkExistingSession() // Check for session on initialization
    }
    
    // Convenience initializer for direct login state
    init(currentUser: LoginResponse?, logoutCallback: (() -> Void)? = nil, apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
        self.currentUser = currentUser
        self.isAuthenticated = currentUser != nil
        
        // Store the logout callback if provided
        if let callback = logoutCallback {
            self.logoutCallback = callback
        }
    }
    
    // Optional logout callback that can be set by parent views
    private var logoutCallback: (() -> Void)?

    // MARK: - Authentication Actions

    /// Checks if a valid session exists on the server.
    func checkExistingSession() {
        isLoading = true
        errorMessage = nil
        print("AuthViewModel: Checking existing session...")

        Task {
            do {
                let user = try await apiService.checkSession()
                self.currentUser = user
                self.isAuthenticated = true
                print("AuthViewModel: Session valid for user \(user.user.username)")
            } catch let apiError as APIService.APIError where apiError == .unauthorized {
                print("AuthViewModel: No valid session found or session expired.")
                self.currentUser = nil
                self.isAuthenticated = false
                // Optionally clear cookies explicitly if needed, though URLSession usually handles expiry
                // clearCookies()
            } catch {
                print("AuthViewModel: Error checking session - \(error.localizedDescription)")
                self.currentUser = nil
                self.isAuthenticated = false
                self.errorMessage = "Failed to verify session. Please log in."
                // Optionally clear cookies explicitly on other errors too
                // clearCookies()
            }
            isLoading = false
        }
    }

    /// Handles successful login notification from LoginViewModel.
    func handleLoginSuccess(user: LoginResponse) {
        self.currentUser = user
        self.isAuthenticated = true
        self.errorMessage = nil
        print("AuthViewModel: User \(user.user.username) logged in.")
    }

    /// Logs the current user out.
    func logout() {
        isLoading = true
        errorMessage = nil
        print("AuthViewModel: Initiating logout for user \(currentUser?.user.username ?? "unknown")")

        Task {
            do {
                // Call the APIService's logout function
                try await apiService.logout()
                print("AuthViewModel: Logout API call successful.")

                // Clear local state regardless of API call success/failure for immediate UI update
                self.currentUser = nil
                self.isAuthenticated = false
                // Explicitly clear cookies related to the session
                clearCookies()
                print("AuthViewModel: Local state cleared, user logged out.")

                // Call the logout callback if it's set
                DispatchQueue.main.async {
                    self.logoutCallback?()
                }

            } catch {
                // Even if API logout fails, log the error but still log the user out locally
                print("AuthViewModel: Error calling logout API - \(error.localizedDescription). Still logging out locally.")
                self.currentUser = nil
                self.isAuthenticated = false
                clearCookies() // Ensure cookies are cleared even on error
                self.errorMessage = "Logout failed on server, but logged out locally."
                
                // Call the logout callback if it's set, even on error
                DispatchQueue.main.async {
                    self.logoutCallback?()
                }
            }
            isLoading = false
        }
    }

    // MARK: - Cookie Management (Optional but Recommended)

    /// Clears cookies associated with the backend domain.
    private func clearCookies() {
        guard let url = URL(string: apiService.baseURLString) else { // Assuming APIService exposes baseURLString
             print("AuthViewModel: Warning - Could not get base URL to clear cookies.")
            return
        }
        
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for cookie in cookies {
                 print("AuthViewModel: Deleting cookie \(cookie.name) for domain \(cookie.domain)")
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        } else {
             print("AuthViewModel: No cookies found for \(url.absoluteString) to clear.")
        }
    }
} 