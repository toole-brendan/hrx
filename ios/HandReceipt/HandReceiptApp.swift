import SwiftUI
import UIKit
import AVFoundation

@main
struct HandReceiptApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared
    
    init() {
        print("🚀 HandReceiptApp: init() called")
        print("🚀 HandReceiptApp: Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("🚀 HandReceiptApp: App version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown")")
        
        // Configure 8VC-inspired global navigation appearance
        GlobalNavigationConfiguration.configureGlobalAppearance()
        print("🎨 HandReceiptApp: 8VC navigation styling configured")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(apiService: APIService())
                .environmentObject(authManager)
                .task {
                    // Check auth status on app launch
                    await authManager.checkAuthStatus()
                }
                .onAppear {
                    print("🚀 ContentView appeared in WindowGroup")
                }
        }
    }
}

// App delegate to ensure window is properly configured
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🚀 AppDelegate: didFinishLaunchingWithOptions")
        
        // Configure audio session to prevent HALC_ProxyIOContext errors
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            AppLogger.error("Failed to configure audio session: \(error)")
        }
        
        // Disable system logging for known issues
        UserDefaults.standard.set(false, forKey: "PKDisableDefaults")
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("🚀 AppDelegate: configurationForConnecting")
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

// Scene delegate to ensure proper window setup
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("🚀 SceneDelegate: willConnectTo")
        
        guard let windowScene = (scene as? UIWindowScene) else { 
            print("❌ Failed to get UIWindowScene")
            return 
        }
        
        // Create window
        window = UIWindow(windowScene: windowScene)
        
        // Create the SwiftUI content view with AuthManager
        let authManager = AuthManager.shared
        let contentView = ContentView(apiService: APIService())
            .environmentObject(authManager)
        let hostingController = UIHostingController(rootView: contentView)
        
        // Ensure the window has a proper background color
        window?.backgroundColor = UIColor.systemBackground
        window?.rootViewController = hostingController
        window?.makeKeyAndVisible()
        
        print("🚀 SceneDelegate: Window configured with SwiftUI ContentView")
        print("🚀 Window frame: \(window?.frame ?? .zero)")
        print("🚀 Window isKeyWindow: \(window?.isKeyWindow ?? false)")
    }
} 