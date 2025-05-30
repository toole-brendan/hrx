import SwiftUI
import UIKit

@main
struct HandReceiptApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        print("🚀 HandReceiptApp: init() called")
        print("🚀 HandReceiptApp: Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("🚀 HandReceiptApp: App version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown")")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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
        
        // Create the SwiftUI content view
        let contentView = ContentView()
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