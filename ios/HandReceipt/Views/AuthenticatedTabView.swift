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
                // Dashboard Tab
                NavigationView {
                    DashboardView(onTabSwitch: { tabIndex in
                        selectedTab = tabIndex
                    })
                }
                .tag(0)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

                // Property Book Tab
                NavigationView {
                    MyPropertiesView()
                        .navigationTitle("Property Book")
                }
                .tag(1)
                .tabItem {
                    Label("Property", systemImage: "shippingbox")
                }

                // Transfers Tab
                NavigationView {
                    TransfersView()
                }
                .tag(2)
                .tabItem {
                    Label("Transfers", systemImage: "arrow.left.arrow.right")
                }

                // Connections Tab
                NavigationView {
                    ConnectionsView()
                }
                .tag(3)
                .tabItem {
                    Label("Network", systemImage: "person.2")
                }

                // More Tab
                NavigationView {
                    MoreView(authViewModel: authViewModel)
                }
                .tag(4)
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
            }
            .accentColor(AppColors.accent)
            
            // Floating Action Button for Quick Actions (only on Property Book tab)
            if selectedTab == 1 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        FloatingActionButton(
                            icon: "plus",
                            action: { showingActionMenu = true }
                        )
                        .padding(.trailing, 20)
                        .padding(.bottom, 80)
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
        // Tab Bar Appearance - 8VC Style
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppColors.appBackground)
        
        // Minimal tab bar styling
        let itemAppearance = UITabBarItemAppearance()
        let normalFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let selectedFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        
        // Light theme icons and text
        itemAppearance.selected.iconColor = UIColor(AppColors.primaryText)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.primaryText),
            .font: selectedFont
        ]
        itemAppearance.normal.iconColor = UIColor(AppColors.tertiaryText)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.tertiaryText),
            .font: normalFont
        ]
        
        tabBarAppearance.stackedLayoutAppearance = itemAppearance
        tabBarAppearance.inlineLayoutAppearance = itemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = itemAppearance

        // Add subtle shadow instead of hard border
        tabBarAppearance.shadowColor = UIColor.black.withAlphaComponent(0.08)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }

        // Navigation Bar Appearance - 8VC Style
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = UIColor(AppColors.appBackground)
        navigationBarAppearance.shadowColor = UIColor.clear
        
        // Serif fonts for navigation titles
        let titleFont = UIFont.systemFont(ofSize: 18, weight: .regular)
        let largeTitleFont = UIFont.systemFont(ofSize: 34, weight: .regular, design: .serif)
        
        navigationBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.primaryText),
            .font: titleFont
        ]
        navigationBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppColors.primaryText),
            .font: largeTitleFont
        ]

        // Minimal button styling
        let barButtonItemAppearance = UIBarButtonItemAppearance()
        let buttonFont = UIFont.systemFont(ofSize: 17, weight: .regular)
        barButtonItemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.accent),
            .font: buttonFont
        ]
        
        navigationBarAppearance.buttonAppearance = barButtonItemAppearance
        navigationBarAppearance.doneButtonAppearance = barButtonItemAppearance

        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().tintColor = UIColor(AppColors.accent)
    }
}

// MARK: - More View (8VC Styled)
struct MoreView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack(alignment: .top) {
            AppColors.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    // Header section
                    VStack(spacing: 0) {
                        HStack {
                            Text("More")
                                .font(AppFonts.serifTitle)
                                .foregroundColor(AppColors.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        Divider()
                            .background(AppColors.divider)
                    }
                    
                    // Property Management Section
                    VStack(spacing: 24) {
                        ElegantSectionHeader(
                            title: "Property Management",
                            subtitle: "Tools and utilities",
                            style: .uppercase
                        )
                        .padding(.horizontal, 24)
                        
                        VStack(spacing: 16) {
                            MinimalMoreActionRow(
                                icon: "book.closed",
                                title: "Reference Database",
                                subtitle: "Browse NSN/LIN catalog",
                                destination: AnyView(ReferenceDatabaseBrowserView())
                            )
                            
                            MinimalMoreActionRow(
                                icon: "person.2",
                                title: "My Network",
                                subtitle: "Manage connections",
                                destination: AnyView(ConnectionsView())
                            )
                            
                            MinimalMoreActionRow(
                                icon: "shield",
                                title: "Sensitive Items",
                                subtitle: "Track high-value property",
                                destination: AnyView(SensitiveItemsView())
                            )
                            
                            MinimalMoreActionRow(
                                icon: "wrench",
                                title: "Maintenance",
                                subtitle: "Property maintenance tracking",
                                destination: AnyView(MaintenanceView())
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Settings Section
                    VStack(spacing: 24) {
                        ElegantSectionHeader(
                            title: "Settings",
                            subtitle: "App preferences and account",
                            style: .uppercase
                        )
                        .padding(.horizontal, 24)
                        
                        VStack(spacing: 16) {
                            MinimalMoreActionRow(
                                icon: "gear",
                                title: "Settings",
                                subtitle: "App preferences and sync",
                                destination: AnyView(SettingsView(authViewModel: authViewModel))
                            )
                            
                            MinimalMoreActionRow(
                                icon: "person.circle",
                                title: "Profile",
                                subtitle: "Account information",
                                destination: AnyView(ProfileView(authViewModel: authViewModel))
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Bottom padding
                    Color.clear.frame(height: 80)
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
}

// MARK: - Profile View (8VC Styled)
struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack(alignment: .top) {
            AppColors.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    // Header with back button
                    VStack(spacing: 0) {
                        HStack {
                            MinimalBackButton(action: {
                                // Handle back navigation
                            })
                            
                            Spacer()
                            
                            Text("Profile")
                                .font(AppFonts.serifTitle)
                                .foregroundColor(AppColors.primaryText)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        Divider()
                            .background(AppColors.divider)
                    }
                    
                    // User Profile Section
                    VStack(spacing: 24) {
                        ElegantSectionHeader(
                            title: "Profile Information",
                            subtitle: "Your account details",
                            style: .serif
                        )
                        .padding(.horizontal, 24)
                        
                        if let user = authViewModel.currentUser?.user {
                            VStack(spacing: 20) {
                                HStack(spacing: 20) {
                                    // Profile Picture
                                    Circle()
                                        .fill(AppColors.tertiaryBackground)
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Text(user.name.prefix(1).uppercased())
                                                .font(AppFonts.title)
                                                .foregroundColor(AppColors.secondaryText)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(user.name)
                                            .font(AppFonts.serifHeadline)
                                            .foregroundColor(AppColors.primaryText)
                                        
                                        Text("@\(user.username)")
                                            .font(AppFonts.monoBody)
                                            .foregroundColor(AppColors.accent)
                                        
                                        Text("ID: #\(user.id)")
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.tertiaryText)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .cleanCard()
                            .padding(.horizontal, 24)
                        }
                    }
                    
                    // Activity Statistics Section
                    VStack(spacing: 24) {
                        ElegantSectionHeader(
                            title: "Activity",
                            subtitle: "Your property management stats",
                            style: .uppercase
                        )
                        .padding(.horizontal, 24)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            MinimalStatCard(
                                title: "Total Items",
                                value: "156",
                                subtitle: "Equipment tracked"
                            )
                            
                            MinimalStatCard(
                                title: "Transfers",
                                value: "47",
                                subtitle: "Completed"
                            )
                            
                            MinimalStatCard(
                                title: "Verifications",
                                value: "312",
                                subtitle: "Items verified"
                            )
                            
                            MinimalStatCard(
                                title: "Maintenance",
                                value: "23",
                                subtitle: "Items serviced"
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Actions Section
                    VStack(spacing: 24) {
                        ElegantSectionHeader(
                            title: "Account Actions",
                            style: .uppercase
                        )
                        .padding(.horizontal, 24)
                        
                        Button("Sign Out") {
                            authViewModel.logout()
                        }
                        .buttonStyle(MinimalSecondaryButtonStyle())
                        .padding(.horizontal, 24)
                    }
                    
                    // Bottom padding
                    Color.clear.frame(height: 80)
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
}

// MARK: - Minimal More Action Row Component
struct MinimalMoreActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(AppColors.primaryText)
                    .frame(width: 32, height: 32)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding(20)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .cleanCard(showShadow: false)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Floating Action Button (Minimal Style)
public struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    let isExpanded: Bool
    
    public init(icon: String, action: @escaping () -> Void, isExpanded: Bool = false) {
        self.icon = icon
        self.action = action
        self.isExpanded = isExpanded
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                
                if isExpanded {
                    Text("CREATE")
                        .font(AppFonts.bodyMedium)
                        .compatibleKerning(AppFonts.wideKerning)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, isExpanded ? 20 : 16)
            .padding(.vertical, 16)
            .background(AppColors.primaryText)
            .cornerRadius(isExpanded ? 28 : 56)
            .shadow(color: AppColors.shadowColor, radius: 8, y: 4)
        }
    }
}

// MARK: - Preview
struct AuthenticatedTabView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticatedTabView(authViewModel: AuthViewModel())
    }
}