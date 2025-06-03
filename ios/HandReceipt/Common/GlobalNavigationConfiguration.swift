// GlobalNavigationConfiguration.swift - 8VC-inspired global navigation setup
import UIKit
import SwiftUI

// MARK: - Global Navigation Configuration
public class GlobalNavigationConfiguration {
    
    /// Configure the global navigation bar appearance for the 8VC aesthetic
    public static func configureNavigationBarAppearance() {
        // Standard Navigation Bar Appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.appBackground)
        appearance.shadowColor = .clear // Remove default shadow
        
        // Serif font for navigation titles (8VC style)
        let titleFont = UIFont.systemFont(ofSize: 17, weight: .regular)
        let largeTitleFont = UIFont.systemFont(ofSize: 34, weight: .regular)
        
        appearance.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: UIColor.label
        ]
        appearance.largeTitleTextAttributes = [
            .font: largeTitleFont,
            .foregroundColor: UIColor.label
        ]
        
        // Minimal button styling
        let barButtonItemAppearance = UIBarButtonItemAppearance()
        let buttonFont = UIFont.systemFont(ofSize: 17, weight: .regular)
        barButtonItemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.accent),
            .font: buttonFont
        ]
        
        appearance.buttonAppearance = barButtonItemAppearance
        appearance.doneButtonAppearance = barButtonItemAppearance
        
        // Apply to all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(AppColors.accent)
        
        // Add subtle shadow to navigation bars
        UINavigationBar.appearance().layer.masksToBounds = false
        UINavigationBar.appearance().layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        UINavigationBar.appearance().layer.shadowOpacity = 1.0
        UINavigationBar.appearance().layer.shadowRadius = 2.0
        UINavigationBar.appearance().layer.shadowOffset = CGSize(width: 0, height: 2)
    }
    
    /// Configure the global tab bar appearance for the 8VC aesthetic
    public static func configureTabBarAppearance() {
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
    }
    
    /// Configure all global UI appearances for the 8VC aesthetic
    public static func configureGlobalAppearance() {
        configureNavigationBarAppearance()
        configureTabBarAppearance()
        configureOtherUIElements()
    }
    
    /// Configure other UI elements like alerts, sheets, etc.
    private static func configureOtherUIElements() {
        // Configure alert appearance
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(AppColors.accent)
        
        // Note: UISheetPresentationController doesn't support appearance proxy
        // Sheet corner radius is handled per-presentation basis
        
        // Configure search bar
        UISearchBar.appearance().tintColor = UIColor(AppColors.accent)
        UISearchBar.appearance().backgroundColor = UIColor(AppColors.appBackground)
        
        // Configure text field
        UITextField.appearance().tintColor = UIColor(AppColors.accent)
        
        // Configure switches and sliders
        UISwitch.appearance().onTintColor = UIColor(AppColors.accent)
        UISlider.appearance().tintColor = UIColor(AppColors.accent)
        
        // Configure progress view
        UIProgressView.appearance().tintColor = UIColor(AppColors.accent)
        UIProgressView.appearance().trackTintColor = UIColor(AppColors.tertiaryBackground)
    }
}

// MARK: - App Delegate Integration
extension GlobalNavigationConfiguration {
    
    /// Call this method in your App's init() or SceneDelegate
    /// Example usage in HandReceiptApp.swift:
    /// ```
    /// @main
    /// struct HandReceiptApp: App {
    ///     init() {
    ///         GlobalNavigationConfiguration.configureGlobalAppearance()
    ///     }
    ///     
    ///     var body: some Scene {
    ///         // ... your app content
    ///     }
    /// }
    /// ```
    public static func initializeAppStyling() {
        configureGlobalAppearance()
    }
} 