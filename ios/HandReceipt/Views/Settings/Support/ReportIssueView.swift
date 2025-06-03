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
        ScrollView {
            VStack(spacing: 24) {
                // Spacer for header
                Color.clear
                    .frame(height: 36)
                
                // Report Issue Content
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.system(size: 60, weight: .thin))
                            .foregroundColor(AppColors.accent)
                        
                        Text("Report an Issue")
                            .font(AppFonts.serifHeadline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("Help us improve HandReceipt by reporting bugs or requesting new features.")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                }
                .cleanCard()
                .padding(.horizontal)
                
                // Issue Category Section
                VStack(alignment: .leading, spacing: 0) {
                    ElegantSectionHeader(title: "Issue Type", style: .uppercase)
                    
                    VStack(spacing: 0) {
                        ForEach(IssueCategory.allCases, id: \.self) { category in
                            IssueCategoryRow(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                            
                            if category != IssueCategory.allCases.last {
                                Divider().background(AppColors.border)
                            }
                        }
                    }
                    .cleanCard()
                    .padding(.horizontal)
                }
                
                // Issue Details Section
                VStack(alignment: .leading, spacing: 0) {
                    ElegantSectionHeader(title: "Details", style: .uppercase)
                    
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(AppFonts.bodyMedium)
                                .foregroundColor(AppColors.primaryText)
                            
                            TextField("Brief description of the issue", text: $issueTitle)
                                .textFieldStyle(MinimalTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(AppFonts.bodyMedium)
                                .foregroundColor(AppColors.primaryText)
                            
                            TextEditor(text: $issueDescription)
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.primaryText)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .background(AppColors.secondaryBackground)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                                .frame(minHeight: 100, maxHeight: 200)
                                .overlay(
                                    Group {
                                        if issueDescription.isEmpty {
                                            VStack {
                                                HStack {
                                                    Text("Please provide detailed information about the issue...")
                                                        .font(AppFonts.body)
                                                        .foregroundColor(AppColors.tertiaryText)
                                                        .padding(.top, 22)
                                                        .padding(.leading, 20)
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                )
                        }
                        
                        Button(action: submitIssue) {
                            Text("Submit Issue")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MinimalPrimaryButtonStyle())
                        .disabled(issueTitle.isEmpty || issueDescription.isEmpty)
                    }
                    .padding()
                    .cleanCard(padding: 0)
                    .padding(.horizontal)
                }
                
                // Bottom spacer
                Spacer()
                    .frame(height: 100)
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea(.all))
        .minimalNavigation(
            title: "Report Issue",
            titleStyle: .minimal,
            showBackButton: true,
            backAction: { dismiss() }
        )
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
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24)
                
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
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ReportIssueView()
} 