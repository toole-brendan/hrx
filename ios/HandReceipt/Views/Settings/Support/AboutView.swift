// AboutView.swift - About HandReceipt screen
import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: "ABOUT",
                titleStyle: .mono,
                showBackButton: true,
                backAction: { dismiss() }
            )
            
            ScrollView {
                VStack(spacing: 32) {
                    // Top padding
                    Color.clear.frame(height: 16)
                    
                    // App Info Content
                    VStack(spacing: 24) {
                        // App Icon and Title
                        VStack(spacing: 16) {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 64, weight: .thin))
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
                    .cleanCard(padding: 24)
                    .padding(.horizontal, 24)
                    
                    // App Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        ElegantSectionHeader(title: "Application Details", style: .uppercase)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            AboutDetailRow(
                                label: "Version",
                                value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                                icon: "info.circle"
                            )
                            
                            Rectangle()
                                .fill(AppColors.divider)
                                .frame(height: 1)
                            
                            AboutDetailRow(
                                label: "Build",
                                value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                                icon: "hammer"
                            )
                            
                            Rectangle()
                                .fill(AppColors.divider)
                                .frame(height: 1)
                            
                            AboutDetailRow(
                                label: "Platform",
                                value: "iOS \(UIDevice.current.systemVersion)",
                                icon: "iphone"
                            )
                            
                            Rectangle()
                                .fill(AppColors.divider)
                                .frame(height: 1)
                            
                            AboutDetailRow(
                                label: "Device",
                                value: UIDevice.current.model,
                                icon: "display"
                            )
                        }
                        .cleanCard(padding: 0)
                        .padding(.horizontal, 24)
                    }
                    
                    // Credits Section
                    VStack(alignment: .leading, spacing: 16) {
                        ElegantSectionHeader(title: "Credits", style: .uppercase)
                            .padding(.horizontal, 24)
                        
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
                        .cleanCard(padding: 20)
                        .padding(.horizontal, 24)
                    }
                    
                    // Legal Section
                    VStack(alignment: .leading, spacing: 16) {
                        ElegantSectionHeader(title: "Legal", style: .uppercase)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            AboutActionRow(
                                title: "Privacy Policy",
                                icon: "hand.raised"
                            ) {
                                // TODO: Show privacy policy
                            }
                            
                            Rectangle()
                                .fill(AppColors.divider)
                                .frame(height: 1)
                            
                            AboutActionRow(
                                title: "Terms of Service",
                                icon: "doc.text"
                            ) {
                                // TODO: Show terms of service
                            }
                            
                            Rectangle()
                                .fill(AppColors.divider)
                                .frame(height: 1)
                            
                            AboutActionRow(
                                title: "Licenses",
                                icon: "scroll"
                            ) {
                                // TODO: Show open source licenses
                            }
                        }
                        .cleanCard(padding: 0)
                        .padding(.horizontal, 24)
                    }
                    
                    // Copyright
                    VStack(spacing: 4) {
                        Text("© 2024 HandReceipt")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                        
                        Text("All rights reserved.")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    .padding(.top, 8)
                    
                    // Bottom spacer
                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

struct AboutDetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
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
        .padding(.vertical, 14)
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
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AboutView()
} 