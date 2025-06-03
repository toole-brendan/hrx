import SwiftUI
import Foundation
import UIKit
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
    @State private var isAnimatingLogo = false
    
    // Callback invoked on successful login, passing the response
    // Used by the containing view/coordinator to navigate away.
    var onLoginSuccess: (LoginResponse) -> Void

    init(onLoginSuccess: @escaping (LoginResponse) -> Void) {
        self.onLoginSuccess = onLoginSuccess
        debugPrint("LoginView initialized")
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background with subtle geometric pattern
                    AppColors.appBackground
                        .ignoresSafeArea()
                    
                    // Subtle geometric pattern overlay
                    GeometricPatternBackground()
                        .opacity(0.03)
                        .ignoresSafeArea()
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Logo section - maintaining original size
                            VStack(spacing: 0) {
                                // Full logo at original size
                                ZStack {
                                    Image("hr_logo4")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 200) // Original size maintained
                                        .scaleEffect(isAnimatingLogo ? 1.05 : 1.0)
                                        .onTapGesture {
                                            handleLogoTap()
                                        }
                                    
                                    // Dev login progress indicator overlay
                                    if logoTapCount > 0 && logoTapCount < 5 {
                                        VStack {
                                            Spacer()
                                            HStack(spacing: 4) {
                                                ForEach(0..<5) { index in
                                                    Circle()
                                                        .fill(index < logoTapCount ? AppColors.primaryText : AppColors.border)
                                                        .frame(width: 6, height: 6)
                                                }
                                            }
                                            .padding(.bottom, 20)
                                        }
                                        .frame(height: 200)
                                    }
                                }
                                
                                Text("Property Management System")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.secondaryText)
                                    .padding(.top, -24)
                            }
                            .padding(.top, geometry.safeAreaInsets.top - 30)
                            .padding(.bottom, 40)
                            
                            // Main content - no container
                            VStack(alignment: .leading, spacing: 20) {
                                // Header section
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Welcome Back")
                                        .font(AppFonts.serifHero)
                                        .foregroundColor(AppColors.primaryText)
                                    
                                    Text("Sign in to continue")
                                        .font(AppFonts.body)
                                        .foregroundColor(AppColors.tertiaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Form fields with tighter spacing
                                VStack(spacing: 16) {
                                    UnderlinedTextField(
                                        label: "Username",
                                        text: $viewModel.username,
                                        placeholder: "Enter your username",
                                        textContentType: .username,
                                        keyboardType: .asciiCapable,
                                        autocapitalization: .none
                                    )
                                    
                                    UnderlinedSecureField(
                                        label: "Password",
                                        text: $viewModel.password,
                                        placeholder: "Enter your password",
                                        textContentType: .password
                                    )
                                }
                                
                                // Error message with subtle animation
                                if !errorMessage.isEmpty {
                                    HStack(spacing: 12) {
                                        Image(systemName: "exclamationmark.circle")
                                            .font(.system(size: 16, weight: .light))
                                            .foregroundColor(AppColors.destructive)
                                        
                                        Text(errorMessage)
                                            .font(AppFonts.body)
                                            .foregroundColor(AppColors.destructive)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .top)),
                                        removal: .opacity
                                    ))
                                    .padding(.top, -12)
                                }
                                
                                // Sign in button
                                MinimalLoadingButton(
                                    isLoading: viewModel.loginState == .loading,
                                    title: "Sign In",
                                    icon: "arrow.right",
                                    action: { viewModel.attemptLogin() }
                                )
                                .disabled(!viewModel.canAttemptLogin)
                                
                                // Registration link section
                                VStack(spacing: 4) {
                                    Text("Don't have an account?")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.tertiaryText)
                                    
                                    Button("Create one") {
                                        showingRegistration = true
                                    }
                                    .buttonStyle(TextLinkButtonStyle())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 12)
                            }
                            .padding(.horizontal, 48) // Generous side margins
                            .padding(.bottom, 24)
                        }
                        .animation(.easeInOut(duration: 0.3), value: errorMessage)
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
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
        
        if timeSinceLastTap > 2.0 {
            logoTapCount = 1
            debugPrint("Dev login: Starting new tap sequence")
        } else {
            logoTapCount += 1
            debugPrint("Dev login: Tap \(logoTapCount) of 5")
        }
        
        lastTapTime = now
        
        // Animate logo
        withAnimation(.easeInOut(duration: 0.2)) {
            isAnimatingLogo = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isAnimatingLogo = false
            }
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if logoTapCount >= 5 {
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
// MARK: - Auth Components
// Note: Auth components are defined in AuthComponents.swift



// MARK: - Preview
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView { loginResponse in
            debugPrint("Preview Login Success: User \(loginResponse.user.username)")
        }
        .previewDisplayName("8VC Style Login")
    }
} 