import SwiftUI

struct AuthenticatedTabView: View {
    @StateObject var authViewModel: AuthViewModel
    @State private var showingScanView = false
    @State private var showingCreateProperty = false
    @State private var selectedTab = 0 // Default to Dashboard tab

    init(authViewModel: AuthViewModel) {
        _authViewModel = StateObject(wrappedValue: authViewModel)
        configureGlobalAppearance()
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Dashboard Tab - NEW LANDING PAGE
                NavigationView {
                    DashboardView()
                }
                .tag(0)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }

                // Property Book Tab (renamed from "Properties")
                NavigationView {
                    MyPropertiesView()
                        .navigationTitle("Property Book")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: { showingCreateProperty = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(AppColors.accent)
                                        .font(.title3)
                                }
                            }
                        }
                }
                .tag(1)
                .tabItem {
                    Label("Property", systemImage: "book.closed.fill")
                }

                // Transfers Tab
                NavigationView {
                    TransfersView()
                }
                .tag(2)
                .tabItem {
                    Label("Transfers", systemImage: "arrow.left.arrow.right")
                }

                // Scan Tab - Central action
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.accent)
                        
                        Text("Scan QR Code")
                            .font(AppFonts.headline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("Tap to scan property QR codes for transfers")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: { showingScanView = true }) {
                            Text("Open Scanner")
                                .font(AppFonts.bodyBold)
                        }
                        .buttonStyle(.primary)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.appBackground.ignoresSafeArea())
                .contentShape(Rectangle())
                .onTapGesture { showingScanView = true }
                .tag(3)
                .tabItem {
                    Label("Scan", systemImage: "qrcode.viewfinder")
                }

                // More Tab - Contains additional pages
                NavigationView {
                    MoreView(authViewModel: authViewModel)
                }
                .tag(4)
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
            }
            .accentColor(AppColors.accent)
            
            // Floating Action Button for Quick Actions (only on Property Book tab)
            if selectedTab == 1 { // Show only on Property Book tab
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        FloatingActionButton(
                            icon: "plus",
                            action: { showingCreateProperty = true }
                        )
                        .padding(.trailing, 20)
                        .padding(.bottom, 80) // Above tab bar
                    }
                }
            }
        }
        .sheet(isPresented: $showingScanView) {
            QRScannerView()
        }
        .sheet(isPresented: $showingCreateProperty) {
            CreatePropertyView()
        }
    }

    // Helper function to configure global UI element appearances
    private func configureGlobalAppearance() {
        // Tab Bar Appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppColors.secondaryBackground)

        // Configure item colors and fonts - use smaller caption font
        let itemAppearance = UITabBarItemAppearance()
        let normalFont = UIFont.systemFont(ofSize: 10, weight: .regular)
        let selectedFont = UIFont.systemFont(ofSize: 10, weight: .medium)
        
        // Configure icon and title positioning for better spacing
        itemAppearance.selected.iconColor = UIColor(AppColors.accent)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.accent), 
            .font: selectedFont
        ]
        itemAppearance.normal.iconColor = UIColor(AppColors.secondaryText)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.secondaryText), 
            .font: normalFont
        ]
        
        // Adjust title position to reduce crowding
        itemAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -2)
        itemAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -2)

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
        navigationBarAppearance.backgroundColor = UIColor(AppColors.secondaryBackground)
        
        let titleFont = AppFonts.uiFont(from: AppFonts.headline) ?? .systemFont(ofSize: 18, weight: .semibold)
        let largeTitleFont = AppFonts.uiFont(from: AppFonts.body.weight(.bold), size: 34) ?? .systemFont(ofSize: 34, weight: .bold)
        
        navigationBarAppearance.titleTextAttributes = [.foregroundColor: UIColor(AppColors.primaryText), .font: titleFont]
        navigationBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppColors.primaryText), .font: largeTitleFont]

        // Configure button colors and fonts
        let barButtonItemAppearance = UIBarButtonItemAppearance()
        let buttonFont = AppFonts.uiFont(from: AppFonts.body) ?? .systemFont(ofSize: 17)
        barButtonItemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppColors.accent), .font: buttonFont]
        
        navigationBarAppearance.buttonAppearance = barButtonItemAppearance
        navigationBarAppearance.doneButtonAppearance = barButtonItemAppearance

        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().tintColor = UIColor(AppColors.accent)
    }
}

// MARK: - More View (New)
struct MoreView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showingReferenceDB = false
    
    var body: some View {
        List {
            // Additional Features Section
            Section("Equipment Management") {
                NavigationLink(destination: ReferenceDatabaseBrowserView()) {
                    HStack {
                        Image(systemName: "book.closed.fill")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text("Reference Database")
                        Spacer()
                    }
                }
                
                NavigationLink(destination: SensitiveItemsView()) {
                    HStack {
                        Image(systemName: "shield.fill")
                            .foregroundColor(.green)
                            .frame(width: 30)
                        Text("Sensitive Items")
                        Spacer()
                    }
                }
                
                NavigationLink(destination: MaintenanceView()) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        Text("Maintenance")
                        Spacer()
                    }
                }
            }
            .listRowBackground(AppColors.secondaryBackground)
            
            // Reports Section
            Section("Reports & Analytics") {
                NavigationLink(destination: ReportsView()) {
                    HStack {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .foregroundColor(.purple)
                            .frame(width: 30)
                        Text("Reports")
                        Spacer()
                    }
                }
                
                NavigationLink(destination: Text("Audit Log View - Coming Soon")) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundColor(.indigo)
                            .frame(width: 30)
                        Text("Audit Log")
                        Spacer()
                    }
                }
            }
            .listRowBackground(AppColors.secondaryBackground)
            
            // Settings Section
            Section("Settings") {
                NavigationLink(destination: Text("QR Management View - Coming Soon")) {
                    HStack {
                        Image(systemName: "qrcode")
                            .foregroundColor(.cyan)
                            .frame(width: 30)
                        Text("QR Management")
                        Spacer()
                    }
                }
                
                NavigationLink(destination: SettingsView(authViewModel: authViewModel)) {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.gray)
                            .frame(width: 30)
                        Text("Settings")
                        Spacer()
                    }
                }
                
                NavigationLink(destination: ProfileView(authViewModel: authViewModel)) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(AppColors.accent)
                            .frame(width: 30)
                        Text("Profile")
                        Spacer()
                    }
                }
            }
            .listRowBackground(AppColors.secondaryBackground)
        }
        .listStyle(.insetGrouped)
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("More")
    }
}

// MARK: - Profile View (New)
struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        List {
            // User Profile Section
            Section {
                if let user = authViewModel.currentUser?.user {
                    HStack {
                        // Profile Picture Placeholder
                        ZStack {
                            Circle()
                                .fill(AppColors.accent)
                                .frame(width: 80, height: 80)
                            
                            Text(user.name.prefix(1).uppercased())
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                        .padding(.trailing)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(user.rank) \(user.name)")
                                .font(AppFonts.headline)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("@\(user.username)")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                            
                            Text("ID: #\(user.id)")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical)
                }
            }
            .listRowBackground(AppColors.secondaryBackground)
            
            // Account Details Section
            Section("Account Details") {
                ProfileDetailRow(label: "Role", value: "Company Commander")
                ProfileDetailRow(label: "Unit", value: "A Company, 1-502 INF")
                ProfileDetailRow(label: "Member Since", value: "Jan 2023")
            }
            .listRowBackground(AppColors.secondaryBackground)
            
            // Statistics Section
            Section("Activity Statistics") {
                ProfileDetailRow(label: "Total Items", value: "156")
                ProfileDetailRow(label: "Transfers Completed", value: "47")
                ProfileDetailRow(label: "Items Verified", value: "312")
            }
            .listRowBackground(AppColors.secondaryBackground)
            
            // Actions Section
            Section {
                Button("Sign Out", role: .destructive) {
                    authViewModel.logout()
                }
                .font(AppFonts.bodyBold)
            }
            .listRowBackground(AppColors.secondaryBackground)
        }
        .listStyle(.insetGrouped)
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Profile")
    }
}

// MARK: - Profile Detail Row Component
struct ProfileDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            Spacer()
            Text(value)
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.primaryText)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(AppColors.accent)
                        .shadow(color: AppColors.accent.opacity(0.3), radius: isPressed ? 4 : 8, y: isPressed ? 2 : 4)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        List {
            // User Info Section
            Section("Account") {
                if let user = authViewModel.currentUser?.user {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Name:")
                                .font(AppFonts.bodyBold)
                                .foregroundColor(AppColors.secondaryText)
                            Text("\(user.rank) \(user.name)")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.primaryText)
                        }
                        
                        HStack {
                            Text("Username:")
                                .font(AppFonts.bodyBold)
                                .foregroundColor(AppColors.secondaryText)
                            Text("@\(user.username)")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.primaryText)
                        }
                        
                        HStack {
                            Text("User ID:")
                                .font(AppFonts.bodyBold)
                                .foregroundColor(AppColors.secondaryText)
                            Text("#\(user.id)")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.primaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowBackground(AppColors.secondaryBackground)

            // App Info Section
            Section("Application") {
                HStack {
                    Text("Version")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                    Spacer()
                    Text("1.0.0")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                }
                
                HStack {
                    Text("Server")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                    Spacer()
                    Text("Connected")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.accent)
                }
            }
            .listRowBackground(AppColors.secondaryBackground)

            // Actions Section
            Section {
                Button(action: {
                    // TODO: Implement sync action
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Force Sync")
                    }
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.accent)
                }
                
                Button(action: {
                    // TODO: Clear local cache
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Cache")
                    }
                    .font(AppFonts.body)
                    .foregroundColor(.orange)
                }
                
                Button("Logout", role: .destructive) {
                    authViewModel.logout()
                }
                .font(AppFonts.bodyBold)
            }
            .listRowBackground(AppColors.secondaryBackground)
        }
        .listStyle(.insetGrouped)
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Settings")
    }
}

// MARK: - Helper Extension for UIFont conversion
extension AppFonts {
    static func uiFont(from font: Font, size: CGFloat? = nil) -> UIFont? {
        let fontDescription = String(describing: font)
        
        if fontDescription.contains("CustomFontProvider") {
            var fontName = "HelveticaNeue"
            var finalSize: CGFloat
            
            switch font {
                case AppFonts.body: fontName = "HelveticaNeue"; finalSize = AppFonts.bodySize
                case AppFonts.bodyBold: fontName = "HelveticaNeue-Bold"; finalSize = AppFonts.bodySize
                case AppFonts.headline: fontName = "HelveticaNeue-Medium"; finalSize = AppFonts.headlineSize
                case AppFonts.subheadline: fontName = "HelveticaNeue"; finalSize = AppFonts.subheadlineSize
                case AppFonts.subheadlineBold: fontName = "HelveticaNeue-Bold"; finalSize = AppFonts.subheadlineSize
                case AppFonts.caption: fontName = "HelveticaNeue"; finalSize = AppFonts.captionSize
                case AppFonts.captionBold: fontName = "HelveticaNeue-Bold"; finalSize = AppFonts.captionSize
                default:
                    if fontDescription.contains("weight=bold") { fontName = "HelveticaNeue-Bold" }
                    else if fontDescription.contains("weight=medium") { fontName = "HelveticaNeue-Medium" }
                    finalSize = AppFonts.bodySize
            }
            
            if let explicitSize = size {
                finalSize = explicitSize
            }
            
            return UIFont(name: fontName, size: finalSize)
        } else {
            print("Warning: Attempting UIFont conversion for non-custom font: \(fontDescription)")
            if font == .headline { return UIFont.preferredFont(forTextStyle: .headline) }
            if font == .body { return UIFont.preferredFont(forTextStyle: .body) }
            if font == .caption { return UIFont.preferredFont(forTextStyle: .caption1) }
            return UIFont.preferredFont(forTextStyle: .body)
        }
    }
}

// MARK: - Preview
struct AuthenticatedTabView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticatedTabView(authViewModel: AuthViewModel())
            .preferredColorScheme(.dark)
    }
} 