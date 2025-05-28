import SwiftUI
// import HandReceipt // Removed unnecessary import

struct UserSelectionView: View {
    // Use @StateObject if this view creates the VM, 
    // @ObservedObject if it's passed in
    @StateObject private var viewModel = UserSelectionViewModel()
    
    // Callback to parent view when user is selected
    let onUserSelected: (UserSummary) -> Void
    // Callback to dismiss the view
    @Environment(\.dismiss) var dismiss 

    init(onUserSelected: @escaping (UserSummary) -> Void) {
        self.onUserSelected = onUserSelected
        // Configure list/search appearance if needed globally or here
        // configureListAppearance()
    }

    var body: some View {
        // NavigationView is already styled globally
        VStack(spacing: 0) { // No spacing needed if List fills VStack
            List {
                switch viewModel.userListState {
                case .idle:
                    Text("Enter search query to find users.")
                        .foregroundColor(AppColors.secondaryText) // Use theme color
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                case .loading:
                    HStack { // Center ProgressView
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.secondaryText))
                        Spacer()
                    }
                    .listRowBackground(AppColors.appBackground) // Match background
                case .success(let users):
                    if users.isEmpty {
                        Text("No users found matching '\(viewModel.searchQuery)'.")
                            .foregroundColor(AppColors.secondaryText) // Use theme color
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(users) { user in
                            UserListItemView(user: user)
                                .listRowInsets(EdgeInsets()) // Remove default padding
                                .padding(.horizontal) // Apply standard horizontal padding
                                .padding(.vertical, 8) // Apply custom vertical padding
                                .listRowBackground(AppColors.appBackground) // Set row background
                                .listRowSeparatorTint(AppColors.secondaryBackground) // Set separator color
                                .contentShape(Rectangle()) // Ensure full row is tappable
                                .onTapGesture {
                                    onUserSelected(user)
                                    dismiss()
                                }
                        }
                    }
                case .error(let message):
                    Text("Error: \(message)")
                        .foregroundColor(AppColors.destructive) // Use theme color
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .listStyle(.plain)
            .background(AppColors.appBackground) // List background
            .searchable(text: $viewModel.searchQuery, prompt: Text("Search Users...").foregroundColor(AppColors.secondaryText))
            .onDisappear { 
                 viewModel.clearSearch()
            }
        }
        // Title and Toolbar are inherited from the NavigationView used in ScanView's sheet presentation
        // .navigationTitle("Select User") // Set in ScanView sheet presentation
        // .navigationBarTitleDisplayMode(.inline)
        // .toolbar { ... } // Set in ScanView sheet presentation
    }
}

// Simple view for displaying a user in the list
struct UserListItemView: View {
    let user: UserSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
             let displayName = "\(user.rank ?? "") \(user.lastName ?? "")".trimmingCharacters(in: .whitespaces)
             Text(displayName.isEmpty ? user.username : displayName) // Fallback to username if rank/last name missing
                 .font(.headline)
                 .foregroundColor(AppColors.primaryText) // Theme text color
             Text("@\(user.username)")
                 .font(.subheadline)
                 .foregroundColor(AppColors.secondaryText) // Theme secondary text color
         }
         // Padding is handled by the list row
         .frame(maxWidth: .infinity, alignment: .leading) // Ensure it fills width
         .background(AppColors.appBackground) // Match background
    }
}

// Preview
struct UserSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { // Add NavView for preview context
            UserSelectionView(onUserSelected: { user in
                print("Preview: Selected user \(user.username)")
            })
        }
        .preferredColorScheme(.dark) // Preview in dark mode
    }
} 