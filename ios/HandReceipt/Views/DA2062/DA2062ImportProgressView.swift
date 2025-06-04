import SwiftUI
import Combine

// MARK: - Progress Tracking Models

struct ImportProgress {
    var totalItems: Int
    var processedItems: Int = 0
    var currentItem: String = ""
    var currentPhase: ImportPhase = .parsing
    var errors: [ImportError] = []
    
    var progress: Double {
        guard totalItems > 0 else { return 0 }
        return Double(processedItems) / Double(totalItems)
    }
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
}

enum ImportPhase: String {
    case scanning = "Scanning document..."
    case extracting = "Extracting text..."
    case parsing = "Parsing items..."
    case validating = "Validating data..."
    case enriching = "Looking up NSN data..."
    case creating = "Creating property records..."
    case complete = "Import complete"
}

struct ImportError: Identifiable {
    let id = UUID()
    let itemName: String
    let error: String
    let recoverable: Bool
}

// MARK: - Progress View

struct DA2062ImportProgressView: View {
    @Binding var isImporting: Bool
    @Binding var importError: String?
    let onDismiss: () -> Void
    @State private var showingErrors = false
    
    var body: some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: "IMPORT PROGRESS",
                titleStyle: .mono,
                showBackButton: false,
                trailingItems: []
            )
            
            VStack(spacing: 40) {
                Spacer()
                
                // Status Icon and Text
                VStack(spacing: 20) {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        
                        Text("Importing Items...")
                            .font(AppFonts.serifHeadline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("Creating property records in your inventory")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                    } else if let error = importError {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 64, weight: .thin))
                            .foregroundColor(AppColors.destructive)
                        
                        Text("Import Failed")
                            .font(AppFonts.serifHeadline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(error)
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 64, weight: .thin))
                            .foregroundColor(AppColors.success)
                        
                        Text("Import Complete!")
                            .font(AppFonts.serifHeadline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("Your DA-2062 items have been added to your inventory")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
                
                // Action Button
                if !isImporting {
                    Button(importError != nil ? "Try Again" : "Done") {
                        onDismiss()
                    }
                    .buttonStyle(MinimalPrimaryButtonStyle())
                    .padding(.horizontal, 24)
                }
                
                // Bottom spacer
                Color.clear.frame(height: 40)
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Phase Indicator View

struct PhaseIndicatorView: View {
    let currentPhase: ImportPhase
    
    private let phases: [ImportPhase] = [
        .scanning,
        .extracting,
        .parsing,
        .validating,
        .enriching,
        .creating
    ]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(phases, id: \.self) { phase in
                PhaseIndicator(
                    phase: phase,
                    isActive: phase == currentPhase,
                    isCompleted: isPhaseCompleted(phase)
                )
                
                if phase != phases.last {
                    PhaseConnector(isCompleted: isPhaseCompleted(phase))
                }
            }
        }
    }
    
    private func isPhaseCompleted(_ phase: ImportPhase) -> Bool {
        guard let currentIndex = phases.firstIndex(of: currentPhase),
              let phaseIndex = phases.firstIndex(of: phase) else {
            return false
        }
        return phaseIndex < currentIndex
    }
}

struct PhaseIndicator: View {
    let phase: ImportPhase
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 20, height: 20)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                } else if isActive {
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                }
            }
            
            Text(phaseShortName)
                .font(AppFonts.caption)
                .foregroundColor(isActive || isCompleted ? AppColors.primaryText : AppColors.tertiaryText)
        }
    }
    
    private var backgroundColor: Color {
        if isCompleted {
            return AppColors.success
        } else if isActive {
            return AppColors.accent
        } else {
            return AppColors.border
        }
    }
    
    private var phaseShortName: String {
        switch phase {
        case .scanning: return "Scan"
        case .extracting: return "Extract"
        case .parsing: return "Parse"
        case .validating: return "Validate"
        case .enriching: return "Enrich"
        case .creating: return "Create"
        case .complete: return "Done"
        }
    }
}

struct PhaseConnector: View {
    let isCompleted: Bool
    
    var body: some View {
        Rectangle()
            .fill(isCompleted ? AppColors.success : AppColors.border)
            .frame(width: 16, height: 1)
    }
}

// MARK: - Error Review View

struct ImportErrorsView: View {
    let errors: [ImportError]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: "IMPORT ISSUES",
                titleStyle: .mono,
                showBackButton: false,
                trailingItems: [
                    .init(text: "Done", style: .text, action: { dismiss() })
                ]
            )
            
            List {
                ForEach(errors) { error in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(error.itemName)
                            .font(AppFonts.bodyMedium)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(error.error)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        if error.recoverable {
                            Text("This item will be imported with limited information")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.warning)
                        } else {
                            Text("This item could not be imported")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.destructive)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(PlainListStyle())
            .background(AppColors.appBackground)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Import Summary View

struct DA2062ImportSummaryView: View {
    let totalItems: Int
    let successfulItems: Int
    let errors: [ImportError]
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: "IMPORT SUMMARY",
                titleStyle: .mono,
                showBackButton: false,
                trailingItems: []
            )
            
            ScrollView {
                VStack(spacing: 32) {
                    // Top padding
                    Color.clear.frame(height: 16)
                    
                    // Success Icon
                    Image(systemName: successfulItems == totalItems ? "checkmark.circle" : "exclamationmark.triangle")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundColor(successfulItems == totalItems ? AppColors.success : AppColors.warning)
                    
                    // Summary Text
                    VStack(spacing: 12) {
                        Text("Import Complete")
                            .font(AppFonts.serifHeadline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("\(successfulItems) of \(totalItems) items imported successfully")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    // Statistics
                    HStack(spacing: 40) {
                        StatView(
                            value: "\(successfulItems)",
                            label: "Imported",
                            color: AppColors.success
                        )
                        
                        if errors.count > 0 {
                            StatView(
                                value: "\(errors.count)",
                                label: "Errors",
                                color: AppColors.destructive
                            )
                        }
                    }
                    
                    // Error List (if any)
                    if !errors.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Failed Items:")
                                .font(AppFonts.bodyMedium)
                                .foregroundColor(AppColors.primaryText)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(errors) { error in
                                        HStack(spacing: 8) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(AppColors.destructive)
                                                .font(.caption)
                                            
                                            Text(error.itemName)
                                                .font(AppFonts.caption)
                                                .foregroundColor(AppColors.primaryText)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 100)
                        }
                        .cleanCard(padding: 16)
                        .padding(.horizontal, 24)
                    }
                    
                    // Action Button
                    Button("View My Properties") {
                        onDismiss()
                    }
                    .buttonStyle(MinimalPrimaryButtonStyle())
                    .padding(.horizontal, 24)
                    
                    // Bottom spacer
                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

struct StatView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.monoHeadline)
                .foregroundColor(color)
            
            Text(label)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
        }
    }
}

// MARK: - Supporting Types

struct ParsedDA2062Item {
    let lineNumber: Int
    let nsn: String?
    let lin: String?
    let description: String
    let quantity: Int
    let unitOfIssue: String
    let serialNumber: String?
    let confidence: Double
}

struct ValidatedItem {
    let parsed: ParsedDA2062Item
    let isValid: Bool
    let confidence: Double
}

struct EnrichedItem {
    let validated: ValidatedItem
    var officialName: String?
    var manufacturer: String?
    var partNumber: String?
} 