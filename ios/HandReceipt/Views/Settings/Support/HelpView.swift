// HelpView.swift - Help and documentation screen
import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                MinimalNavigationBar(
                    title: "Help & Support",
                    titleStyle: .serif,
                    showBackButton: true,
                    backAction: { dismiss() }
                )
                
                ScrollView {
                    VStack(spacing: 40) {
                        // Help Hero Section
                        VStack(spacing: 24) {
                            GeometricPatternView()
                                .frame(height: 120)
                                .opacity(0.2)
                                .overlay(
                                    VStack(spacing: 16) {
                                        Image(systemName: "questionmark.circle")
                                            .font(.system(size: 48, weight: .thin))
                                            .foregroundColor(AppColors.primaryText)
                                        
                                        Text("Help & Documentation")
                                            .font(AppFonts.serifHeadline)
                                            .foregroundColor(AppColors.primaryText)
                                    }
                                )
                            
                            Text("Comprehensive guides and troubleshooting resources for HandReceipt features and functionality.")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        
                        // Quick Help Topics
                        VStack(alignment: .leading, spacing: 20) {
                            ElegantSectionHeader(
                                title: "Quick Help",
                                subtitle: "Common topics and guides",
                                style: .uppercase
                            )
                            .padding(.horizontal, 24)
                            
                            VStack(spacing: 0) {
                                HelpTopicRow(
                                    title: "Getting Started",
                                    description: "Learn the basics of HandReceipt",
                                    icon: "play.circle"
                                )
                                
                                Divider()
                                    .background(AppColors.divider)
                                
                                HelpTopicRow(
                                    title: "Property Management",
                                    description: "Managing your assigned property",
                                    icon: "shippingbox"
                                )
                                
                                Divider()
                                    .background(AppColors.divider)
                                
                                HelpTopicRow(
                                    title: "Transfer Process",
                                    description: "How to transfer property between users",
                                    icon: "arrow.left.arrow.right"
                                )
                                
                                Divider()
                                    .background(AppColors.divider)
                                
                                HelpTopicRow(
                                    title: "Troubleshooting",
                                    description: "Common issues and solutions",
                                    icon: "wrench"
                                )
                            }
                            .cleanCard(padding: 0)
                            .padding(.horizontal, 24)
                        }
                        
                        // Support Contact
                        VStack(alignment: .leading, spacing: 20) {
                            ElegantSectionHeader(
                                title: "Support",
                                style: .mono
                            )
                            .padding(.horizontal, 24)
                            
                            VStack(spacing: 16) {
                                SupportContactCard(
                                    title: "Contact Support",
                                    description: "Get help from our support team",
                                    icon: "envelope",
                                    action: "support@handreceipt.mil"
                                )
                                
                                SupportContactCard(
                                    title: "Report Issue",
                                    description: "Report bugs or request features",
                                    icon: "exclamationmark.bubble",
                                    action: "Submit Report"
                                )
                            }
                            .cleanCard()
                            .padding(.horizontal, 24)
                        }
                        
                        // Bottom safe area
                        Color.clear.frame(height: 80)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct HelpTopicRow: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        Button(action: {
            // TODO: Navigate to specific help topic
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(description)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                }
                
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

struct SupportContactCard: View {
    let title: String
    let description: String
    let icon: String
    let action: String
    
    var body: some View {
        Button(action: {
            // TODO: Handle support contact action
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(description)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Text(action)
                        .font(AppFonts.monoCaption)
                        .foregroundColor(AppColors.accent)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(AppColors.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HelpView()
} 