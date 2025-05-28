import Foundation
import Combine

// Enum for Login State
enum LoginState: Equatable {
    case idle
    case loading
    case success(LoginResponse) // Include response on success
    case failed(String) // Include error message on failure
    
    // Add Equatable conformance
    static func == (lhs: LoginState, rhs: LoginState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.success(let lResponse), .success(let rResponse)): 
            return lResponse.userId == rResponse.userId && lResponse.user.username == rResponse.user.username
        case (.failed(let lMessage), .failed(let rMessage)): 
            return lMessage == rMessage
        default: return false
        }
    }
}

@MainActor
class LoginViewModel: ObservableObject {
    // --- State --- 
    @Published var username = ""
    @Published var password = ""
    @Published var loginState: LoginState = .idle
    @Published var canAttemptLogin = false // Computed based on inputs

    // --- Dependencies --- 
    private let apiService: APIServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
        debugPrint("LoginViewModel initialized with API service: \(type(of: apiService))")
        setupValidation()
    }

    // --- Validation --- 
    private func setupValidation() {
        debugPrint("Setting up validation publishers")
        // Combine publisher to check if both fields are non-empty
        Publishers.CombineLatest($username, $password)
            .map { username, password -> Bool in
                let canLogin = !username.trimmingCharacters(in: .whitespaces).isEmpty && 
                       !password.isEmpty // Passwords usually aren't trimmed
                debugPrint("Validation state updated: canLogin = \(canLogin)")
                return canLogin
            }
            .assign(to: &$canAttemptLogin)

        // Reset login state if inputs change after a failed/success attempt
         Publishers.CombineLatest($username, $password)
             .dropFirst() // Ignore initial state
            .sink { [weak self] username, password in
                 guard let self = self else { return }
                 
                 // Debug values without exposing actual text
                 debugPrint("Input changed: username \(username.isEmpty ? "empty" : "has value"), password \(password.isEmpty ? "empty" : "has value")")
                 
                 if case .failed(let message) = self.loginState {
                     debugPrint("Resetting login state from failed(\(message)) to idle due to input change")
                     self.loginState = .idle
                 }
                 if case .success = self.loginState {
                     debugPrint("Resetting login state from success to idle due to input change")
                     self.loginState = .idle
                 }
             }
             .store(in: &cancellables)
    }

    // --- Actions --- 
    func attemptLogin() {
        guard canAttemptLogin else {
            debugPrint("LoginViewModel: Login attempt blocked - validation failed")
            return
        }
        
        // Check if we're already in a loading state
        if case .loading = loginState {
            debugPrint("LoginViewModel: Login attempt blocked - already in loading state")
            return // Prevent concurrent attempts
        }
        
        loginState = .loading
        debugPrint("LoginViewModel: Login state set to loading")
        
        let credentials = LoginCredentials(
            username: username.trimmingCharacters(in: .whitespaces),
            password: password // Send password as entered
        )
        
        debugPrint("LoginViewModel: Attempting login for user: \(credentials.username)")

        Task {
            do {
                debugPrint("LoginViewModel: Calling API service login method")
                let response = try await apiService.login(credentials: credentials)
                // Login successful! Cookie should be stored by URLSession.
                debugPrint("LoginViewModel: Login Successful: User \(response.user.username) (ID: \(response.userId))")
                self.loginState = .success(response)
                debugPrint("LoginViewModel: Login state updated to success")
                // The View should observe this state change and navigate
            } catch let apiError as APIService.APIError {
                debugPrint("LoginViewModel: Login API Error: \(apiError.localizedDescription)")
                let errorMessage: String
                switch apiError {
                    case .unauthorized: 
                        errorMessage = "Invalid username or password."
                        debugPrint("LoginViewModel: Unauthorized error - invalid credentials")
                    case .networkError(let error): 
                        errorMessage = "Network error. Please check connection."
                        debugPrint("LoginViewModel: Network error details: \(error)")
                    case .serverError(let statusCode, let message):
                        errorMessage = "Server error (\(statusCode)): \(message ?? "Unknown server error")"
                        debugPrint("LoginViewModel: Server error \(statusCode): \(message ?? "nil")")
                    default: 
                        errorMessage = apiError.localizedDescription
                        debugPrint("LoginViewModel: Other API error: \(apiError)")
                }
                self.loginState = .failed(errorMessage)
                debugPrint("LoginViewModel: Login state updated to failed: \(errorMessage)")
            } catch {
                debugPrint("LoginViewModel: Login Unknown Error: \(error)")
                debugPrint("LoginViewModel: Error type: \(type(of: error))")
                self.loginState = .failed("An unexpected error occurred during login.")
                debugPrint("LoginViewModel: Login state updated to failed with generic message")
            }
        }
    }
    
    // --- Debug/Testing methods ---
    
    #if DEBUG
    /// Simulates a successful login (for debugging/testing)
    func simulateLoginSuccess() {
        debugPrint("LoginViewModel: Simulating successful login")
        
        // Create a JSON representation of our response
        let mockResponseData = """
        {
            "token": "mock_token_string",
            "user": {
                "id": 12345,
                "username": "test_user",
                "name": "Test User",
                "rank": "TST"
            }
        }
        """.data(using: .utf8)!
        
        do {
            // Decode it using the standard decoder
            let mockResponse = try JSONDecoder().decode(LoginResponse.self, from: mockResponseData)
            self.loginState = .success(mockResponse)
            debugPrint("LoginViewModel: Set mock success state with user: \(mockResponse.user.username)")
        } catch {
            debugPrint("LoginViewModel: Failed to create mock response: \(error)")
            self.loginState = .failed("Failed to create mock response")
        }
    }
    
    /// Simulates a login error (for debugging/testing)
    func simulateLoginError(_ message: String = "Simulated error") {
        debugPrint("LoginViewModel: Simulating login error")
        self.loginState = .failed(message)
        debugPrint("LoginViewModel: Set mock error state with message: \(message)")
    }
    
    /// Simulates loading state (for debugging/testing UI)
    func simulateLoading() {
        debugPrint("LoginViewModel: Simulating loading state")
        self.loginState = .loading
    }
    #endif
} 