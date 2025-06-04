// ReportIssueView.swift - Issue reporting screen
import SwiftUI

struct ReportIssueView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var issueTitle = ""
    @State private var issueDescription = ""
    @State private var selectedCategory = IssueCategory.bug
    
    enum IssueCategory: String, CaseIterable {
        case bug = "Bug Report"
        case feature = "Feature Request"
        case performance = "Performance Issue"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .bug: return "ant"
            case .feature: return "lightbulb"
            case .performance: return "speedometer"
            case .other: return "questionmark.circle"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: "REPORT ISSUE",
                titleStyle: .mono,
                showBackButton: true,
                backAction: { dismiss() }
            )
            
            ScrollView {
                VStack(spacing: 32) {
                    // Top padding
                    Color.clear.frame(height: 16)
                    
                    // Report Issue Content
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.bubble")
                                .font(.system(size: 64, weight: .thin))
                                .foregroundColor(AppColors.accent)
                            
                            Text("Report an Issue")
                                .font(AppFonts.serifHeadline)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("Help us improve HandReceipt by reporting bugs or requesting new features.")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .cleanCard(padding: 24)
                    .padding(.horizontal, 24)
                    
                    // Issue Category Section
                    VStack(alignment: .leading, spacing: 16) {
                        ElegantSectionHeader(title: "Issue Type", style: .uppercase)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            ForEach(IssueCategory.allCases, id: \.self) { category in
                                IssueCategoryRow(
                                    category: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                                
                                if category != IssueCategory.allCases.last {
                                    Rectangle()
                                        .fill(AppColors.divider)
                                        .frame(height: 1)
                                }
                            }
                        }
                        .cleanCard(padding: 0)
                        .padding(.horizontal, 24)
                    }
                    
                    // Issue Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        ElegantSectionHeader(title: "Details", style: .uppercase)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Title")
                                    .font(AppFonts.bodyMedium)
                                    .foregroundColor(AppColors.primaryText)
                                
                                TextField("Brief description of the issue", text: $issueTitle)
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.primaryText)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(AppColors.secondaryBackground)
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(AppColors.border, lineWidth: 1)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(AppFonts.bodyMedium)
                                    .foregroundColor(AppColors.primaryText)
                                
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $issueDescription)
                                        .font(AppFonts.body)
                                        .foregroundColor(AppColors.primaryText)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(AppColors.secondaryBackground)
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(AppColors.border, lineWidth: 1)
                                        )
                                        .frame(minHeight: 120)
                                    
                                    if issueDescription.isEmpty {
                                        Text("Please provide detailed information about the issue...")
                                            .font(AppFonts.body)
                                            .foregroundColor(AppColors.tertiaryText)
                                            .padding(.horizontal, 20)
                                            .padding(.top, 22)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                            
                            Button(action: submitIssue) {
                                Text("Submit Issue")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(MinimalPrimaryButtonStyle())
                            .disabled(issueTitle.isEmpty || issueDescription.isEmpty)
                        }
                        .cleanCard(padding: 20)
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
    
    private func submitIssue() {
        // TODO: Implement issue submission
        print("Submitting issue: \(issueTitle)")
        dismiss()
    }
}

struct IssueCategoryRow: View {
    let category: ReportIssueView.IssueCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 20)
                
                Text(category.rawValue)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.accent)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.tertiaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ReportIssueView()
} 