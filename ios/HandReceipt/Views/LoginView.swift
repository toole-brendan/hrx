import SwiftUI
import Foundation
import UIKit  // For haptic feedback
// Import our custom colors and styles directly by relative file path
// @_exported import class HandReceipt.AppColors
// @_exported import struct HandReceipt.PrimaryButtonStyle

// Make sure AppColors and styles are available
// Since they're in the same module, they should be accessible without explicit import

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var showingRegistration = false
    @State private var logoTapCount = 0
    @State private var lastTapTime = Date()
    
    // Callback invoked on successful login, passing the response
    // Used by the containing view/coordinator to navigate away.
    var onLoginSuccess: (LoginResponse) -> Void

    init(onLoginSuccess: @escaping (LoginResponse) -> Void) {
        self.onLoginSuccess = onLoginSuccess
        debugPrint("LoginView initialized")
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Black background to match web
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Logo and Header Section
                        VStack(spacing: 0) {
                            // Logo with tap gesture for dev login
                            ZStack {
                                Image("hr_logo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 350) // Approximate h-96 from web
                                    .onTapGesture {
                                        handleLogoTap()
                                    }
                                
                                // Dev login progress indicator
                                if logoTapCount > 0 && logoTapCount < 5 {
                                    Circle()
                                        .strokeBorder(Color.gray.opacity(0.2), lineWidth: 2)
                                        .frame(width: 200, height: 200)
                                        .scaleEffect(1 + (CGFloat(logoTapCount) * 0.05))
                                        .animation(.easeOut(duration: 0.2), value: logoTapCount)
                                    
                                    Text("\(logoTapCount)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.gray.opacity(0.5))
                                        .offset(y: -120)
                                }
                            }
                            .padding(.bottom, 16)
                            
                            Text("Military Supply Chain Management")
                                .font(.custom("DIN Alternate", size: 16))
                                .italic()
                                .foregroundColor(Color.gray)
                                .padding(.bottom, 24)
                        }
                        .padding(.top, 8)
                        
                        // Login Card
                        VStack(spacing: 0) {
                            // Card Header
                            VStack(spacing: 8) {
                                Text("Sign In")
                                    .font(.custom("DIN Alternate", size: 24))
                                    .foregroundColor(.white)
                                    .compatibleKerning(1.0)
                                
                                Text("Enter your credentials to access your account")
                                    .font(.custom("DIN Alternate", size: 14))
                                    .foregroundColor(Color.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 24)
                            
                            // Card Content
                            VStack(spacing: 16) {
                                // Username Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("USERNAME")
                                        .font(.custom("DIN Alternate", size: 11))
                                        .foregroundColor(Color(white: 0.8))
                                        .compatibleKerning(1.5)
                                    
                                    TextField("", text: $viewModel.username)
                                        .textFieldStyle(WebStyleTextField())
                                        .textContentType(.username)
                                        .keyboardType(.asciiCapable)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                
                                // Password Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("PASSWORD")
                                        .font(.custom("DIN Alternate", size: 11))
                                        .foregroundColor(Color(white: 0.8))
                                        .compatibleKerning(1.5)
                                    
                                    SecureField("", text: $viewModel.password)
                                        .textFieldStyle(WebStyleTextField())
                                        .textContentType(.password)
                                }
                                
                                // Error Message
                                if !errorMessage.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.red)
                                        
                                        Text(errorMessage)
                                            .font(.custom("DIN Alternate", size: 13))
                                            .foregroundColor(.red)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                
                                // Login Button
                                Button {
                                    viewModel.attemptLogin()
                                } label: {
                                    HStack(spacing: 8) {
                                        if case .loading = viewModel.loginState {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "arrow.right.circle.fill")
                                                .font(.system(size: 16))
                                        }
                                        
                                        Text("SIGN IN")
                                            .font(.custom("DIN Alternate", size: 11))
                                            .compatibleKerning(1.5)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .foregroundColor(.white)
                                    .background(Color(red: 59/255, green: 130/255, blue: 246/255).opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.clear, lineWidth: 0)
                                    )
                                }
                                .disabled(!viewModel.canAttemptLogin || viewModel.loginState == .loading)
                                .opacity((!viewModel.canAttemptLogin || viewModel.loginState == .loading) ? 0.6 : 1.0)
                                .onHover { isHovered in
                                    // This will only work on macOS/iPad with mouse
                                }
                            }
                            .padding(24)
                            
                            // Card Footer
                            VStack(spacing: 8) {
                                // Empty footer to match web design
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .background(Color(white: 0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color(white: 0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .onChange(of: viewModel.loginState) { newState in
                if case .success(let response) = newState {
                    debugPrint("LoginView: Login success - User: \(response.user.username)")
                    debugPrint("LoginView: User data - firstName: \(response.user.firstName ?? "nil"), lastName: \(response.user.lastName ?? "nil"), rank: \(response.user.rank)")
                    
                    // Update AuthManager with the login response
                    Task {
                        await AuthManager.shared.login(response: response)
                    }
                    
                    onLoginSuccess(response)
                }
            }
            .sheet(isPresented: $showingRegistration) {
                RegisterView()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // Helper to get the error message text from the state
    private var errorMessage: String {
        if case .failed(let message) = viewModel.loginState {
            return message
        } else {
            return ""
        }
    }
    
    // Handle logo tap for hidden dev login
    private func handleLogoTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        // Reset counter if more than 2 seconds since last tap
        if timeSinceLastTap > 2.0 {
            logoTapCount = 1
            debugPrint("Dev login: Starting new tap sequence")
        } else {
            logoTapCount += 1
            debugPrint("Dev login: Tap \(logoTapCount) of 5")
        }
        
        lastTapTime = now
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Trigger dev login after 5 taps
        if logoTapCount >= 5 {
            // Stronger haptic for success
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            performDevLogin()
            logoTapCount = 0
        }
    }
    
    // Perform development login bypass
    private func performDevLogin() {
        debugPrint("🔧 DEV LOGIN ACTIVATED! Using test credentials...")
        
        // Use test credentials to actually authenticate with the backend
        viewModel.username = "michael.rodriguez"
        viewModel.password = "password123"
        
        // Show a brief visual confirmation
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.loginState = .loading
        }
        
        // Perform actual login with test credentials
        Task {
            do {
                try await viewModel.performLogin()
                debugPrint("✅ Dev login successful via API!")
            } catch {
                debugPrint("❌ Dev login failed: \(error)")
                // Fallback to local mock if API fails in development
                #if DEBUG
                let mockUser = LoginResponse.User(
                    id: 999,
                    uuid: "dev-uuid",
                    username: "michael.rodriguez",
                    email: "michael.rodriguez@example.com",
                    firstName: "Michael",
                    lastName: "Rodriguez",
                    rank: "SSG",
                    unit: "Test Unit",
                    role: "user",
                    status: "active"
                )
                
                let mockResponse = LoginResponse(
                    accessToken: "dev-token-\(UUID().uuidString)",
                    refreshToken: "dev-refresh-token-\(UUID().uuidString)",
                    expiresAt: Date().addingTimeInterval(86400), // 24 hours from now
                    user: mockUser
                )
                
                viewModel.loginState = .success(mockResponse)
                onLoginSuccess(mockResponse)
                #endif
            }
        }
    }
}

// Web-style text field matching the web module's input styling
struct WebStyleTextField: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.custom("DIN Alternate", size: 15))
            .foregroundColor(Color(white: 0.1))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(white: 0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color(white: 0.6), lineWidth: 1)
            )
    }
}

// --- Preview --- 
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView { loginResponse in
            debugPrint("Preview Login Success: User \(loginResponse.user.username)")
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        LoginView { _ in }
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
    }
} 