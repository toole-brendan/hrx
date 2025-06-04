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
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Status Icon and Text
                VStack(spacing: 16) {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(2.0)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        
                        Text("Importing Items...")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Creating property records in your inventory")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else if let error = importError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        
                        Text("Import Failed")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        Text("Import Complete!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Your DA-2062 items have been added to your inventory")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
                
                // Action Button
                if !isImporting {
                    Button(importError != nil ? "Try Again" : "Done") {
                        onDismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(importError != nil ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Import Progress")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var progressIcon: String {
        switch viewModel.progress.currentPhase {
        case .scanning, .extracting:
            return "doc.text.viewfinder"
        case .parsing:
            return "text.alignleft"
        case .validating:
            return "checkmark.shield"
        case .enriching:
            return "magnifyingglass"
        case .creating:
            return "square.and.arrow.down"
        case .complete:
            return "checkmark.circle.fill"
        }
    }
    
    private var progressColor: Color {
        switch viewModel.progress.currentPhase {
        case .complete:
            return .green
        case .scanning, .extracting, .parsing, .validating, .enriching, .creating:
            return .blue
        }
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
                    .frame(width: 24, height: 24)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else if isActive {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(phaseShortName)
                .font(.system(size: 9))
                .foregroundColor(isActive || isCompleted ? .primary : .secondary)
        }
    }
    
    private var backgroundColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .blue
        } else {
            return .gray.opacity(0.3)
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
            .fill(isCompleted ? Color.green : Color.gray.opacity(0.3))
            .frame(width: 20, height: 2)
    }
}

// MARK: - Error Review View

struct ImportErrorsView: View {
    let errors: [ImportError]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(errors) { error in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error.itemName)
                            .font(.headline)
                        
                        Text(error.error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if error.recoverable {
                            Text("This item will be imported with limited information")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Text("This item could not be imported")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Import Issues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Import Summary View

struct DA2062ImportSummaryView: View {
    let totalItems: Int
    let successfulItems: Int
    let errors: [ImportError]
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Success Icon
            Image(systemName: successfulItems == totalItems ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(successfulItems == totalItems ? .green : .orange)
            
            // Summary Text
            VStack(spacing: 8) {
                Text("Import Complete")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(successfulItems) of \(totalItems) items imported successfully")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Statistics
            HStack(spacing: 40) {
                StatView(
                    value: "\(successfulItems)",
                    label: "Imported",
                    color: .green
                )
                
                if errors.count > 0 {
                    StatView(
                        value: "\(errors.count)",
                        label: "Errors",
                        color: .red
                    )
                }
            }
            .padding()
            
            // Error List (if any)
            if !errors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed Items:")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(errors) { error in
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    
                                    Text(error.itemName)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Action Button
            Button("View My Properties") {
                onDismiss()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}

struct StatView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
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