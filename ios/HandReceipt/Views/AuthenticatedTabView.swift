import SwiftUI

struct AuthenticatedTabView: View {
    @StateObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var showingCreateProperty = false

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

                // Connections Tab - NEW
                NavigationView {
                    ConnectionsView()
                }
                .tag(3)
                .tabItem {
                    Label("Network", systemImage: "person.2.fill")
                }

                // QR Scan functionality has been removed
                // NavigationView {
                //     ScanTabPlaceholderView()
                // }
                // .tag(3)
                // .tabItem {
                //     Label("Scan", systemImage: "qrcode.viewfinder")
                // }

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

// MARK: - More View (Updated)
struct MoreView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // Equipment Management Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Equipment Management")
                        
                        VStack(spacing: 0) {
                            // Reference Database
                            MoreActionRow(
                                icon: "book.closed.fill",
                                iconColor: .blue,
                                title: "Reference Database",
                                subtitle: "Browse NSN/LIN catalog",
                                destination: AnyView(ReferenceDatabaseBrowserView())
                            )
                            
                            Divider()
                                .background(AppColors.border)
                            
                            // My Network - NEW
                            MoreActionRow(
                                icon: "person.2.fill",
                                iconColor: AppColors.accent,
                                title: "My Network",
                                subtitle: "Manage connections",
                                destination: AnyView(ConnectionsView())
                            )
                            
                            Divider()
                                .background(AppColors.border)
                            
                            // Sensitive Items
                            MoreActionRow(
                                icon: "shield.fill",
                                iconColor: AppColors.success,
                                title: "Sensitive Items",
                                subtitle: "Track high-value equipment",
                                destination: AnyView(SensitiveItemsView())
                            )
                            
                            Divider()
                                .background(AppColors.border)
                            
                            // Maintenance
                            MoreActionRow(
                                icon: "wrench.and.screwdriver.fill",
                                iconColor: AppColors.warning,
                                title: "Maintenance",
                                subtitle: "Equipment maintenance tracking",
                                destination: AnyView(MaintenanceView())
                            )
                        }
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(0)
                        .overlay(
                            Rectangle()
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                    
                    // Settings Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Settings")
                        
                        VStack(spacing: 0) {
                            // QR Management - Removed
                            // MoreActionRow(
                            //     icon: "qrcode",
                            //     iconColor: .cyan,
                            //     title: "QR Management",
                            //     subtitle: "Generate and manage QR codes",
                            //     destination: AnyView(QRManagementView())
                            // )
                            //
                            // Divider()
                            //     .background(AppColors.border)
                            
                            // Settings
                            MoreActionRow(
                                icon: "gear",
                                iconColor: .gray,
                                title: "Settings",
                                subtitle: "App preferences and sync",
                                destination: AnyView(SettingsView(authViewModel: authViewModel))
                            )
                            
                            Divider()
                                .background(AppColors.border)
                            
                            // Profile
                            MoreActionRow(
                                icon: "person.circle.fill",
                                iconColor: AppColors.accent,
                                title: "Profile",
                                subtitle: "Account information",
                                destination: AnyView(ProfileView(authViewModel: authViewModel))
                            )
                        }
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(0)
                        .overlay(
                            Rectangle()
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                    
                    // Bottom spacer
                    Spacer()
                        .frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Top bar header
            MoreHeaderSection()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
}

// MARK: - Profile View (Updated)
struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // User Profile Card
                    WebAlignedCard {
                        if let user = authViewModel.currentUser?.user {
                            HStack(spacing: 16) {
                                // Profile Picture
                                ZStack {
                                    Circle()
                                        .fill(AppColors.accent)
                                        .frame(width: 80, height: 80)
                                    
                                    Text(user.name.prefix(1).uppercased())
                                        .font(.largeTitle)
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
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
                            .padding()
                        }
                    }
                    .padding(.horizontal)
                    
                    // Account Details Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Account Details")
                        
                        WebAlignedCard {
                            VStack(spacing: 0) {
                                ProfileDetailRow(label: "Role", value: "Company Commander")
                                Divider().background(AppColors.border)
                                ProfileDetailRow(label: "Unit", value: "A Company, 1-502 INF")
                                Divider().background(AppColors.border)
                                ProfileDetailRow(label: "Member Since", value: "Jan 2023")
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Activity Statistics Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Activity Statistics")
                        
                        WebAlignedCard {
                            VStack(spacing: 0) {
                                ProfileDetailRow(label: "Total Items", value: "156")
                                Divider().background(AppColors.border)
                                ProfileDetailRow(label: "Transfers Completed", value: "47")
                                Divider().background(AppColors.border)
                                ProfileDetailRow(label: "Items Verified", value: "312")
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Actions
                    Button("Sign Out", role: .destructive) {
                        authViewModel.logout()
                    }
                    .buttonStyle(.destructive)
                    .padding(.horizontal)
                    
                    // Bottom spacer
                    Spacer()
                        .frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Header
            ProfileHeaderSection()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
}

// MARK: - More Header Section
struct MoreHeaderSection: View {
    var body: some View {
        ZStack {
            // Background that extends to top of screen
            AppColors.secondaryBackground
                .ignoresSafeArea()
            
            // Content positioned at bottom of header
            VStack {
                Spacer()
                Text("MORE")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.primaryText)
                    .kerning(1.2)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            }
        }
        .frame(height: 36)
    }
}

// MARK: - More Action Row Component
struct MoreActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Rectangle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .cornerRadius(0)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Profile Header Section
struct ProfileHeaderSection: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppColors.secondaryBackground
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                HStack {
                    // Back button
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(AppColors.accent)
                    }
                    
                    Spacer()
                    
                    Text("PROFILE")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.primaryText)
                        .kerning(1.2)
                    
                    Spacer()
                    
                    // Invisible placeholder for balance
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.clear)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 36)
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
        .padding()
    }
}

// MARK: - QR Management View (DEPRECATED - Removed)
/*
struct QRManagementView: View {
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 24) {
                    Color.clear.frame(height: 36)
                    
                    Text("QR Code Management")
                        .font(AppFonts.largeTitle)
                        .foregroundColor(AppColors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    WebAlignedCard {
                        VStack(spacing: 16) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 60))
                                .foregroundColor(AppColors.secondaryText)
                            
                            Text("QR Management Coming Soon")
                                .font(AppFonts.headline)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("This feature will allow you to generate and manage QR codes for your equipment.")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    Spacer().frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            QRManagementHeaderSection()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
}

struct QRManagementHeaderSection: View {
    var body: some View {
        ZStack {
            AppColors.secondaryBackground
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                Text("QR MANAGEMENT")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.primaryText)
                    .kerning(1.2)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            }
        }
        .frame(height: 36)
    }
}
*/

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