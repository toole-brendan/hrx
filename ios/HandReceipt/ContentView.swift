import SwiftUI
import Foundation
import Darwin
// Remove these lines
// @_exported import class HandReceipt.AppColors
// @_exported import struct HandReceipt.PrimaryButtonStyle

struct ContentView: View {
    // Use AuthManager from environment instead of local state
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoading: Bool = false
    @State private var loadingError: Error? = nil
    @State private var showDebugOverlay: Bool = false

    // Inject the APIService
    private let apiService: APIServiceProtocol

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.appBackground.ignoresSafeArea())
        .accentColor(AppColors.accent)
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
                LoadingView(
                    error: loadingError,
                    onRetry: {
                        loadingError = nil
                        checkSessionStatus()
                    },
                    onSkipToLogin: {
                        isLoading = false
                        loadingError = nil
                    }
                )
                .transition(.opacity)
                .zIndex(1) // Ensure it's on top
            } else if !authManager.isAuthenticated {
                LoginView { loginResponse in
                    debugPrint("ContentView: Login successful for user \(loginResponse.user.username)")
                    Task {
                        // Update AuthManager with login response
                        await authManager.login(response: loginResponse)
                        debugPrint("ContentView: Authentication state updated - user is now authenticated")
                    }
                }
                .onAppear {
                    debugPrint("LoginView appeared - user needs to authenticate")
                }
            } else {
                AuthenticatedTabView(authViewModel: AuthViewModel(
                    currentUser: LoginResponse(
                        accessToken: AuthManager.shared.getAccessToken(),
                        user: authManager.currentUser ?? LoginResponse.User(
                            id: 0,
                            username: "unknown",
                            rank: ""
                        )
                    ),
                    logoutCallback: {
                        debugPrint("ContentView: Received logout request")
                        Task {
                            await authManager.logout()
                            debugPrint("ContentView: User logged out - authentication state reset")
                        }
                    }
                ))
                .environmentObject(authManager)
                .onAppear {
                    debugPrint("AuthenticatedTabView appeared - user is authenticated as \(authManager.currentUser?.username ?? "unknown")")
                }
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
                Text("Authenticated: \(authManager.isAuthenticated ? "Yes" : "No")")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.primaryText)
                if let user = authManager.currentUser {
                    Text("User: \(user.username) (ID: \(user.id))")
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
        // No longer needed - AuthManager handles session checking
        debugPrint("ContentView: checkSessionStatus called but no longer used")
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