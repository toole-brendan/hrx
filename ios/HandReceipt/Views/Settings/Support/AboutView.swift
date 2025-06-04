// AboutView.swift - About HandReceipt screen
import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                MinimalNavigationBar(
                    title: "About",
                    titleStyle: .mono,
                    showBackButton: true,
                    backAction: { dismiss() }
                )
                
                ScrollView {
                    VStack(spacing: 40) {
                        // App Info Hero Section
                        VStack(spacing: 24) {
                            GeometricPatternView()
                                .frame(height: 120)
                                .opacity(0.2)
                                .overlay(
                                    VStack(spacing: 16) {
                                        Image(systemName: "shippingbox")
                                            .font(.system(size: 48, weight: .thin))
                                            .foregroundColor(AppColors.primaryText)
                                        
                                        Text("HandReceipt")
                                            .font(AppFonts.serifTitle)
                                            .foregroundColor(AppColors.primaryText)
                                    }
                                )
                            
                            VStack(spacing: 12) {
                                Text("Digital Military Property Management")
                                    .font(AppFonts.headline)
                                    .foregroundColor(AppColors.primaryText)
                                    .multilineTextAlignment(.center)
                                
                                Text("A comprehensive digital solution for efficient equipment tracking and accountability in military environments.")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // System Information
                        VStack(alignment: .leading, spacing: 20) {
                            ElegantSectionHeader(
                                title: "System Information",
                                style: .uppercase
                            )
                            .padding(.horizontal, 24)
                            
                            VStack(spacing: 0) {
                                AboutDetailRow(
                                    label: "Version",
                                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                                    icon: "info.circle"
                                )
                                
                                Divider()
                                    .background(AppColors.divider)
                                
                                AboutDetailRow(
                                    label: "Build",
                                    value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                                    icon: "hammer"
                                )
                                
                                Divider()
                                    .background(AppColors.divider)
                                
                                AboutDetailRow(
                                    label: "Platform",
                                    value: "iOS \(UIDevice.current.systemVersion)",
                                    icon: "iphone"
                                )
                            }
                            .cleanCard(padding: 0)
                            .padding(.horizontal, 24)
                        }
                        
                        // Credits
                        VStack(alignment: .leading, spacing: 20) {
                            ElegantSectionHeader(
                                title: "Credits",
                                subtitle: "Development and acknowledgments",
                                style: .serif
                            )
                            .padding(.horizontal, 24)
                            
                            VStack(spacing: 20) {
                                CreditItem(
                                    title: "Development Team",
                                    description: "Built with dedication for military personnel and their mission-critical operations."
                                )
                                
                                CreditItem(
                                    title: "Open Source",
                                    description: "Utilizing modern frameworks and community-driven libraries."
                                )
                            }
                            .cleanCard()
                            .padding(.horizontal, 24)
                        }
                        
                        // Legal
                        VStack(alignment: .leading, spacing: 20) {
                            ElegantSectionHeader(
                                title: "Legal",
                                style: .mono
                            )
                            .padding(.horizontal, 24)
                            
                            VStack(spacing: 0) {
                                AboutActionRow(
                                    title: "Privacy Policy",
                                    icon: "hand.raised"
                                ) {
                                    // TODO: Show privacy policy
                                }
                                
                                Divider()
                                    .background(AppColors.divider)
                                
                                AboutActionRow(
                                    title: "Terms of Service",
                                    icon: "doc.text"
                                ) {
                                    // TODO: Show terms of service
                                }
                                
                                Divider()
                                    .background(AppColors.divider)
                                
                                AboutActionRow(
                                    title: "Open Source Licenses",
                                    icon: "scroll"
                                ) {
                                    // TODO: Show open source licenses
                                }
                            }
                            .cleanCard(padding: 0)
                            .padding(.horizontal, 24)
                        }
                        
                        // Copyright footer
                        VStack(spacing: 4) {
                            Text("© 2024 HandReceipt")
                                .font(AppFonts.monoCaption)
                                .foregroundColor(AppColors.tertiaryText)
                            
                            Text("All rights reserved.")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.quaternaryText)
                        }
                        .padding(.top, 20)
                        
                        // Bottom safe area
                        Color.clear.frame(height: 80)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct AboutDetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(AppColors.accent)
                .frame(width: 20)
            
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.monoBody)
                .foregroundColor(AppColors.primaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct AboutActionRow: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 20)
                
                Text(title)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CreditItem: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFonts.bodyMedium)
                .foregroundColor(AppColors.primaryText)
            
            Text(description)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    AboutView()
} 