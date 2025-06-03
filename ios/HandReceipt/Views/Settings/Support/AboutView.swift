// AboutView.swift - About HandReceipt screen
import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Spacer for header
                Color.clear
                    .frame(height: 36)
                
                // App Info Content
                VStack(spacing: 0) {
                    VStack(spacing: 24) {
                        // App Icon and Title
                        VStack(spacing: 16) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 80, weight: .thin))
                                .foregroundColor(AppColors.accent)
                            
                            Text("HandReceipt")
                                .font(AppFonts.serifTitle)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("Digital Military Property Management")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Description
                        VStack(spacing: 12) {
                            Text("A comprehensive digital solution for efficient equipment tracking and accountability in military environments.")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                            
                            Text("Built with modern technology to streamline property management processes and ensure accurate record-keeping.")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(32)
                }
                .cleanCard()
                .padding(.horizontal)
                
                // App Details Section
                VStack(alignment: .leading, spacing: 0) {
                    ElegantSectionHeader(title: "Application Details", style: .uppercase)
                    
                    VStack(spacing: 0) {
                        AboutDetailRow(
                            label: "Version",
                            value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                            icon: "info.circle"
                        )
                        
                        Divider().background(AppColors.border)
                        
                        AboutDetailRow(
                            label: "Build",
                            value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                            icon: "hammer"
                        )
                        
                        Divider().background(AppColors.border)
                        
                        AboutDetailRow(
                            label: "Platform",
                            value: "iOS \(UIDevice.current.systemVersion)",
                            icon: "iphone"
                        )
                        
                        Divider().background(AppColors.border)
                        
                        AboutDetailRow(
                            label: "Device",
                            value: UIDevice.current.model,
                            icon: "display"
                        )
                    }
                    .cleanCard()
                    .padding(.horizontal)
                }
                
                // Credits Section
                VStack(alignment: .leading, spacing: 0) {
                    ElegantSectionHeader(title: "Credits", style: .uppercase)
                    
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Text("Development Team")
                                .font(AppFonts.bodyMedium)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("Built with dedication for military personnel and their mission-critical operations.")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Open Source Libraries")
                                .font(AppFonts.bodyMedium)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("This application utilizes various open source components and libraries.")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                    .cleanCard(padding: 0)
                    .padding(.horizontal)
                }
                
                // Legal Section
                VStack(alignment: .leading, spacing: 0) {
                    ElegantSectionHeader(title: "Legal", style: .uppercase)
                    
                    VStack(spacing: 0) {
                        AboutActionRow(
                            title: "Privacy Policy",
                            icon: "hand.raised"
                        ) {
                            // TODO: Show privacy policy
                        }
                        
                        Divider().background(AppColors.border)
                        
                        AboutActionRow(
                            title: "Terms of Service",
                            icon: "doc.text"
                        ) {
                            // TODO: Show terms of service
                        }
                        
                        Divider().background(AppColors.border)
                        
                        AboutActionRow(
                            title: "Licenses",
                            icon: "scroll"
                        ) {
                            // TODO: Show open source licenses
                        }
                    }
                    .cleanCard()
                    .padding(.horizontal)
                }
                
                // Copyright
                VStack(spacing: 8) {
                    Text("© 2024 HandReceipt")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                    
                    Text("All rights reserved.")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                }
                .padding(.top, 16)
                
                // Bottom spacer
                Spacer()
                    .frame(height: 100)
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea(.all))
        .minimalNavigation(
            title: "About",
            titleStyle: .minimal,
            showBackButton: true,
            backAction: { dismiss() }
        )
    }
}

struct AboutDetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.accent)
                .frame(width: 24)
            
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.monoBody)
                .foregroundColor(AppColors.primaryText)
        }
        .padding()
    }
}

struct AboutActionRow: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24)
                
                Text(title)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
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

#Preview {
    AboutView()
} 