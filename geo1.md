import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = RegisterViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedRank = ""
    @State private var unit = ""
    @State private var showingLogin = false
    
    let militaryRanks = [
        "PVT", "PV2", "PFC", "SPC", "CPL", "SGT", "SSG", "SFC", "MSG", "1SG", "SGM",
        "2LT", "1LT", "CPT", "MAJ", "LTC", "COL", "BG", "MG", "LTG", "GEN"
    ]
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    AppColors.appBackground
                        .ignoresSafeArea()
                    
                    // Subtle geometric pattern
                    GeometricPatternBackground()
                        .opacity(0.03)
                        .ignoresSafeArea()
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Custom navigation bar
                            HStack {
                                MinimalBackButton(label: "Back") {
                                    dismiss()
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 48)
                            .padding(.top, geometry.safeAreaInsets.top + 20)
                            .padding(.bottom, 40)
                            
                            // Main content
                            VStack(alignment: .leading, spacing: 56) {
                                // Header
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Create Account")
                                        .font(AppFonts.serifTitle)
                                        .foregroundColor(AppColors.primaryText)
                                    
                                    Text("Join the property management system")
                                        .font(AppFonts.body)
                                        .foregroundColor(AppColors.tertiaryText)
                                }
                                
                                // Personal Information Section
                                VStack(alignment: .leading, spacing: 24) {
                                    SectionHeader(title: "Personal Information")
                                    
                                    HStack(spacing: 24) {
                                        UnderlinedTextField(
                                            label: "First Name",
                                            text: $firstName,
                                            placeholder: "John",
                                            textContentType: .givenName
                                        )
                                        
                                        UnderlinedTextField(
                                            label: "Last Name",
                                            text: $lastName,
                                            placeholder: "Doe",
                                            textContentType: .familyName
                                        )
                                    }
                                    
                                    UnderlinedTextField(
                                        label: "Username",
                                        text: $username,
                                        placeholder: "john.doe",
                                        textContentType: .username,
                                        keyboardType: .asciiCapable,
                                        autocapitalization: .none
                                    )
                                    
                                    UnderlinedTextField(
                                        label: "Email",
                                        text: $email,
                                        placeholder: "john.doe@example.com",
                                        textContentType: .emailAddress,
                                        keyboardType: .emailAddress,
                                        autocapitalization: .none
                                    )
                                }
                                
                                // Military Details Section
                                VStack(alignment: .leading, spacing: 24) {
                                    SectionHeader(title: "Military Details")
                                    
                                    HStack(spacing: 24) {
                                        MinimalDropdown(
                                            label: "Rank",
                                            selection: $selectedRank,
                                            placeholder: "Select Rank",
                                            options: militaryRanks
                                        )
                                        
                                        UnderlinedTextField(
                                            label: "Unit",
                                            text: $unit,
                                            placeholder: "1st Battalion"
                                        )
                                    }
                                }
                                
                                // Security Section
                                VStack(alignment: .leading, spacing: 24) {
                                    SectionHeader(title: "Security")
                                    
                                    UnderlinedSecureField(
                                        label: "Password",
                                        text: $password,
                                        placeholder: "Minimum 8 characters",
                                        textContentType: .newPassword
                                    )
                                    
                                    UnderlinedSecureField(
                                        label: "Confirm Password",
                                        text: $confirmPassword,
                                        placeholder: "Re-enter password",
                                        textContentType: .newPassword
                                    )
                                    
                                    // Password requirements
                                    if !password.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            PasswordRequirement(
                                                met: password.count >= 8,
                                                text: "At least 8 characters"
                                            )
                                            PasswordRequirement(
                                                met: password == confirmPassword && !confirmPassword.isEmpty,
                                                text: "Passwords match"
                                            )
                                        }
                                        .padding(.top, -16)
                                        .transition(.opacity)
                                    }
                                }
                                
                                // Error message
                                if let errorMessage = viewModel.errorMessage {
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
                                }
                                
                                // Create account button
                                MinimalLoadingButton(
                                    isLoading: viewModel.isLoading,
                                    title: "Create Account",
                                    icon: nil,
                                    action: register
                                )
                                .disabled(!isFormValid || viewModel.isLoading)
                                .padding(.top, 16)
                                
                                // Login link
                                VStack(spacing: 4) {
                                    Text("Already have an account?")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.tertiaryText)
                                    
                                    Button("Sign in") {
                                        showingLogin = true
                                    }
                                    .buttonStyle(TextLinkButtonStyle())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                            }
                            .padding(.horizontal, 48)
                            .padding(.bottom, 80)
                        }
                        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
                        .animation(.easeInOut(duration: 0.3), value: password)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingLogin) {
            LoginView { loginResponse in
                dismiss()
            }
        }
    }
    
    private var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !username.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword &&
        !selectedRank.isEmpty &&
        !unit.isEmpty &&
        password.count >= 8
    }
    
    private func register() {
        Task {
            await viewModel.register(
                firstName: firstName,
                lastName: lastName,
                username: username,
                email: email,
                password: password,
                rank: selectedRank,
                unit: unit
            )
            
            if viewModel.isRegistered {
                showingLogin = true
            }
        }
    }
}

// MARK: - Custom Components

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(AppFonts.captionMedium)
                .foregroundColor(AppColors.secondaryText)
                .kerning(AppFonts.ultraWideKerning)
            
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
        }
    }
}

struct MinimalDropdown: View {
    let label: String
    @Binding var selection: String
    let placeholder: String
    let options: [String]
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
                .kerning(AppFonts.wideKerning)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection = option
                    }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? placeholder : selection)
                        .font(AppFonts.body)
                        .foregroundColor(selection.isEmpty ? AppColors.tertiaryText : AppColors.primaryText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(AppColors.tertiaryText)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
        }
    }
}

struct PasswordRequirement: View {
    let met: Bool
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(met ? AppColors.success : AppColors.border)
            
            Text(text)
                .font(AppFonts.caption)
                .foregroundColor(met ? AppColors.secondaryText : AppColors.tertiaryText)
        }
        .animation(.easeInOut(duration: 0.2), value: met)
    }
}

// MARK: - View Model

@MainActor
class RegisterViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRegistered = false
    
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    func register(
        firstName: String,
        lastName: String,
        username: String,
        email: String,
        password: String,
        rank: String,
        unit: String
    ) async {
        isLoading = true
        errorMessage = nil
        
        let credentials = RegisterCredentials(
            username: username,
            email: email,
            password: password,
            first_name: firstName,
            last_name: lastName,
            rank: rank,
            unit: unit
        )
        
        do {
            _ = try await apiService.register(credentials: credentials)
            isRegistered = true
        } catch let error as APIService.APIError {
            switch error {
            case .badRequest(let message):
                errorMessage = message ?? "Registration failed. Please check your information."
            case .conflict:
                errorMessage = "Username or email already exists."
            case .serverError:
                errorMessage = "Server error. Please try again later."
            default:
                errorMessage = "Registration failed. Please try again."
            }
        } catch {
            errorMessage = "An unexpected error occurred."
        }
        
        isLoading = false
    }
}

// MARK: - Preview

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
            .previewDisplayName("8VC Style Register")
    }
}