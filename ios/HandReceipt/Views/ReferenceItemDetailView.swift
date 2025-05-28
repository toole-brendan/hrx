import SwiftUI

struct ReferenceItemDetailView: View {
    // Use @StateObject to create and manage the ViewModel instance
    // The ViewModel will be kept alive for the lifecycle of this view
    @StateObject private var viewModel: ReferenceItemDetailViewModel

    // Initializer receives the itemId and creates the ViewModel
    init(itemId: String) {
        // Initialize the StateObject with the ViewModel, passing the itemId
        _viewModel = StateObject(wrappedValue: ReferenceItemDetailViewModel(itemId: itemId))
         print("ReferenceItemDetailView initialized for item ID: \(itemId)")
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
                 ErrorView(message: message) {
                     // Provide a retry action
                    viewModel.fetchDetails()
                 }
            }
        }
        .padding()
        // Use the item name from the ViewModel for the navigation title if available
        .navigationTitle(viewModel.item?.itemName ?? "Item Detail")
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
    let item: ReferenceItem

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

                Text(item.itemName).font(.title2).fontWeight(.semibold)
                Text("NSN: \(item.nsn)").font(.subheadline).foregroundColor(.secondary)
                Text("Manufacturer: \(item.manufacturer ?? "N/A")").font(.subheadline).foregroundColor(.secondary)
                Text("Description:").font(.headline).padding(.top, 8)
                Text(item.description ?? "No description available.").font(.body)
                
                // Add more fields as necessary (e.g., Category, LIN, Part Number)
                 Divider().padding(.vertical, 8)
                 
                 HStack {
                     Text("Category:").fontWeight(.medium)
                     Spacer()
                     Text(item.category ?? "N/A")
                 }
                 HStack {
                     Text("LIN:").fontWeight(.medium)
                     Spacer()
                     Text(item.lin ?? "N/A")
                 }
                 HStack {
                     Text("Part Number:").fontWeight(.medium)
                     Spacer()
                     Text(item.partNumber ?? "N/A")
                 }
            }
        }
    }
}

// Reusable Error View Component
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.red)
            Text("Error Loading Data")
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                retryAction()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// Preview Provider
struct ReferenceItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { // Wrap in NavigationView for preview context
            // Provide a sample UUID string for the preview
             ReferenceItemDetailView(itemId: UUID().uuidString) 
        }
    }
} 