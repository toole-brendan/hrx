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
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                MinimalNavigationBar(
                    title: "Report Issue",
                    titleStyle: .serif,
                    showBackButton: true,
                    backAction: { dismiss() }
                )
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Issue Report Hero
                        VStack(spacing: 24) {
                            GeometricPatternView()
                                .frame(height: 100)
                                .opacity(0.2)
                                .overlay(
                                    VStack(spacing: 12) {
                                        Image(systemName: "exclamationmark.bubble")
                                            .font(.system(size: 40, weight: .thin))
                                            .foregroundColor(AppColors.primaryText)
                                        
                                        Text("Report an Issue")
                                            .font(AppFonts.serifHeadline)
                                            .foregroundColor(AppColors.primaryText)
                                    }
                                )
                            
                            Text("Help us improve HandReceipt by reporting bugs or requesting new features.")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        
                        // Issue Category Selection
                        VStack(alignment: .leading, spacing: 16) {
                            ElegantSectionHeader(
                                title: "Issue Type",
                                style: .uppercase
                            )
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
                                        Divider()
                                            .background(AppColors.divider)
                                    }
                                }
                            }
                            .cleanCard(padding: 0)
                            .padding(.horizontal, 24)
                        }
                        
                        // Issue Details Form
                        VStack(alignment: .leading, spacing: 16) {
                            ElegantSectionHeader(
                                title: "Details",
                                style: .uppercase
                            )
                            .padding(.horizontal, 24)
                            
                            VStack(spacing: 20) {
                                // Title Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TITLE")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                        .kerning(AppFonts.wideKerning)
                                    
                                    TextField("Brief description of the issue", text: $issueTitle)
                                        .font(AppFonts.body)
                                        .foregroundColor(AppColors.primaryText)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(AppColors.tertiaryBackground)
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(AppColors.border, lineWidth: 1)
                                        )
                                }
                                
                                // Description Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("DESCRIPTION")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                        .kerning(AppFonts.wideKerning)
                                    
                                    ZStack(alignment: .topLeading) {
                                        TextEditor(text: $issueDescription)
                                            .font(AppFonts.body)
                                            .foregroundColor(AppColors.primaryText)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(AppColors.tertiaryBackground)
                                            .cornerRadius(4)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(AppColors.border, lineWidth: 1)
                                            )
                                            .frame(minHeight: 100)
                                        
                                        if issueDescription.isEmpty {
                                            Text("Please provide detailed information about the issue...")
                                                .font(AppFonts.body)
                                                .foregroundColor(AppColors.tertiaryText)
                                                .padding(.horizontal, 20)
                                                .padding(.top, 18)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                }
                                
                                // Submit Button
                                Button(action: submitIssue) {
                                    Text("Submit Issue")
                                }
                                .buttonStyle(MinimalPrimaryButtonStyle())
                                .disabled(issueTitle.isEmpty || issueDescription.isEmpty)
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
            HStack(spacing: 16) {
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
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ReportIssueView()
} 