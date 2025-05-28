import SwiftUI

struct AuthenticatedTabView: View {
    @StateObject var authViewModel: AuthViewModel // Use @StateObject for owning the VM
    @State private var showingScanView = false // State to control sheet presentation

    // Initialize appearance on view creation (can also be done in App struct)
    init(authViewModel: AuthViewModel) {
        _authViewModel = StateObject(wrappedValue: authViewModel)
        configureGlobalAppearance()
    }

    var body: some View {
        TabView {
            // Reference DB Tab
            NavigationView {
                ReferenceDatabaseBrowserView()
            }
            .tag(0) // Add tags for potential programmatic selection
            .tabItem {
                Label("Ref DB", systemImage: "book.closed")
            }

            // My Properties Tab
            NavigationView {
                 MyPropertiesView()
            }
            .tag(1)
            .tabItem {
                Label("Properties", systemImage: "list.bullet.rectangle.portrait")
            }

            // Scan Placeholder Tab
            VStack { // Wrap in VStack for alignment if needed
                Text("Tap to Scan") // More informative placeholder
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.appBackground.ignoresSafeArea()) // Match background
            .contentShape(Rectangle()) // Make the whole area tappable
            .onTapGesture { showingScanView = true }
            .tag(2)
            .tabItem {
                 Label("Scan", systemImage: "qrcode.viewfinder")
            }
            
            // Transfers Tab
             NavigationView {
                 TransfersView() // Use the actual TransfersView
             }
             .tag(3)
             .tabItem {
                 Label("Transfers", systemImage: "arrow.right.arrow.left.circle")
             }

            // Settings/Profile Tab
            NavigationView {
                SettingsView(authViewModel: authViewModel) // Use a dedicated SettingsView
            }
            .tag(4)
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .accentColor(AppColors.accent) // Set the accent color for tab items & nav buttons
        .sheet(isPresented: $showingScanView) { // Present ScanView as a sheet
             NavigationView { // Embed ScanView in NavigationView for title/buttons
                 ScanView()
                     .navigationTitle("Scan Equipment")
                     .navigationBarTitleDisplayMode(.inline)
                      // Use theme colors for sheet elements
                     .toolbar { 
                         ToolbarItem(placement: .navigationBarLeading) {
                             Button("Cancel") { showingScanView = false }
                                .font(AppFonts.body) // Apply font
                                .foregroundColor(AppColors.accent) // Apply color
                         }
                     }
                     // Ensure ScanView background is set if needed, or rely on global nav appearance
                     // .background(AppColors.appBackground) // Example if needed
             }
             .accentColor(AppColors.accent) // Ensure sheet also uses accent color
        }
        // .onAppear { // Configure appearance here if not done in init
        //     configureGlobalAppearance()
        // }
    }

    // Helper function to configure global UI element appearances
    private func configureGlobalAppearance() {
        // Tab Bar Appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppColors.secondaryBackground) // Darker background

        // Configure item colors and fonts (selected and normal)
        let itemAppearance = UITabBarItemAppearance()
        let normalFont = AppFonts.uiFont(from: AppFonts.caption) ?? .systemFont(ofSize: 10) // Fallback font
        let selectedFont = AppFonts.uiFont(from: AppFonts.captionBold) ?? .systemFont(ofSize: 10, weight: .medium) // Fallback font
        
        itemAppearance.selected.iconColor = UIColor(AppColors.accent)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppColors.accent), .font: selectedFont]
        itemAppearance.normal.iconColor = UIColor(AppColors.secondaryText)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppColors.secondaryText), .font: normalFont]

        tabBarAppearance.stackedLayoutAppearance = itemAppearance
        tabBarAppearance.inlineLayoutAppearance = itemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }

        // Navigation Bar Appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = UIColor(AppColors.secondaryBackground) // Match tab bar
        
        let titleFont = AppFonts.uiFont(from: AppFonts.headline) ?? .systemFont(ofSize: 18, weight: .semibold) // Fallback font
        let largeTitleFont = AppFonts.uiFont(from: AppFonts.body.weight(.bold), size: 34) ?? .systemFont(ofSize: 34, weight: .bold) // Approx large title size
        
        navigationBarAppearance.titleTextAttributes = [.foregroundColor: UIColor(AppColors.primaryText), .font: titleFont]
        navigationBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppColors.primaryText), .font: largeTitleFont]

        // Configure button colors and fonts
        let barButtonItemAppearance = UIBarButtonItemAppearance()
        let buttonFont = AppFonts.uiFont(from: AppFonts.body) ?? .systemFont(ofSize: 17)
        barButtonItemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppColors.accent), .font: buttonFont]
        // Apply to disabled, highlighted states if needed
        // barButtonItemAppearance.disabled.titleTextAttributes = ...
        // barButtonItemAppearance.highlighted.titleTextAttributes = ...
        
        navigationBarAppearance.buttonAppearance = barButtonItemAppearance
        navigationBarAppearance.doneButtonAppearance = barButtonItemAppearance // Apply to Done buttons too

        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance // For compact sizes
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance // For large titles
        UINavigationBar.appearance().tintColor = UIColor(AppColors.accent) // Global tint for image buttons
    }
}

// MARK: - Helper Extension for UIFont conversion
// Placed here for locality, could be moved to a common utility file
extension AppFonts {
    // Attempts to create a UIFont from a SwiftUI Font description.
    // Note: This is somewhat fragile as it relies on parsing the Font description.
    // It works for .custom fonts but might fail for others.
    static func uiFont(from font: Font, size: CGFloat? = nil) -> UIFont? {
        let fontDescription = String(describing: font)
        
        if fontDescription.contains("CustomFontProvider") {
            var fontName = "HelveticaNeue" // Default
            var finalSize: CGFloat // Use this to determine the size
            
            // Determine font name and base size from the matched AppFonts static property
            switch font {
                case AppFonts.body: fontName = "HelveticaNeue"; finalSize = AppFonts.bodySize
                case AppFonts.bodyBold: fontName = "HelveticaNeue-Bold"; finalSize = AppFonts.bodySize
                case AppFonts.headline: fontName = "HelveticaNeue-Medium"; finalSize = AppFonts.headlineSize
                case AppFonts.subheadline: fontName = "HelveticaNeue"; finalSize = AppFonts.subheadlineSize
                case AppFonts.subheadlineBold: fontName = "HelveticaNeue-Bold"; finalSize = AppFonts.subheadlineSize
                case AppFonts.caption: fontName = "HelveticaNeue"; finalSize = AppFonts.captionSize
                case AppFonts.captionBold: fontName = "HelveticaNeue-Bold"; finalSize = AppFonts.captionSize
                default:
                    // Basic fallback for weighted fonts (less reliable)
                    print("Warning: UIFont conversion attempting fallback for: \(fontDescription).")
                    if fontDescription.contains("weight=bold") { fontName = "HelveticaNeue-Bold" }
                    else if fontDescription.contains("weight=medium") { fontName = "HelveticaNeue-Medium" }
                    
                    // REMOVED the attempt to parse size from description string
                    finalSize = AppFonts.bodySize // Default to body size if no direct match
            }
            
            // Override size if explicitly passed in
            if let explicitSize = size {
                finalSize = explicitSize
            }
            
            return UIFont(name: fontName, size: finalSize)
        } else {
            // Handle non-custom fonts (system fonts)
            print("Warning: Attempting UIFont conversion for non-custom font: \(fontDescription)")
            // Fallback to system preferred fonts
            if font == .headline { return UIFont.preferredFont(forTextStyle: .headline) }
            if font == .body { return UIFont.preferredFont(forTextStyle: .body) }
            if font == .caption { return UIFont.preferredFont(forTextStyle: .caption1) }
            // Add more mappings if needed
            return UIFont.preferredFont(forTextStyle: .body) // Default Fallback
        }
    }
}

// MARK: - Placeholder Settings View
// Create a dedicated view for settings content
struct SettingsView: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        List { 
            Section("Account") {
                Text("User: \(authViewModel.currentUser?.user.username ?? "N/A")")
                    .font(AppFonts.body) // Apply theme font
                    .foregroundColor(AppColors.primaryText) // Apply theme color
                // Avoid displaying tokens directly in UI
                // Text("Token: \(authViewModel.currentUser?.token.prefix(10) ?? "N/A")...")
            }
            .listRowBackground(AppColors.secondaryBackground) // Set row background

            Section {
                Button("Logout", role: .destructive) {
                    authViewModel.logout()
                }
                .font(AppFonts.body) // Apply theme font
                .foregroundColor(AppColors.destructive) // Ensure destructive color is used
            }
            .listRowBackground(AppColors.secondaryBackground) // Set row background
        }
        .listStyle(.insetGrouped)
        .background(AppColors.appBackground.ignoresSafeArea()) // Set view background
        .navigationTitle("Settings")
    }
}

// Preview needs adjustment if AuthViewModel requires initialization
struct AuthenticatedTabView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a default AuthViewModel for the preview
        AuthenticatedTabView(authViewModel: AuthViewModel())
            .preferredColorScheme(.dark) // Preview in dark mode
    }
} 