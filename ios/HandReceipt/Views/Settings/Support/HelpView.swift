// HelpView.swift - Help and documentation screen
import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: "HELP",
                titleStyle: .mono,
                showBackButton: true,
                backAction: { dismiss() }
            )
            
            ScrollView {
                VStack(spacing: 32) {
                    // Top padding
                    Color.clear.frame(height: 16)
                    
                    // Help Content
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 64, weight: .thin))
                                .foregroundColor(AppColors.accent)
                            
                            Text("Help & Documentation")
                                .font(AppFonts.serifHeadline)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("Comprehensive help documentation will be available here. In the meantime, you can contact support for assistance with HandReceipt features.")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .cleanCard(padding: 24)
                    .padding(.horizontal, 24)
                    
                    // Quick Help Section
                    VStack(alignment: .leading, spacing: 16) {
                        ElegantSectionHeader(title: "Quick Help", style: .uppercase)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            HelpTopicRow(
                                title: "Getting Started",
                                description: "Learn the basics of HandReceipt",
                                icon: "play.circle"
                            )
                            
                            Rectangle()
                                .fill(AppColors.divider)
                                .frame(height: 1)
                            
                            HelpTopicRow(
                                title: "Property Management",
                                description: "Managing your assigned property",
                                icon: "shippingbox"
                            )
                            
                            Rectangle()
                                .fill(AppColors.divider)
                                .frame(height: 1)
                            
                            HelpTopicRow(
                                title: "Transfers",
                                description: "How to transfer property",
                                icon: "arrow.left.arrow.right"
                            )
                            
                            Rectangle()
                                .fill(AppColors.divider)
                                .frame(height: 1)
                            
                            HelpTopicRow(
                                title: "Troubleshooting",
                                description: "Common issues and solutions",
                                icon: "wrench"
                            )
                        }
                        .cleanCard(padding: 0)
                        .padding(.horizontal, 24)
                    }
                    
                    // Bottom spacer
                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea())
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
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFonts.body)
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
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HelpView()
} 