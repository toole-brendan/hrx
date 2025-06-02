// handreceipt/ios/HandReceipt/Views/AuthenticatedTabView.swift

import SwiftUI

struct AuthenticatedTabView: View {
    @StateObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var showingCreateProperty = false
    @State private var showingDA2062Import = false
    @State private var showingActionMenu = false

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
                            action: { showingActionMenu = true }
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
        .sheet(isPresented: $showingDA2062Import) {
            NavigationView {
                DA2062ScanView()
            }
        }
        .actionSheet(isPresented: $showingActionMenu) {
            ActionSheet(
                title: Text("Add Property"),
                buttons: [
                    .default(Text("Create New Property")) {
                        showingCreateProperty = true
                    },
                    .default(Text("Import from DA-2062")) {
                        showingDA2062Import = true
                    },
                    .cancel()
                ]
            )
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
            AppColors.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // Property Management Section
                    VStack(alignment: .leading, spacing: 0) {
                        
                        VStack(spacing: 12) {
                            // Reference Database
                            ModernMoreActionRow(
                                icon: "book.closed.fill",
                                iconColor: .blue,
                                title: "Reference Database",
                                subtitle: "Browse NSN/LIN catalog",
                                destination: AnyView(ReferenceDatabaseBrowserView())
                            )
                            
                            // My Network
                            ModernMoreActionRow(
                                icon: "person.2.fill",
                                iconColor: AppColors.accent,
                                title: "My Network",
                                subtitle: "Manage connections",
                                destination: AnyView(ConnectionsView())
                            )
                            
                            // Sensitive Items
                            ModernMoreActionRow(
                                icon: "shield.fill",
                                iconColor: AppColors.success,
                                title: "Sensitive Items",
                                subtitle: "Track high-value property",
                                destination: AnyView(SensitiveItemsView())
                            )
                            
                            // Maintenance
                            ModernMoreActionRow(
                                icon: "wrench.and.screwdriver.fill",
                                iconColor: AppColors.warning,
                                title: "Maintenance",
                                subtitle: "Property maintenance tracking",
                                destination: AnyView(MaintenanceView())
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Settings Section
                    VStack(alignment: .leading, spacing: 0) {
                        ModernSectionHeader(
                            title: "Settings",
                            subtitle: "App preferences and account management"
                        )
                        
                        VStack(spacing: 12) {
                            // Settings
                            ModernMoreActionRow(
                                icon: "gear",
                                iconColor: AppColors.secondaryText,
                                title: "Settings",
                                subtitle: "App preferences and sync",
                                destination: AnyView(SettingsView(authViewModel: authViewModel))
                            )
                            
                            // Profile
                            ModernMoreActionRow(
                                icon: "person.circle.fill",
                                iconColor: AppColors.accent,
                                title: "Profile",
                                subtitle: "Account information",
                                destination: AnyView(ProfileView(authViewModel: authViewModel))
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Bottom spacer
                    Spacer()
                        .frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Header
            UniversalHeaderView(title: "More", showBackButton: false)
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
            AppColors.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // User Profile Section
                    VStack(alignment: .leading, spacing: 16) {
                        ModernSectionHeader(
                            title: "Profile Information",
                            subtitle: "Your account details and information"
                        )
                        
                        // User Profile Card
                        VStack(spacing: 20) {
                            if let user = authViewModel.currentUser?.user {
                                HStack(spacing: 20) {
                                    // Profile Picture
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.accent)
                                            .frame(width: 80, height: 80)
                                        
                                        Text(user.name.prefix(1).uppercased())
                                            .font(AppFonts.largeTitleHeavy)
                                            .foregroundColor(.black)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("\(user.rank) \(user.name)")
                                            .font(AppFonts.title)
                                            .foregroundColor(AppColors.primaryText)
                                        
                                        Text("@\(user.username)")
                                            .font(AppFonts.bodyBold)
                                            .foregroundColor(AppColors.accent)
                                        
                                        Text("ID: #\(user.id)")
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.tertiaryText)
                                            .compatibleKerning(AppFonts.wideTracking)
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .modernCard()
                        .padding(.horizontal)
                    }
                    
                    // Account Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        ModernSectionHeader(
                            title: "Account Details",
                            subtitle: "Role and organizational information"
                        )
                        
                        VStack(spacing: 12) {
                            ModernProfileDetailRow(label: "Role", value: "Company Commander")
                            ModernProfileDetailRow(label: "Unit", value: "A Company, 1-502 INF")
                            ModernProfileDetailRow(label: "Member Since", value: "Jan 2023")
                        }
                        .padding(.horizontal)
                    }
                    
                    // Activity Statistics Section
                    VStack(alignment: .leading, spacing: 16) {
                        ModernSectionHeader(
                            title: "Activity Statistics",
                            subtitle: "Your property management activity"
                        )
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ProfileStatCard(title: "Total Items", value: "156", icon: "cube.box.fill", color: AppColors.accent)
                            ProfileStatCard(title: "Transfers", value: "47", icon: "arrow.left.arrow.right.circle.fill", color: AppColors.success)
                            ProfileStatCard(title: "Verifications", value: "312", icon: "checkmark.shield.fill", color: AppColors.warning)
                            ProfileStatCard(title: "Maintenance", value: "23", icon: "wrench.and.screwdriver.fill", color: AppColors.destructive)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Actions Section
                    VStack(alignment: .leading, spacing: 16) {
                        ModernSectionHeader(
                            title: "Account Actions",
                            subtitle: "Manage your account settings"
                        )
                        
                        Button("Sign Out", role: .destructive) {
                            authViewModel.logout()
                        }
                        .buttonStyle(.destructive)
                        .padding(.horizontal)
                    }
                    
                    // Bottom spacer
                    Spacer()
                        .frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Header
            UniversalHeaderView(
                title: "Profile",
                showBackButton: true,
                backButtonAction: nil
            )
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
}



// MARK: - Modern More Action Row Component
struct ModernMoreActionRow: View {
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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .modernCard(isElevated: false)
    }
}



// MARK: - Modern Profile Detail Row Component
struct ModernProfileDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(AppFonts.captionBold)
                .foregroundColor(AppColors.tertiaryText)
                .compatibleKerning(AppFonts.militaryTracking)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .modernCard(isElevated: false)
    }
}

// MARK: - Profile Stat Card Component
struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(AppFonts.largeTitleHeavy)
                .foregroundColor(AppColors.primaryText)
            
            Text(title.uppercased())
                .font(AppFonts.captionBold)
                .foregroundColor(AppColors.secondaryText)
                .compatibleKerning(AppFonts.wideTracking)
        }
        .modernCard()
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

// MARK: - Floating Action Button (using the one from IndustrialComponents)
// FloatingActionButton is now defined in IndustrialComponents.swift



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
                case AppFonts.subhead: fontName = "HelveticaNeue"; finalSize = AppFonts.subheadSize
                case AppFonts.subheadBold: fontName = "HelveticaNeue-Bold"; finalSize = AppFonts.subheadSize
                case AppFonts.caption: fontName = "HelveticaNeue"; finalSize = AppFonts.smallSize
                case AppFonts.captionBold: fontName = "HelveticaNeue-Bold"; finalSize = AppFonts.smallSize
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