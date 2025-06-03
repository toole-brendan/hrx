// AuthenticatedTabView.swift - Updated with MinimalTabBar
import SwiftUI

struct AuthenticatedTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var documentService = DocumentService.shared
    
    // Services
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content using custom implementation instead of TabView
            tabContent
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
            
            // Custom minimal tab bar
            MinimalTabBar(
                selectedTab: $selectedTab,
                items: [
                    .init(icon: "house", label: "Home", tag: 0),
                    .init(icon: "shippingbox", label: "Property", tag: 1),
                    .init(icon: "arrow.left.arrow.right", label: "Transfers", tag: 2),
                    .init(icon: "person", label: "Profile", tag: 3, badge: documentService.unreadCount > 0 ? "\(documentService.unreadCount)" : nil)
                ]
            )
        }
        .background(AppColors.appBackground)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        NavigationView {
            switch selectedTab {
            case 0:
                DashboardView(
                    apiService: apiService,
                    onTabSwitch: { tab in
                        withAnimation {
                            selectedTab = tab
                        }
                    }
                )
                .transition(.opacity)
                
            case 1:
                MyPropertiesView()
                
            case 2:
                TransfersView(apiService: apiService)
                    .transition(.opacity)
                
            case 3:
                ProfileView()
                    .transition(.opacity)
                
            default:
                DashboardView(
                    apiService: apiService,
                    onTabSwitch: { tab in
                        withAnimation {
                            selectedTab = tab
                        }
                    }
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

