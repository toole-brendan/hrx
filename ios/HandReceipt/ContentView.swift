import SwiftUI
import Foundation
import Darwin
// Remove these lines
// @_exported import class HandReceipt.AppColors
// @_exported import struct HandReceipt.PrimaryButtonStyle

struct ContentView: View {
    // Simple state to track authentication.
    // In a real app, this would likely come from an ObservableObject (e.g., AuthManager)
    // that checks stored session tokens or performs a session check API call.
    @State private var isAuthenticated: Bool = false // Start as not authenticated
    @State private var loggedInUser: LoginResponse? = nil
    @State private var isLoading: Bool = true // Added loading state
    @State private var loadingError: Error? = nil // Track any errors for debugging
    @State private var showDebugOverlay: Bool = false // Toggle for debug overlay

    // Inject the APIService
    private let apiService: APIServiceProtocol // Use protocol for testability

    // Initializer to inject the service
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
        debugPrint("ContentView initialized with APIService")
    }

    var body: some View {
        ZStack {
            // Main content
            mainContent
            
            // Debug overlay when enabled
            #if DEBUG
            if showDebugOverlay {
                debugOverlay
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure ZStack fills the screen
        .background(AppColors.appBackground.ignoresSafeArea()) // Use dark theme background
        .accentColor(AppColors.accent) // Use theme accent color
        // Detect shake gesture for debug overlay
        .onShake {
            #if DEBUG
            withAnimation {
                showDebugOverlay.toggle()
                debugPrint("Debug overlay toggled: \(showDebugOverlay)")
            }
            #endif
        }
    }
    
    // Main content view based on authentication state
    private var mainContent: some View {
        VStack {
            // Show loading indicator while checking session
            if isLoading {
                VStack {
                    ProgressView {
                        Text("Checking session...")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.primaryText)
                    }
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                    
                    // Display error details if there was a loading error
                    if let error = loadingError {
                        VStack(spacing: 10) {
                            Text("Debug: Session check error")
                                .font(AppFonts.headline)
                                .foregroundColor(AppColors.destructive) // Use destructive color for errors
                            
                            Text(error.localizedDescription)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.destructive) // Use destructive color for errors
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            // Add button to retry session check
                            Button("Retry") {
                                debugPrint("Manual retry of session check")
                                checkSessionStatus()
                            }
                            .buttonStyle(.primary) // Apply primary button style
                            .padding()
                            
                            // Skip login button for debugging
                            Button("Debug: Skip to Login") {
                                debugPrint("Debug: Manually forcing login screen")
                                isLoading = false
                            }
                            .buttonStyle(.primary) // Apply primary button style
                            .padding()
                        }
                        .padding()
                    }
                }
                .onAppear(perform: checkSessionStatus) // Check status when view appears
            } else if !isAuthenticated {
                LoginView {
                     // This closure is called by LoginView on success
                     loginResponse in
                     debugPrint("ContentView: Login successful for user \(loginResponse.user.username)")
                     // Update state to show the main app content
                     // Use MainActor.run for state updates triggered from background tasks (like login)
                     Task { @MainActor in
                         self.loggedInUser = loginResponse
                         self.isAuthenticated = true
                         debugPrint("ContentView: Authentication state updated - user is now authenticated")
                     }
                }
                // Pass the injected apiService if LoginView needs it
                // .environmentObject(apiService) // Example if using EnvironmentObject
                .onAppear {
                    debugPrint("LoginView appeared - user needs to authenticate")
                }
            } else {
                // Use TabView for the main authenticated view
                AuthenticatedTabView(authViewModel: AuthViewModel(
                    currentUser: loggedInUser,
                    logoutCallback: {
                        // Logout callback
                        debugPrint("ContentView: Received logout request")
                        Task { @MainActor in
                            self.isAuthenticated = false
                            self.loggedInUser = nil
                            debugPrint("ContentView: User logged out - authentication state reset")
                        }
                    }
                ))
                .onAppear {
                    debugPrint("AuthenticatedTabView appeared - user is authenticated as \(loggedInUser?.user.username ?? "unknown")")
                }
                 // Pass API service via environment if needed by tabs
                 // .environmentObject(APIService()) 
            }
        }
    }
    
    // Debug overlay view with system information
    private var debugOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DEBUG INFORMATION")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showDebugOverlay = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.primaryText)
                }
            }
            
            Divider().background(AppColors.secondaryText)
            
            Group {
                Text("App State:")
                    .font(AppFonts.subheadlineBold)
                    .foregroundColor(AppColors.primaryText)
                Text("Loading: \(isLoading ? "Yes" : "No")")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.primaryText)
                Text("Authenticated: \(isAuthenticated ? "Yes" : "No")")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.primaryText)
                if let user = loggedInUser {
                    Text("User: \(user.user.username) (ID: \(user.userId))")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.primaryText)
                }
            }
            
            Divider().background(AppColors.secondaryText)
            
            Group {
                Text("System:")
                    .font(AppFonts.subheadlineBold)
                    .foregroundColor(AppColors.primaryText)
                Text("iOS Version: \(UIDevice.current.systemVersion)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.primaryText)
                Text("Device: \(UIDevice.current.model)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.primaryText)
                Text("Memory: \(getMemoryUsage())")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.primaryText)
            }
            
            Divider().background(AppColors.secondaryText)
            
            Group {
                Text("Network:")
                    .font(AppFonts.subheadlineBold)
                    .foregroundColor(AppColors.primaryText)
                Text("API Base URL: \(apiService.baseURLString)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.primaryText)
                
                // Debug action buttons
                HStack {
                    Button("Test Connection") {
                        debugPrint("Test connection button tapped")
                        testNetworkConnection()
                    }
                    .font(AppFonts.captionBold)
                    .padding(6)
                    .background(AppColors.accent) // Use theme accent
                    .foregroundColor(AppColors.primaryText) // Use light text
                    .cornerRadius(6)
                    
                    Button("Clear Cookies") {
                        debugPrint("Clear cookies button tapped")
                        clearCookies()
                    }
                    .font(AppFonts.captionBold)
                    .padding(6)
                    .background(AppColors.destructive) // Use theme destructive
                    .foregroundColor(AppColors.primaryText) // Use light text
                    .cornerRadius(6)
                }
            }
            
            if let error = loadingError {
                Divider().background(AppColors.secondaryText)
                
                Group {
                    Text("Last Error:")
                        .font(AppFonts.subheadlineBold)
                        .foregroundColor(AppColors.primaryText)
                    Text(error.localizedDescription)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.destructive) // Use destructive color for error
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.secondaryBackground.opacity(0.9)) // Use slightly lighter dark bg
        .cornerRadius(10)
        .padding()
        .transition(.move(edge: .bottom))
    }

    // Function to check session status
    private func checkSessionStatus() {
        // Ensure we only run this check once if .onAppear fires multiple times
        // or if we already successfully authenticated via login
        guard isLoading, !isAuthenticated else { 
            debugPrint("ContentView: Skipping redundant session check")
            return 
        }
        
        debugPrint("ContentView: Starting session check process")

        Task {
            do {
                debugPrint("ContentView: Checking session status...")
                
                // Add delay for debugging to make sure we can see the loading state
                #if DEBUG
                debugPrint("DEBUG: Adding artificial delay to observe loading state")
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                #endif
                
                let user = try await apiService.checkSession()
                debugPrint("ContentView: Session check successful for user \(user.user.username)")
                
                // Update state on the main thread
                await MainActor.run {
                    debugPrint("ContentView: Updating UI after successful session check")
                    self.loggedInUser = user
                    self.isAuthenticated = true
                    self.isLoading = false
                    self.loadingError = nil
                }
            } catch {
                debugPrint("ContentView: Session check failed. Error: \(error)")
                
                // Detailed error logging
                if let apiError = error as? APIService.APIError {
                    switch apiError {
                    case .unauthorized:
                        debugPrint("ContentView: No valid session found (Unauthorized 401)")
                    case .networkError(let underlyingError):
                        debugPrint("ContentView: Network error during session check: \(underlyingError)")
                    case .serverError(let statusCode, let message):
                        debugPrint("ContentView: Server error \(statusCode) during session check: \(message ?? "No message")")
                    default:
                        debugPrint("ContentView: API error during session check: \(apiError)")
                    }
                } else {
                    debugPrint("ContentView: Unexpected error type during session check: \(type(of: error))")
                }
                
                // Update state on the main thread - stay unauthenticated
                await MainActor.run {
                    debugPrint("ContentView: Updating UI after failed session check")
                    self.isAuthenticated = false
                    self.loggedInUser = nil
                    self.isLoading = false
                    self.loadingError = error // Store the error for displaying debug info
                }
            }
        }
    }
    
    // MARK: - Debug Helpers
    
    private func getMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            return String(format: "%.1f MB", usedMB)
        } else {
            return "Unknown"
        }
    }
    
    private func testNetworkConnection() {
        Task {
            do {
                let url = URL(string: "\(apiService.baseURLString)/health")!
                let request = URLRequest(url: url)
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    debugPrint("Network test result: \(httpResponse.statusCode)")
                    // Display an alert or update the UI with the result
                }
            } catch {
                debugPrint("Network test failed: \(error)")
                // Display an alert or update the UI with the error
            }
        }
    }
    
    private func clearCookies() {
        if let baseURL = URL(string: apiService.baseURLString) {
            if let cookies = HTTPCookieStorage.shared.cookies(for: baseURL) {
                debugPrint("Clearing \(cookies.count) cookies for \(baseURL)")
                
                for cookie in cookies {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                    debugPrint("Deleted cookie: \(cookie.name)")
                }
            } else {
                debugPrint("No cookies found for \(baseURL)")
            }
        }
    }
}

// MARK: - Shake Gesture Detection

// Extension to detect device shake
extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

// UIWindow extension to capture shake events
extension UIWindow {
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

// View extension to respond to shake
extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
}

// Shake view modifier
struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}

// Preview needs adjustment or removal if APIService injection is complex
// For now, we comment it out as it requires more setup with the APIService dependency.
// struct ContentView_Previews: PreviewProvider {
//     static var previews: some View {
//         // Need to provide a mock APIService or handle the dependency here
//         // ContentView(apiService: MockAPIService())
//         ContentView() // This will now use the default APIService(), potentially making network calls
//     }
// } 