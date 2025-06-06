import SwiftUI

struct ReferencePropertyDetailView: View {
    // Use @StateObject to create and manage the ViewModel instance
    // The ViewModel will be kept alive for the lifecycle of this view
    @StateObject private var viewModel: ReferencePropertyDetailViewModel

    // Initializer receives the itemId and creates the ViewModel
    init(itemId: String) {
        // Initialize the StateObject with the ViewModel, passing the itemId
        _viewModel = StateObject(wrappedValue: ReferencePropertyDetailViewModel(itemId: itemId))
         print("ReferencePropertyDetailView initialized for item ID: \(itemId)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch viewModel.loadingState {
            case .idle, .loading:
                ProgressView("Loading item details...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .success(let item):
                ItemDetailContent(item: item)
            case .error(let message):
                 ErrorStateView(message: message) {
                     // Provide a retry action
                    viewModel.fetchDetails()
                 }
            }
        }
        .padding()
        // Use the item name from the ViewModel for the navigation title if available
        .navigationTitle(viewModel.item?.name ?? "Item Detail")
        .navigationBarTitleDisplayMode(.inline) // Keep title concise
        // Optional: Add a refresh button if pull-to-refresh isn't suitable
        // .toolbar {
        //     ToolbarItem(placement: .navigationBarTrailing) {
        //         Button {
        //             viewModel.fetchDetails()
        //         } label: {
        //             Image(systemName: "arrow.clockwise")
        //         }
        //         .disabled(viewModel.loadingState == .loading)
        //     }
        // }
    }
}

// Subview for displaying the actual item content
struct ItemDetailContent: View {
    let item: ReferenceProperty

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Image (Placeholder for now, replace with actual image loading)
                Image(systemName: "photo") // Placeholder image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.bottom, 8)

                Text(item.name).font(.title2).fontWeight(.semibold)
                Text("NSN: \(item.nsn)").font(.subheadline).foregroundColor(.secondary)
                Text("Manufacturer: \(item.manufacturer ?? "N/A")").font(.subheadline).foregroundColor(.secondary)
                Text("Description:").font(.headline).padding(.top, 8)
                Text(item.description ?? "No description available.").font(.body)
                
                // Add more fields as necessary (e.g., Category, Unit of Issue, Unit Price)
                 Divider().padding(.vertical, 8)
                 
                 HStack {
                     Text("Category:").fontWeight(.medium)
                     Spacer()
                     Text(item.category ?? "N/A")
                 }
                 
                 if let unitOfIssue = item.unitOfIssue {
                     HStack {
                         Text("Unit of Issue:").fontWeight(.medium)
                         Spacer()
                         Text(unitOfIssue)
                     }
                 }
                 
                 if let unitPrice = item.unitPrice {
                     HStack {
                         Text("Unit Price:").fontWeight(.medium)
                         Spacer()
                         Text("$\(unitPrice, specifier: "%.2f")")
                     }
                 }
            }
        }
    }
}

// Preview Provider
struct ReferencePropertyDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { // Wrap in NavigationView for preview context
            // Provide a sample UUID string for the preview
             ReferencePropertyDetailView(itemId: UUID().uuidString) 
        }
    }
} 