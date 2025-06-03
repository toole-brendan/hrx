import SwiftUI
import Foundation
import UIKit

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var showingRegistration = false
    @State private var logoTapCount = 0
    @State private var lastTapTime = Date()
    @State private var isAnimatingLogo = false
    
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
                                    
                                    // Dev login progress indicator
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
                                    .padding(.top, 24)
                                
                                // Dev login indicator
                                if logoTapCount > 0 && logoTapCount < 5 {
                                    HStack(spacing: 4) {
                                        ForEach(0..<5) { index in
                                            Circle()
                                                .fill(index < logoTapCount ? AppColors.primaryText : AppColors.border)
                                                .frame(width: 6, height: 6)
                                        }
                                    }
                                    .transition(.opacity)
                                }
                            }
                            .padding(.top, geometry.safeAreaInsets.top + 60)
                            .padding(.bottom, 60)
                            
                            // Main content - no container
                            VStack(alignment: .leading, spacing: 48) {
                                // Header section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Welcome Back")
                                        .font(AppFonts.serifHero)
                                        .foregroundColor(AppColors.primaryText)
                                    
                                    Text("Sign in to continue")
                                        .font(AppFonts.body)
                                        .foregroundColor(AppColors.tertiaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Form fields with generous spacing
                                VStack(spacing: 36) {
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
                                    .padding(.top, -20)
                                }
                                
                                // Sign in button
                                MinimalLoadingButton(
                                    isLoading: viewModel.loginState == .loading,
                                    title: "Sign In",
                                    icon: "arrow.right",
                                    action: { viewModel.attemptLogin() }
                                )
                                .disabled(!viewModel.canAttemptLogin)
                                .padding(.top, 8)
                                
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
                                .padding(.top, 32)
                            }
                            .padding(.horizontal, 48) // Generous side margins
                            .padding(.bottom, 80)
                        }
                        .animation(.easeInOut(duration: 0.3), value: errorMessage)
                    }
                }
            }
            .navigationBarHidden(true)
            .onChange(of: viewModel.loginState) { newState in
                if case .success(let response) = newState {
                    debugPrint("LoginView: Login success - User: \(response.user.username)")
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
    
    private var errorMessage: String {
        if case .failed(let message) = viewModel.loginState {
            return message
        } else {
            return ""
        }
    }
    
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
    
    private func performDevLogin() {
        debugPrint("🔧 DEV LOGIN ACTIVATED! Using test credentials...")
        
        viewModel.username = "michael.rodriguez"
        viewModel.password = "password123"
        
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.loginState = .loading
        }
        
        Task {
            do {
                try await viewModel.performLogin()
                debugPrint("✅ Dev login successful via API!")
            } catch {
                debugPrint("❌ Dev login failed: \(error)")
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
                    expiresAt: Date().addingTimeInterval(86400),
                    user: mockUser
                )
                
                viewModel.loginState = .success(mockResponse)
                onLoginSuccess(mockResponse)
                #endif
            }
        }
    }
}

// MARK: - Custom Components

struct UnderlinedTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var textContentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .sentences
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(isFocused ? AppColors.primaryText : AppColors.tertiaryText)
                .kerning(AppFonts.wideKerning)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            TextField(placeholder, text: $text)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .tint(AppColors.accent)
                .textFieldStyle(PlainTextFieldStyle())
                .textContentType(textContentType)
                .keyboardType(keyboardType)
                .autocapitalization(autocapitalization)
                .disableAutocorrection(true)
                .focused($isFocused)
                .padding(.vertical, 8)
            
            Rectangle()
                .fill(isFocused ? AppColors.primaryText : AppColors.border)
                .frame(height: isFocused ? 2 : 1)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

struct UnderlinedSecureField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var textContentType: UITextContentType? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(isFocused ? AppColors.primaryText : AppColors.tertiaryText)
                .kerning(AppFonts.wideKerning)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            SecureField(placeholder, text: $text)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .tint(AppColors.accent)
                .textFieldStyle(PlainTextFieldStyle())
                .textContentType(textContentType)
                .focused($isFocused)
                .padding(.vertical, 8)
            
            Rectangle()
                .fill(isFocused ? AppColors.primaryText : AppColors.border)
                .frame(height: isFocused ? 2 : 1)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

struct MinimalLoadingButton: View {
    let isLoading: Bool
    let title: String
    let icon: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    // Minimal three dots loading animation
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                                .scaleEffect(isLoading ? 1 : 0.3)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: isLoading
                                )
                        }
                    }
                } else {
                    Text(title)
                        .font(AppFonts.bodyMedium)
                    
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .regular))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(MinimalPrimaryButtonStyle())
        .disabled(isLoading)
    }
}

struct GeometricPatternBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Create subtle geometric pattern inspired by 8VC
                let spacing: CGFloat = 120
                let lineWidth: CGFloat = 0.5
                
                // Draw grid of subtle lines
                for x in stride(from: 0, to: size.width, by: spacing) {
                    for y in stride(from: 0, to: size.height, by: spacing) {
                        // Draw subtle square
                        let rect = CGRect(x: x, y: y, width: spacing * 0.6, height: spacing * 0.6)
                        context.stroke(
                            Path(rect),
                            with: .color(AppColors.border.opacity(0.5)),
                            lineWidth: lineWidth
                        )
                        
                        // Add inner square for depth
                        let innerRect = CGRect(x: x + 20, y: y + 20, width: spacing * 0.3, height: spacing * 0.3)
                        context.stroke(
                            Path(innerRect),
                            with: .color(AppColors.border.opacity(0.3)),
                            lineWidth: lineWidth
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView { loginResponse in
            debugPrint("Preview Login Success: User \(loginResponse.user.username)")
        }
        .previewDisplayName("8VC Style Login")
    }
}