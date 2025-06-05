//ios/HandReceipt/Views/DA2062/DA2062ImportProgressView.swift

import SwiftUI
import Combine

// MARK: - Progress Tracking Models (using models from DA2062Models.swift)

// MARK: - Progress View

struct DA2062ImportProgressView: View {
    @StateObject private var viewModel = DA2062ImportViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let sourceImage: UIImage
    let confirmedItems: [EditableDA2062Item]?
    
    // Initialize with just source image (legacy support)
    init(sourceImage: UIImage) {
        self.sourceImage = sourceImage
        self.confirmedItems = nil
    }
    
    // Initialize with confirmed items from review
    init(sourceImage: UIImage, confirmedItems: [EditableDA2062Item]) {
        self.sourceImage = sourceImage
        self.confirmedItems = confirmedItems
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header with OCR mode indicator
                HStack {
                    VStack(alignment: .leading) {
                        Text(confirmedItems != nil ? "Final Import" : "DA 2062 Import")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if confirmedItems != nil {
                            Text("Creating property records from reviewed items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            HStack {
                                Image(systemName: viewModel.useAzureOCR ? "cloud.fill" : "iphone")
                                    .foregroundColor(viewModel.useAzureOCR ? .blue : .orange)
                                Text(viewModel.useAzureOCR ? "Azure Computer Vision" : "Local OCR")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // OCR mode toggle (only if not using confirmed items)
                    if !viewModel.isImporting && confirmedItems == nil {
                        Button(action: {
                            viewModel.toggleOCRMode()
                        }) {
                            Image(systemName: "arrow.2.squarepath")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Progress Section
                ProgressCard(
                    phase: viewModel.progress.currentPhase,
                    currentItem: viewModel.progress.currentItem,
                    totalItems: viewModel.progress.totalItems,
                    processedItems: viewModel.progress.processedItems,
                    isImporting: viewModel.isImporting,
                    useAzureOCR: confirmedItems != nil ? false : viewModel.useAzureOCR
                )
                
                // Status Information
                if viewModel.isImporting {
                    ImportStatusCard(
                        progress: viewModel.progress, 
                        useAzureOCR: confirmedItems != nil ? false : viewModel.useAzureOCR
                    )
                }
                
                // Error Display
                if !viewModel.progress.errors.isEmpty {
                    ErrorCard(errors: viewModel.progress.errors)
                }
                
                // Success Summary
                if viewModel.showingSummary {
                    let summary = viewModel.importSummary
                    ImportSummaryCard(
                        totalItems: summary.total,
                        successfulItems: summary.successful,
                        useAzureOCR: confirmedItems != nil ? false : viewModel.useAzureOCR
                    )
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    if viewModel.isImporting {
                        Button("Cancel") {
                            viewModel.cancelImport()
                        }
                        .buttonStyle(.bordered)
                    } else if viewModel.showingSummary {
                        Button("Complete") {
                            viewModel.completeImport()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(confirmedItems != nil ? "Create Properties" : "Start Import") {
                            Task {
                                if let items = confirmedItems {
                                    await viewModel.processConfirmedItems(items)
                                } else {
                                    await viewModel.processDA2062WithProgress(image: sourceImage)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isImporting)
                    }
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled(viewModel.isImporting)
    }
}

// Enhanced progress card showing Azure integration
struct ProgressCard: View {
    let phase: ImportPhase
    let currentItem: String
    let totalItems: Int
    let processedItems: Int
    let isImporting: Bool
    let useAzureOCR: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Phase indicator with enhanced descriptions
            HStack {
                PhaseIndicator(
                    phase: phase,
                    isActive: isImporting,
                    useAzureOCR: useAzureOCR
                )
                
                Spacer()
                
                if totalItems > 0 {
                    Text("\(processedItems)/\(totalItems)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            if totalItems > 0 {
                ProgressView(value: Double(processedItems), total: Double(totalItems))
                    .progressViewStyle(LinearProgressViewStyle())
            } else if isImporting {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle())
            }
            
            // Current item
            if !currentItem.isEmpty {
                Text(currentItem)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// Enhanced phase indicator with Azure-specific phases
struct PhaseIndicator: View {
    let phase: ImportPhase
    let isActive: Bool
    let useAzureOCR: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForPhase(phase))
                .foregroundColor(isActive ? .accentColor : .secondary)
                .rotationEffect(.degrees(isActive ? 360 : 0))
                .animation(isActive ? .linear(duration: 2).repeatForever(autoreverses: false) : .default, value: isActive)
            
            Text(titleForPhase(phase))
                .font(.headline)
                .foregroundColor(isActive ? .primary : .secondary)
        }
    }
    
    private func iconForPhase(_ phase: ImportPhase) -> String {
        switch phase {
        case .scanning:
            return useAzureOCR ? "cloud.upload" : "doc.text.viewfinder"
        case .extracting:
            return useAzureOCR ? "brain.head.profile" : "textformat.abc"
        case .parsing:
            return "list.bullet.clipboard"
        case .validating:
            return "checkmark.shield"
        case .enriching:
            return "magnifyingglass.circle"
        case .creating:
            return "plus.circle"
        case .complete:
            return "checkmark.circle.fill"
        }
    }
    
    private func titleForPhase(_ phase: ImportPhase) -> String {
        switch phase {
        case .scanning:
            return useAzureOCR ? "Uploading to Azure" : "Scanning Document"
        case .extracting:
            return useAzureOCR ? "Azure Computer Vision" : "Local OCR Processing"
        case .parsing:
            return "Parsing Items"
        case .validating:
            return "Validating Data"
        case .enriching:
            return "Enriching Items"
        case .creating:
            return "Creating Records & Logging to Ledger"
        case .complete:
            return "Import Complete"
        }
    }
}

// Import status card with ledger information
struct ImportStatusCard: View {
    let progress: ImportProgress
    let useAzureOCR: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Import Status")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(
                    icon: "cloud.fill",
                    title: "OCR Processing",
                    value: useAzureOCR ? "Azure Computer Vision" : "Local Vision Framework"
                )
                
                StatusRow(
                    icon: "lock.shield",
                    title: "Ledger Logging",
                    value: "Azure Immutable Ledger"
                )
                
                if progress.totalItems > 0 {
                    StatusRow(
                        icon: "list.number",
                        title: "Items Processed",
                        value: "\(progress.processedItems) of \(progress.totalItems)"
                    )
                }
                
                if !progress.errors.isEmpty {
                    StatusRow(
                        icon: "exclamationmark.triangle",
                        title: "Errors",
                        value: "\(progress.errors.count)"
                    )
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct StatusRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// Error display card
struct ErrorCard: View {
    let errors: [ImportError]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Import Issues")
                    .font(.headline)
                Spacer()
            }
            
            ForEach(errors.indices, id: \.self) { index in
                let error = errors[index]
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.itemName)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(error.error)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if index < errors.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// Import summary card with ledger confirmation
struct ImportSummaryCard: View {
    let totalItems: Int
    let successfulItems: Int
    let useAzureOCR: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Import Complete")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                SummaryRow(
                    title: "Items Successfully Created",
                    value: "\(successfulItems) of \(totalItems)"
                )
                
                SummaryRow(
                    title: "OCR Method",
                    value: useAzureOCR ? "Azure Computer Vision" : "Local Processing"
                )
                
                SummaryRow(
                    title: "Ledger Status",
                    value: "✅ Logged to Azure Immutable Ledger"
                )
                
                if successfulItems < totalItems {
                    let failed = totalItems - successfulItems
                    SummaryRow(
                        title: "Failed Items",
                        value: "\(failed) (see errors above)"
                    )
                }
            }
            
            Text("All property creations have been logged to the Azure Immutable Ledger for audit trail and compliance.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Phase Indicator View

struct PhaseIndicatorView: View {
    let currentPhase: ImportPhase
    let useAzureOCR: Bool = true  // Default value for now
    
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
                    useAzureOCR: useAzureOCR
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

// MARK: - Supporting Types (using models from DA2062Models.swift) 