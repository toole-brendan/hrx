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
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.military)
                        
                        Text("Create Account")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Join HandReceipt System")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Registration Form
                    VStack(spacing: 16) {
                        // Name fields
                        HStack(spacing: 12) {
                            TextField("First Name", text: $firstName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .textContentType(.givenName)
                            
                            TextField("Last Name", text: $lastName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .textContentType(.familyName)
                        }
                        
                        // Username
                        TextField("Username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.username)
                            .autocapitalization(.none)
                        
                        // Email
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        // Rank and Unit
                        HStack(spacing: 12) {
                            Picker("Rank", selection: $selectedRank) {
                                Text("Select Rank").tag("")
                                ForEach(militaryRanks, id: \.self) { rank in
                                    Text(rank).tag(rank)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            
                            TextField("Unit", text: $unit)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Password fields
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.newPassword)
                        
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.newPassword)
                        
                        // Error message
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                        
                        // Register button
                        Button(action: register) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "person.badge.plus")
                                    Text("Create Account")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.military : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!isFormValid || viewModel.isLoading)
                        
                        // Login link
                        HStack {
                            Text("Already have an account?")
                                .foregroundColor(.secondary)
                            Button("Sign In") {
                                showingLogin = true
                            }
                            .foregroundColor(.military)
                        }
                        .font(.footnote)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingLogin) {
            LoginView { loginResponse in
                // Dismiss the register view when login is successful
                dismiss()
            }
        }
        .navigationViewStyle(.stack)
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

// RegisterViewModel
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
                errorMessage = message ?? "Registration failed. Please try again."
            default:
                errorMessage = "Registration failed. Please try again."
            }
        } catch {
            errorMessage = "An unexpected error occurred."
        }
        
        isLoading = false
    }
} 