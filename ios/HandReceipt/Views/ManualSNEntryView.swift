import SwiftUI

// REMOVE Placeholder APIService, APIError, and old ViewModel
// class APIService { ... } // REMOVED
// enum APIError: Error, LocalizedError { ... } // REMOVED
// @MainActor class ManualSNViewModel: ObservableObject { ... } // REMOVED

struct ManualSNEntryView: View {
    // Use the new ViewModel from the dedicated file
    @StateObject private var viewModel = ManualSNViewModel()

    // Callback for when an item is confirmed (pass the found Property)
    // This might be used to initiate a transfer, start maintenance, etc.
    var onItemConfirmed: ((Property) -> Void)?

    // State for showing confirmation alert
    @State private var showingConfirmationAlert = false
    @State private var itemToConfirm: Property? = nil

    @State private var nsn: String = ""
    @State private var lin: String = ""
    @State private var description: String = ""
    
    @State private var showingNSNSearch = false
    @State private var nsnSearchQuery = ""
    @State private var nsnSearchResults: [NSNDetails] = []
    @State private var isSearchingNSN = false

    var body: some View {
        NavigationView { // Added for Title and potentially other navigation
            VStack(spacing: 16) {

                // --- Input Field --- 
                HStack {
                     TextField(
                        "Enter Serial Number",
                        text: $viewModel.serialNumberInput
                     )
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters) // Changed to .characters for SNs
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .disabled(viewModel.lookupState == PropertyLookupState.loading) // Use specific enum case
                     // Trigger search on submit (hitting return key)
                    .onSubmit { 
                        viewModel.findProperty() 
                    }

                     // Clear button
                     if !viewModel.serialNumberInput.isEmpty {
                        Button {
                            viewModel.clearAndReset()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, -30) // Adjust to overlay nicely
                    }
                }
                .padding(.horizontal)

                // NSN/LIN Fields with lookup
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NSN (Optional)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            HStack {
                                TextField("13-digit NSN", text: $nsn)
                                    .textFieldStyle(IndustrialTextFieldStyle())
                                    .autocapitalization(.none)
                                    .onChange(of: nsn) { newValue in
                                        // Format NSN as user types (####-##-###-####)
                                        if newValue.count == 13 && !newValue.contains("-") {
                                            let formatted = formatNSN(newValue)
                                            nsn = formatted
                                        }
                                    }
                                
                                Button(action: lookupNSN) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(AppColors.primary)
                                }
                                .disabled(nsn.replacingOccurrences(of: "-", with: "").count != 13)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LIN (Optional)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            HStack {
                                TextField("6-character LIN", text: $lin)
                                    .textFieldStyle(IndustrialTextFieldStyle())
                                    .autocapitalization(.allCharacters)
                                    .onChange(of: lin) { newValue in
                                        lin = String(newValue.prefix(6)).uppercased()
                                    }
                                
                                Button(action: lookupLIN) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(AppColors.primary)
                                }
                                .disabled(lin.count != 6)
                            }
                        }
                    }
                    
                    Button(action: { showingNSNSearch = true }) {
                        HStack {
                            Image(systemName: "text.magnifyingglass")
                            Text("Search NSN Database")
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.primary)
                    }
                }
                .padding(.bottom)

                // --- Status/Result Area --- 
                VStack {
                    switch viewModel.lookupState {
                    case .idle:
                        // Optionally show a prompt or leave empty
                         Text("Enter a serial number above to look up an item.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top)

                    case .loading:
                        ProgressView("Looking up...")
                            .padding()

                    case .success(let property):
                        PropertyFoundView(
                            property: property,
                            onConfirm: {
                                // Trigger confirmation flow if callback exists
                                if onItemConfirmed != nil {
                                    itemToConfirm = property
                                    showingConfirmationAlert = true
                                } else {
                                    // Handle case where no confirmation action is provided
                                     print("Item found, but no confirmation action provided.")
                                }
                            },
                            // Only show confirm button if handler is provided
                            showConfirmButton: onItemConfirmed != nil 
                        )
                        .padding(.horizontal)

                    case .notFound:
                        Text("Serial number \"\(viewModel.serialNumberInput)\" not found.")
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding()

                    case .error(let message):
                        Text(message)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                            // Add a retry button for errors?
                            Button("Retry") {
                                viewModel.findProperty()
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 5)

                    }
                }
                .frame(maxWidth: .infinity, minHeight: 150) // Give result area some space
                .background(Color(uiColor: .secondarySystemBackground)) // Subtle background
                .cornerRadius(10)
                .padding(.horizontal)

                Spacer() // Pushes content up
            }
            .padding(.top) // Add padding at the top of the VStack
             // Alert for confirming the action
            .alert("Confirm Action", isPresented: $showingConfirmationAlert, presenting: itemToConfirm) { property in
                 // Provide context in the alert message if needed
                Button("Confirm") {
                    onItemConfirmed?(property)
                }
                Button("Cancel", role: .cancel) {}
            } message: { property in
                // Customize alert message based on the intended action
                Text("Do you want to proceed with the action for \"\(property.itemName)\" (SN: \(property.serialNumber))?")
            }
            .navigationTitle("Manual Serial Number Entry")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
             // Optionally clear state when view appears if needed
            // viewModel.clearAndReset()
        }

        .sheet(isPresented: $showingNSNSearch) {
            NSNSearchView(
                searchQuery: $nsnSearchQuery,
                searchResults: $nsnSearchResults,
                isSearching: $isSearchingNSN,
                onSelect: { selectedNSN in
                    applyNSNDetails(selectedNSN)
                    showingNSNSearch = false
                }
            )
        }
    }

    // MARK: - NSN/LIN Lookup Functions
    
    private func lookupNSN() {
        let cleanNSN = nsn.replacingOccurrences(of: "-", with: "")
        guard cleanNSN.count == 13 else { return }
        
        Task {
            do {
                let response = try await apiService.lookupNSN(nsn: cleanNSN)
                await MainActor.run {
                    applyNSNDetails(response.data)
                }
            } catch {
                print("NSN lookup failed: \(error)")
                // Show error alert
            }
        }
    }
    
    private func lookupLIN() {
        guard lin.count == 6 else { return }
        
        Task {
            do {
                let response = try await apiService.lookupLIN(lin: lin)
                await MainActor.run {
                    applyNSNDetails(response.data)
                }
            } catch {
                print("LIN lookup failed: \(error)")
                // Show error alert
            }
        }
    }
    
    private func applyNSNDetails(_ details: NSNDetails) {
        if !itemName.isEmpty && itemName != details.itemName {
            // Ask user if they want to overwrite
            // For now, just append
            itemName = "\(itemName) - \(details.itemName)"
        } else {
            itemName = details.itemName
        }
        
        if let detailsNSN = details.nsn {
            nsn = formatNSN(detailsNSN)
        }
        
        if let detailsLIN = details.lin {
            lin = detailsLIN
        }
        
        if description.isEmpty {
            var desc = ""
            if let manufacturer = details.manufacturer {
                desc += "Manufacturer: \(manufacturer)\n"
            }
            if let partNumber = details.partNumber {
                desc += "Part Number: \(partNumber)\n"
            }
            if let price = details.unitPrice {
                desc += "Unit Price: $\(String(format: "%.2f", price))\n"
            }
            description = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private func formatNSN(_ nsn: String) -> String {
        let clean = nsn.replacingOccurrences(of: "-", with: "")
        guard clean.count == 13 else { return nsn }
        
        let part1 = clean.prefix(4)
        let part2 = clean.dropFirst(4).prefix(2)
        let part3 = clean.dropFirst(6).prefix(3)
        let part4 = clean.dropFirst(9)
        
        return "\(part1)-\(part2)-\(part3)-\(part4)"
    }
}

// --- Subview for displaying found property --- 
struct PropertyFoundView: View {
    let property: Property
    let onConfirm: () -> Void
    let showConfirmButton: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Item Found:").font(.headline)
            Divider()
            HStack { // Use HStack for better layout of labels and values
                Text("Name:").bold().frame(width: 100, alignment: .leading)
                Text(property.itemName)
            }
            HStack {
                Text("Serial #:").bold().frame(width: 100, alignment: .leading)
                Text(property.serialNumber)
            }
            HStack {
                Text("NSN:").bold().frame(width: 100, alignment: .leading)
                Text(property.nsn)
            }
             HStack {
                Text("Status:").bold().frame(width: 100, alignment: .leading)
                Text(property.status)
            }
            HStack(alignment: .top) {
                Text("Location:").bold().frame(width: 100, alignment: .leading)
                Text(property.location ?? "N/A")
            }
            if let notes = property.notes, !notes.isEmpty {
                 HStack(alignment: .top) {
                    Text("Notes:").bold().frame(width: 100, alignment: .leading)
                    Text(notes)
                 }
            }
            // TODO: Fetch and display assigned user name if ID exists
             HStack {
                Text("Assigned:").bold().frame(width: 100, alignment: .leading)
                 Text(property.assignedToUserId != nil ? "User ID: \(property.assignedToUserId!)" : "Unassigned").foregroundColor(.gray)
            }

             // Display dates if available (requires DateFormatter)
            if let lastInvDate = property.lastInventoryDate {
                 HStack {
                    Text("Last Inv:").bold().frame(width: 100, alignment: .leading)
                     Text(lastInvDate, style: .date).foregroundColor(.gray)
                }
            }

            // Confirmation Button
            if showConfirmButton {
                Spacer(minLength: 10)
                Button { 
                    onConfirm() 
                } label: {
                     Label("Confirm & Proceed", systemImage: "checkmark.circle.fill") // Add icon
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 5)
            }
        }
        .padding()
        // .background(Color.green.opacity(0.1)) // Removed background color here
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// --- Preview --- 
struct ManualSNEntryView_Previews: PreviewProvider {
    static var previews: some View {

        // --- Preview 1: Idle State --- 
        ManualSNEntryView {
            print("Preview Confirmed Item: \($0.serialNumber)")
        }
        .previewDisplayName("Idle State")

        // --- Preview 2: Loading State --- 
        ManualSNEntryView {
            print("Preview Confirmed Item: \($0.serialNumber)")
        }
        .onAppear { // Simulate loading state for preview
            let viewModel = ManualSNViewModel()
            viewModel.lookupState = .loading
            // Need a way to inject this VM or have the preview modify the @StateObject
            // For simplicity, this preview might not show loading correctly
            // without more complex preview setup (e.g., mock service).
        }
        .previewDisplayName("Loading State")

        // --- Preview 3: Item Found State --- 
        ManualSNEntryView {
            print("Preview Confirmed Item: \($0.serialNumber)")
        }
        .onAppear { // Simulate found state for preview
             let viewModel = ManualSNViewModel() // Temporary instance for preview data
             viewModel.lookupState = .success(Property.example) 
             // This doesn't directly affect the @StateObject in the view.
             // Showing state requires passing a pre-configured VM or mock service.
        }
         // Providing a direct view with state might be easier for previews:
         .overlay( // Overlay approach for state preview (simpler than VM injection)
            VStack {
                 Spacer()
                 PropertyFoundView(
                    property: Property.example, 
                    onConfirm: { print("Preview Confirm Clicked") }, 
                    showConfirmButton: true
                 )
                 .padding()
                 .background(Color(uiColor: .secondarySystemBackground))
                 .cornerRadius(10)
                 .padding()
             }.offset(y: -50) // Adjust offset as needed
         )
        .previewDisplayName("Item Found")

         // --- Preview 4: Not Found State --- 
         ManualSNEntryView {
             print("Preview Confirmed Item: \($0.serialNumber)")
         }
         .onAppear {
             let viewModel = ManualSNViewModel()
             viewModel.serialNumberInput = "NOTFOUNDSN"
             viewModel.lookupState = .notFound
             // Again, direct modification of @StateObject is tricky in previews
         }
         .overlay(
            Text("Serial number \"NOTFOUNDSN\" not found.").foregroundColor(.orange).padding().offset(y: 50)
         )
         .previewDisplayName("Not Found")

        // --- Preview 5: Error State --- 
        ManualSNEntryView {
            print("Preview Confirmed Item: \($0.serialNumber)")
        }
         .overlay(
            Text("Network problem. Check connection.").foregroundColor(.red).padding().offset(y: 50)
         )
        .previewDisplayName("Error State")
    }
} 