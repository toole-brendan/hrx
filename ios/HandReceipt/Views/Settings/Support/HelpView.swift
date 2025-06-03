// HelpView.swift - Help and documentation screen
import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Spacer for header
                Color.clear
                    .frame(height: 36)
                
                // Help Content
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 60, weight: .thin))
                            .foregroundColor(AppColors.accent)
                        
                        Text("Help & Documentation")
                            .font(AppFonts.serifHeadline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("Comprehensive help documentation will be available here. In the meantime, you can contact support for assistance with HandReceipt features.")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                }
                .cleanCard()
                .padding(.horizontal)
                
                // Quick Help Section
                VStack(alignment: .leading, spacing: 0) {
                    ElegantSectionHeader(title: "Quick Help", style: .uppercase)
                    
                    VStack(spacing: 0) {
                        HelpTopicRow(
                            title: "Getting Started",
                            description: "Learn the basics of HandReceipt",
                            icon: "play.circle"
                        )
                        
                        Divider().background(AppColors.border)
                        
                        HelpTopicRow(
                            title: "Property Management",
                            description: "Managing your assigned property",
                            icon: "shippingbox"
                        )
                        
                        Divider().background(AppColors.border)
                        
                        HelpTopicRow(
                            title: "Transfers",
                            description: "How to transfer property",
                            icon: "arrow.left.arrow.right"
                        )
                        
                        Divider().background(AppColors.border)
                        
                        HelpTopicRow(
                            title: "Troubleshooting",
                            description: "Common issues and solutions",
                            icon: "wrench"
                        )
                    }
                    .cleanCard()
                    .padding(.horizontal)
                }
                
                // Bottom spacer
                Spacer()
                    .frame(height: 100)
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea(.all))
        .minimalNavigation(
            title: "Help",
            titleStyle: .minimal,
            showBackButton: true,
            backAction: { dismiss() }
        )
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
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24)
                
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
    HelpView()
} 