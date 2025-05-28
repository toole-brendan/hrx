import SwiftUI

struct TransfersView: View {
    // Inject AuthViewModel to get current user ID
    // @StateObject private var authViewModel = AuthViewModel() // Consider using @EnvironmentObject if provided higher up
    // Initialize TransfersViewModel with the current user ID
    @StateObject private var viewModel: TransfersViewModel

    // Initializer to inject current user ID
    // TODO: Inject AuthViewModel or User ID more cleanly (e.g., EnvironmentObject or direct injection)
    init() {
        // Temporarily create AuthViewModel here to get ID. Ideally, AuthViewModel would be an EnvironmentObject.
        let authVM = AuthViewModel()
        let initialViewModel = TransfersViewModel(currentUserId: authVM.currentUser?.userId)
        _viewModel = StateObject(wrappedValue: initialViewModel)
        // Configure appearance once, perhaps in App initialisation if possible
        Self.configureSegmentedControlAppearance() 
    }

    var body: some View {
        VStack(spacing: 0) { // Use VStack to hold Pickers and List
            filterControls // Keep filter controls separate
            Divider().background(AppColors.secondaryText.opacity(0.2)) // Subtle divider
            listContent // Extracted list content
        }
        .background(AppColors.appBackground.ignoresSafeArea()) // Consistent background
        .navigationTitle("Transfers")
        .navigationBarTitleDisplayMode(.inline) // Keep title inline for minimalist look
        .toolbar {
             ToolbarItem(placement: .navigationBarTrailing) {
                  Button {
                      viewModel.fetchTransfers()
                  } label: {
                      Image(systemName: "arrow.clockwise") // Use image directly
                          .foregroundColor(AppColors.accent) // Themed color
                  }
                  .disabled(viewModel.loadingState == TransfersViewModel.LoadingState.loading)
              }
          }
        // .onAppear { 
        //     // Appearance should ideally be set once globally
        //     Self.configureSegmentedControlAppearance()
        // }
    }

    // Configure Segmented Control Appearance (Static method to avoid re-applying)
    private static func configureSegmentedControlAppearance() {
        let appearance = UISegmentedControl.appearance()
        appearance.backgroundColor = UIColor(AppColors.secondaryBackground) // Match filter background
        appearance.selectedSegmentTintColor = UIColor(AppColors.accent)
        appearance.setDividerImage(UIImage(), forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default) // Remove dividers

        // Use slightly smaller font for better fit
        let normalFont = AppFonts.uiFont(from: AppFonts.caption) ?? .systemFont(ofSize: 12)
        let selectedFont = AppFonts.uiFont(from: AppFonts.captionBold) ?? .systemFont(ofSize: 12, weight: .bold)

        appearance.setTitleTextAttributes([
            .foregroundColor: UIColor(AppColors.secondaryText),
            .font: normalFont
        ], for: .normal)
        appearance.setTitleTextAttributes([
            .foregroundColor: UIColor.black, // High contrast selected text
            .font: selectedFont
        ], for: .selected)
    }

    // Extracted view for filter controls
    private var filterControls: some View {
        VStack(spacing: 8) { // Reduced spacing slightly
            Picker("Direction", selection: $viewModel.selectedDirectionFilter) {
                ForEach(TransfersViewModel.FilterDirection.allCases) {
                    direction in
                    Text(direction.rawValue).tag(direction)
                }
            }
            .pickerStyle(.segmented)

            Picker("Status", selection: $viewModel.selectedStatusFilter) {
                 ForEach(TransfersViewModel.FilterStatus.allCases) {
                    status in
                    // Use shorter labels to prevent truncation
                    Text(statusDisplayName(status)).tag(status)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.vertical, 12) // Adjusted padding
        .background(AppColors.secondaryBackground) // Consistent background
    }
    
    // Helper to get shorter display names for status
    private func statusDisplayName(_ status: TransfersViewModel.FilterStatus) -> String {
        switch status {
        case .approved: return "Appr."
        case .rejected: return "Rej."
        case .cancelled: return "Canc."
        default: return status.rawValue // Use rawValue for Pending, All
        }
    }

    // Extracted view for the main list content or status messages
    private var listContent: some View {
        ZStack {
            // Background is handled by the parent VStack

            Group {
                switch viewModel.loadingState {
                case .idle:
                    StatusMessageView(message: "Select filters to view transfers.", iconName: "line.3.horizontal.decrease.circle")
                case .loading:
                    ProgressView {
                        Text("Loading transfers...")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                case .success(_):
                    if viewModel.filteredTransfers.isEmpty {
                        StatusMessageView(message: "No transfers found matching filters.", iconName: "doc.text.magnifyingglass")
                    }
                     else {
                        List {
                            ForEach(viewModel.filteredTransfers) { transfer in
                                ZStack {
                                    // NavigationLink hidden behind the content
                                    NavigationLink(destination: TransferDetailView(transfer: transfer, viewModel: viewModel)) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                    
                                    TransferListItemView(transfer: transfer)
                                }
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)) // Consistent padding
                                .listRowBackground(AppColors.secondaryBackground.cornerRadius(8)) // Rounded background for items
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 4) // Spacing between items
                            }
                        }
                        .listStyle(.plain)
                        .background(AppColors.appBackground) // Ensure list background matches app bg
                        .refreshable {
                             viewModel.fetchTransfers()
                         }
                    }
                case .error(let message):
                    ErrorStateView(message: message) {
                        viewModel.fetchTransfers()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Overlay for Action State (Success/Error Messages)
            ActionStatusOverlay(state: viewModel.actionState)
        }
    }
}

// Simple view for status messages (like idle or empty)
struct StatusMessageView: View {
    let message: String
    let iconName: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 30))
                .foregroundColor(AppColors.secondaryText.opacity(0.6))
            Text(message)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - List Item View
struct TransferListItemView: View {
    let transfer: Transfer

    // Use a Formatter for dates
    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none // Keep it short
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) { // Align top for better vertical layout
            // Item/User Info Column
            VStack(alignment: .leading, spacing: 4) {
                Text(transfer.propertyName ?? "Unknown Item")
                    .font(AppFonts.bodyBold) // Themed font
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                Text("SN: \(transfer.propertySerialNumber)")
                    .font(AppFonts.caption) // Themed font
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
                Spacer().frame(height: 4) // Add a bit more space
                Text("\(transfer.fromUser?.rank ?? "?") \(transfer.fromUser?.username ?? "N/A") → \(transfer.toUser?.rank ?? "?") \(transfer.toUser?.username ?? "N/A")")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
                Text("Requested: \(transfer.requestTimestamp, formatter: Self.dateFormatter)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText.opacity(0.7))
            }
            
            Spacer()
            
            // Status Badge Column (aligned top)
            Text(transfer.status.rawValue.capitalized)
                .font(AppFonts.captionBold) // Bolder font for status
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundColor(statusForegroundColor(transfer.status)) // Dynamic themed text color
                .background(statusBackgroundColor(transfer.status)) // Dynamic themed background color
                .clipShape(Capsule())
        }
        // Background handled by list row background
    }

    // Helpers for status badge colors (themed)
    private func statusBackgroundColor(_ status: TransferStatus) -> Color {
        switch status {
            case .PENDING: return Color.orange.opacity(0.2)
            case .APPROVED: return AppColors.accent.opacity(0.2)
            case .REJECTED: return AppColors.destructive.opacity(0.2)
            case .CANCELLED: return AppColors.secondaryText.opacity(0.2)
            case .UNKNOWN: return AppColors.secondaryText.opacity(0.1)
        }
    }
    
    private func statusForegroundColor(_ status: TransferStatus) -> Color {
        switch status {
            case .PENDING: return Color.orange
            case .APPROVED: return AppColors.accent
            case .REJECTED: return AppColors.destructive
            case .CANCELLED: return AppColors.secondaryText
            case .UNKNOWN: return AppColors.secondaryText.opacity(0.7)
        }
    }
}

// MARK: - Detail View
struct TransferDetailView: View {
    let transfer: Transfer
    @ObservedObject var viewModel: TransfersViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView { // Ensure content scrolls
            VStack(alignment: .leading, spacing: 20) { // Increased spacing
                // Property Info Section
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: "Item Details")
                    detailRow(label: "Name", value: transfer.propertyName ?? "N/A")
                    detailRow(label: "Serial #", value: transfer.propertySerialNumber)
                }
                .padding()
                .background(AppColors.secondaryBackground)
                .cornerRadius(10)

                // Transfer Info Section
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: "Transfer Info")
                    detailRow(label: "Status", value: transfer.status.rawValue.capitalized)
                    detailRow(label: "From", value: "\(transfer.fromUser?.rank ?? "?") \(transfer.fromUser?.username ?? "N/A")")
                    detailRow(label: "To", value: "\(transfer.toUser?.rank ?? "?") \(transfer.toUser?.username ?? "N/A")")
                    detailRow(label: "Requested", value: transfer.requestTimestamp.formatted(date: .numeric, time: .shortened))
                    if let approvalDate = transfer.approvalTimestamp {
                        detailRow(label: "Resolved", value: approvalDate.formatted(date: .numeric, time: .shortened))
                    }
                     if let notes = transfer.notes, !notes.isEmpty {
                         detailRow(label: "Notes", value: notes)
                     }
                }
                .padding()
                .background(AppColors.secondaryBackground)
                .cornerRadius(10)

                Spacer() // Push buttons to bottom if content is short

                // Action Buttons (only if applicable)
                if transfer.status == .PENDING && transfer.toUserId == viewModel.currentUserId {
                    actionButtons
                        .padding(.top) // Add padding above buttons
                }
            }
            .padding() // Padding for the overall ScrollView content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.appBackground.ignoresSafeArea()) // Consistent background
        .navigationTitle("Transfer #\(transfer.id)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) { // Keep overlay at bottom
            ActionStatusOverlay(state: viewModel.actionState)
                .padding(.bottom, 20)
        }
    }
    
    // Helper for Section Headers
    @ViewBuilder
    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(AppFonts.headline) // Themed font
            .foregroundColor(AppColors.secondaryText)
            .padding(.bottom, 4)
    }

    // Helper for detail rows
    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) { // Align top for multi-line values
            Text(label + ":")
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 90, alignment: .leading) // Adjusted width
            Text(value)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading) // Allow text to wrap
        }
    }

    // Action Buttons View
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 15) {
            if viewModel.actionState == .loading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                    .padding(.vertical, 10) // Add padding when loading
            } else {
                HStack(spacing: 15) {
                    Button("Reject") {
                        viewModel.rejectTransfer(transferId: transfer.id)
                    }
                    .buttonStyle(.primary) // Use consistent button style
                    .tint(AppColors.destructive) // Destructive tint
                    .disabled(viewModel.actionState == .loading)
                    .frame(maxWidth: .infinity)

                    Button("Approve") {
                        viewModel.approveTransfer(transferId: transfer.id)
                    }
                    .buttonStyle(.primary) // Use consistent button style
                    // .tint(AppColors.accent) // Primary style defaults to accent
                    .disabled(viewModel.actionState == .loading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal) // Add horizontal padding to buttons container
    }
}

// MARK: - Action Status Overlay
struct ActionStatusOverlay: View {
    let state: TransfersViewModel.ActionState

    var body: some View {
        // Use ZStack to manage presence transition
        ZStack {
            if state != .idle && state != .loading {
                HStack(spacing: 10) {
                    Image(systemName: state.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(state.iconColor)
                    Text(state.message)
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(2)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 15)
                .background(Material.ultraThinMaterial) // Use material for overlay effect
                .environment(\.colorScheme, .dark) // Ensure material is dark
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 5)
                .transition(.opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: state) // Smoother animation
    }
}

// Helper extension for ActionState properties
extension TransfersViewModel.ActionState {
    var message: String {
        switch self {
            case .idle, .loading: return ""
            case .success(let msg): return msg
            case .error(let msg): return msg
        }
    }
    
    var iconName: String {
        switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            default: return ""
        }
    }
    
    var iconColor: Color {
        switch self {
            case .success: return AppColors.accent // Themed success color
            case .error: return AppColors.destructive
            default: return .clear
        }
    }
}

// Preview
struct TransfersView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { // Wrap in NavigationView for preview context
            TransfersView()
        }
        .preferredColorScheme(.dark) // Preview in dark mode
        .environmentObject(AuthViewModel()) // Provide AuthViewModel for preview if needed
    }
} 