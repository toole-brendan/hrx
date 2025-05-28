import SwiftUI
import Foundation
// Import our custom colors and styles directly by relative file path
// @_exported import class HandReceipt.AppColors
// @_exported import struct HandReceipt.PrimaryButtonStyle

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    
    // Callback invoked on successful login, passing the response
    // Used by the containing view/coordinator to navigate away.
    var onLoginSuccess: (LoginResponse) -> Void

    init(onLoginSuccess: @escaping (LoginResponse) -> Void) {
        self.onLoginSuccess = onLoginSuccess
        debugPrint("LoginView initialized")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerView
                
                inputFieldsView
                
                errorMessageView
                
                #if DEBUG
                debugInfoView
                #endif
                
                loginButtonView
                
                Spacer()
            }
            .standardContainerPadding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.appBackground.ignoresSafeArea())
            .navigationTitle("Login")
            .navigationBarHidden(true)
            .onChange(of: viewModel.loginState) { newState in
                debugPrint("LoginView: Login state changed to \(String(describing: newState))")
                if case .success(let response) = newState {
                    debugPrint("LoginView: Login successful for user: \(response.user.username)")
                    onLoginSuccess(response)
                }
            }
            .onAppear {
                debugPrint("LoginView appeared")
            }
            .onDisappear {
                debugPrint("LoginView disappeared")
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack {
            // Replicate the web sidebar logo style
            Text("HandReceipt")
                .font(.custom("Georgia", size: 20)) // Use Georgia font, adjust size as needed
                .fontWeight(.light) // Use light weight if available, otherwise regular
                .kerning(3.0) // Add letter spacing (kerning), adjust value for desired 'widest' look
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 16) // Approximate px-4
                .padding(.vertical, 6)   // Approximate py-1.5
                .overlay(
                    // Add the border matching the web style (using primary text with opacity)
                    Rectangle() // Use sharp rectangle, not rounded
                        .stroke(AppColors.primaryText.opacity(0.7), lineWidth: 1)
                )
        }
        .frame(height: 150) // Keep existing frame or adjust as needed
    }
    
    private var inputFieldsView: some View {
        VStack(spacing: 15) {
            TextField("Username", text: $viewModel.username)
                .textFieldStyle(.industrial)
                .textContentType(.username)
                .keyboardType(.asciiCapable)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: viewModel.username) { newValue in
                    debugPrint("Username changed: \(newValue.isEmpty ? "[empty]" : "[has value]")")
                }
            
            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.industrial)
                .textContentType(.password)
                .onChange(of: viewModel.password) { newValue in
                    debugPrint("Password changed: \(newValue.isEmpty ? "[empty]" : "[has value]")")
                }
        }
    }
    
    private var errorMessageView: some View {
        HStack(spacing: 5) {
            if !errorMessage.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                   .foregroundColor(AppColors.destructive)
            }
            Text(errorMessage)
                .font(AppFonts.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.destructive)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 25)
        .opacity(errorMessage.isEmpty ? 0 : 1)
    }
    
    #if DEBUG
    private var debugInfoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DEBUG INFO")
                .font(AppFonts.captionBold)
                .foregroundColor(AppColors.accent)
            
            Text("Login State: \(String(describing: viewModel.loginState))")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
            
            Text("Can Login: \(viewModel.canAttemptLogin ? "Yes" : "No")")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
            
            HStack {
                Button("Debug: Quick Login") {
                    debugPrint("Debug: Using quick login")
                    viewModel.username = "testuser"
                    viewModel.password = "password"
                }
                .font(AppFonts.captionBold)
                .padding(4)
                .background(AppColors.accent.opacity(0.3))
                .foregroundColor(AppColors.primaryText)
                .cornerRadius(4)
                
                Button("Simulate Success") {
                    debugPrint("Debug: Simulating login success")
                    viewModel.simulateLoginSuccess()
                }
                .font(AppFonts.captionBold)
                .padding(4)
                .background(Color.green.opacity(0.3))
                .foregroundColor(AppColors.primaryText)
                .cornerRadius(4)
                
                Button("Simulate Error") {
                    debugPrint("Debug: Simulating login error")
                    viewModel.simulateLoginError("Debug simulated error")
                }
                .font(AppFonts.captionBold)
                .padding(4)
                .background(AppColors.destructive.opacity(0.3))
                .foregroundColor(AppColors.primaryText)
                .cornerRadius(4)
            }
        }
        .padding(8)
        .background(AppColors.secondaryBackground)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(AppColors.secondaryText.opacity(0.3), lineWidth: 1)
        )
    }
    #endif
    
    private var loginButtonView: some View {
        Button {
            debugPrint("Login button tapped - attempting login")
            viewModel.attemptLogin()
        } label: {
            ZStack {
                Text("Login")
                    .opacity(viewModel.loginState == .loading ? 0 : 1)
                
                if case .loading = viewModel.loginState {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                        .frame(height: 20)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 20)
        }
        .buttonStyle(.primary)
        .disabled(!viewModel.canAttemptLogin || viewModel.loginState == .loading)
        .padding(.top, 10)
    }
    
    // Helper to get the error message text from the state
    private var errorMessage: String {
        if case .failed(let message) = viewModel.loginState {
            return message
        } else {
            return "" // Return empty string when no error
        }
    }
}

// --- Preview --- 
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView { loginResponse in
            debugPrint("Preview Login Success: User \(loginResponse.user.username)")
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Idle State - Dark")

        LoginView { _ in }
            .onAppear {
                let viewModel = LoginViewModel()
                viewModel.loginState = .loading
            }
             .preferredColorScheme(.dark)
            .previewDisplayName("Loading State - Dark")
    }
} 