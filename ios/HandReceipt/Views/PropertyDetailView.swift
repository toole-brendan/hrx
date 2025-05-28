import SwiftUI

struct PropertyDetailView: View {
    @StateObject private var viewModel: PropertyDetailViewModel
    
    @Environment(\.dismiss) var dismiss

    // Shared Date Formatter (Consider moving to a Utils file)
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    // Initialize the view with a propertyId that will be used to fetch details
    init(propertyId: Int, apiService: APIServiceProtocol = APIService()) {
        // Create the ViewModel with the provided ID
        let vm = PropertyDetailViewModel(propertyId: propertyId, apiService: apiService)
        self._viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        ZStack {
            content
        }
        .navigationTitle("Property Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { // Add actions to toolbar
            ToolbarItem(placement: .navigationBarTrailing) {
                // Only show button if property is loaded and not currently trying to transfer
                if viewModel.property != nil && viewModel.transferRequestState != .loading {
                    Button("Request Transfer") {
                        viewModel.requestTransferClicked()
                    }
                }
            }
        }
        // Present User Selection Sheet
        .sheet(isPresented: $viewModel.showingUserSelection) {
            // Pass the callback to the ViewModel's initiateTransfer function
            UserSelectionView(onUserSelected: { selectedUser in
                viewModel.initiateTransfer(targetUser: selectedUser)
            })
        }
        // Use TransferStatusMessage from ScanView instead
        .overlay(TransferStatusMessage(state: viewModel.transferRequestState))
        .onAppear {
            // Load property on view appearance
            viewModel.loadProperty()
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.loadingState {
        case .idle, .loading:
            ProgressView("Loading property details...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .success(let property):
            detailsContent(property: property)
            
        case .error(let message):
            ErrorStateView(message: message) {
                viewModel.loadProperty() // Retry loading
            }
        }
    }
    
    private func detailsContent(property: Property) -> some View {
        ScrollView { // Make content scrollable if it gets long
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Item Name", value: property.itemName)
                DetailRow(label: "NSN", value: property.nsn)
                DetailRow(label: "Serial Number", value: property.serialNumber)
                Divider()
                DetailRow(label: "Status", value: property.status)
                DetailRow(label: "Location", value: property.location ?? "N/A")
                DetailRow(label: "Assigned To ID", value: property.assignedToUserId != nil ? "\(property.assignedToUserId!)" : "None")
                
                if let lastInvDate = property.lastInventoryDate {
                    DetailRow(label: "Last Inventory", value: lastInvDate, formatter: DateFormatter.Style.short)
                }
                
                if let acquisitionDate = property.acquisitionDate {
                    DetailRow(label: "Acquisition Date", value: acquisitionDate, formatter: DateFormatter.Style.short)
                }
                
                if let notes = property.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes:").bold()
                        Text(notes)
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Spacer(minLength: 30)
            }
            .padding()
        }
    }
}

// Helper view for consistent detail rows
struct DetailRow: View {
    let label: String
    let value: String

    // Explicit initializer for String values
    init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label + ":")
                .bold()
                .frame(width: 120, alignment: .leading)
            Text(value)
            Spacer() // Pushes content to the left
        }
    }
    
    // Overload for date values
    init(label: String, value: Date, formatter: DateFormatter) {
        self.label = label
        self.value = formatter.string(from: value)
    }
    
    // Convenience initializer for common date formats
    init(label: String, value: Date, formatter style: DateFormatter.Style) {
        let formatter = DateFormatter()
        formatter.dateStyle = style // Correctly assign the style
        self.init(label: label, value: value, formatter: formatter)
    }
}

// Ensure ActionStatusOverlay is accessible or defined here
// If it's in TransfersView.swift, it might need to be moved to its own file
// or defined again here (less ideal).

// Assuming ActionStatusOverlay is accessible:

// MARK: - Preview
struct PropertyDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview needs adjustment to work with new VM states and potentially MockAPIService
        NavigationView { // Wrap in NavigationView for Title
            // Use Int ID for preview
            PropertyDetailView(propertyId: Property.mockList[0].id,
                               apiService: MockAPIService())
            .previewDisplayName("Property Details")
        }
    }
}
