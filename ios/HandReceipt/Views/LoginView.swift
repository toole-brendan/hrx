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
                // Background
                AppColors.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Logo and Header Section
                        VStack(spacing: 24) {
                            // Military Icon
                            ZStack {
                                Circle()
                                    .fill(AppColors.military)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: AppColors.military.opacity(0.3), radius: 10, x: 0, y: 4)
                                
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundColor(AppColors.primaryText)
                                
                                // Dev login progress indicator
                                if logoTapCount > 0 && logoTapCount < 5 {
                                    Circle()
                                        .strokeBorder(AppColors.primaryText.opacity(0.3), lineWidth: 2)
                                        .frame(width: 90, height: 90)
                                        .overlay(
                                            Text("\(logoTapCount)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(AppColors.primaryText.opacity(0.5))
                                                .offset(x: 35, y: -35)
                                        )
                                        .animation(.easeInOut(duration: 0.2), value: logoTapCount)
                                }
                            }
                            .onTapGesture {
                                handleLogoTap()
                            }
                            
                            VStack(spacing: 8) {
                                Text("HandReceipt")
                                    .font(.custom("Georgia", size: 32))
                                    .fontWeight(.light)
                                    .compatibleKerning(3.0)
                                    .foregroundColor(AppColors.primaryText)
                                
                                Text("Military Supply Chain Management")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                    .compatibleKerning(1.0)
                                    .textCase(.uppercase)
                            }
                        }
                        .padding(.top, 60)
                        .padding(.bottom, 48)
                        
                        // Login Card
                        VStack(spacing: 0) {
                            // Card Header
                            VStack(spacing: 4) {
                                Text("SIGN IN")
                                    .font(AppFonts.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.primaryText)
                                    .compatibleKerning(1.5)
                                
                                Text("Enter your credentials to access your account")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .padding(.horizontal, 24)
                            .background(AppColors.secondaryBackground)
                            
                            // Divider
                            Rectangle()
                                .fill(AppColors.border)
                                .frame(height: 1)
                            
                            // Card Content
                            VStack(spacing: 20) {
                                // Input Fields
                                VStack(spacing: 16) {
                                    // Username Field
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("USERNAME")
                                            .font(AppFonts.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppColors.secondaryText)
                                            .compatibleKerning(0.5)
                                        
                                        TextField("john.doe", text: $viewModel.username)
                                            .textFieldStyle(MaterialTextFieldStyle())
                                            .textContentType(.username)
                                            .keyboardType(.asciiCapable)
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                    }
                                    
                                    // Password Field
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("PASSWORD")
                                            .font(AppFonts.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppColors.secondaryText)
                                            .compatibleKerning(0.5)
                                        
                                        SecureField("••••••••", text: $viewModel.password)
                                            .textFieldStyle(MaterialTextFieldStyle())
                                            .textContentType(.password)
                                    }
                                }
                                
                                // Error Message
                                if !errorMessage.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.destructive)
                                        
                                        Text(errorMessage)
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.destructive)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(AppColors.destructive.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(AppColors.destructive.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                
                                // Login Button
                                Button {
                                    viewModel.attemptLogin()
                                } label: {
                                    HStack(spacing: 8) {
                                        if case .loading = viewModel.loginState {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "arrow.right.circle.fill")
                                                .font(.system(size: 18))
                                        }
                                        
                                        Text("SIGN IN")
                                            .font(AppFonts.subheadline)
                                            .fontWeight(.medium)
                                            .compatibleKerning(1.0)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .foregroundColor(AppColors.primaryText)
                                    .background(AppColors.military)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(AppColors.military, lineWidth: 1)
                                    )
                                }
                                .disabled(!viewModel.canAttemptLogin || viewModel.loginState == .loading)
                                .opacity((!viewModel.canAttemptLogin || viewModel.loginState == .loading) ? 0.6 : 1.0)
                                
                                #if DEBUG
                                // Debug Controls
                                VStack(spacing: 12) {
                                    Divider()
                                        .background(AppColors.border)
                                    
                                    Text("DEBUG CONTROLS")
                                        .font(AppFonts.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.accent)
                                        .compatibleKerning(0.5)
                                    
                                    HStack(spacing: 8) {
                                        Button("Quick Fill") {
                                            viewModel.username = "testuser"
                                            viewModel.password = "password"
                                        }
                                        .buttonStyle(DebugButtonStyle())
                                        
                                        Button("Success") {
                                            viewModel.simulateLoginSuccess()
                                        }
                                        .buttonStyle(DebugButtonStyle(color: .green))
                                        
                                        Button("Error") {
                                            viewModel.simulateLoginError("Debug error")
                                        }
                                        .buttonStyle(DebugButtonStyle(color: AppColors.destructive))
                                    }
                                }
                                .padding(.top, 8)
                                #endif
                            }
                            .padding(24)
                            .background(AppColors.tertiaryBackground)
                            
                            // Card Footer
                            VStack(spacing: 16) {
                                Button {
                                    showingRegistration = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Don't have an account?")
                                            .foregroundColor(AppColors.secondaryText)
                                        
                                        Text("Create Account")
                                            .foregroundColor(AppColors.military)
                                            .fontWeight(.medium)
                                    }
                                    .font(AppFonts.caption)
                                }
                                
                                Text("This is a secure Department of Defense system.\nUnauthorized access is prohibited.")
                                    .font(AppFonts.caption2)
                                    .foregroundColor(AppColors.tertiaryText)
                                    .multilineTextAlignment(.center)
                                    .compatibleKerning(0.3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(AppColors.secondaryBackground)
                            
                            // Bottom border
                            Rectangle()
                                .fill(AppColors.border)
                                .frame(height: 1)
                        }
                        .background(AppColors.tertiaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .onChange(of: viewModel.loginState) { newState in
                if case .success(let response) = newState {
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
            return "" // Return empty string when no error
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
        debugPrint("🔧 DEV LOGIN ACTIVATED! Bypassing authentication...")
        
        // Create a mock user using the nested User type from LoginResponse
        let mockUser = LoginResponse.User(
            id: 999,
            username: "dev_user",
            name: "Developer",
            rank: "DEV",
            lastName: "User"
        )
        
        let mockResponse = LoginResponse(
            token: "dev-token-\(UUID().uuidString)",
            user: mockUser
        )
        
        // Show a brief visual confirmation
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.loginState = .success(mockResponse)
        }
        
        // Trigger the success callback after a short delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onLoginSuccess(mockResponse)
        }
        
        #if DEBUG
        // In debug builds, also show an alert or some visual feedback
        debugPrint("✅ Dev login successful! User: \(mockUser.username)")
        #endif
    }
}

// Material-style text field
struct MaterialTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(AppFonts.body)
            .foregroundColor(AppColors.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.secondaryBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}

// Debug button style
struct DebugButtonStyle: ButtonStyle {
    let color: Color
    
    init(color: Color = AppColors.accent) {
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.caption2.weight(.medium))
            .foregroundColor(AppColors.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(configuration.isPressed ? 0.3 : 0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
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