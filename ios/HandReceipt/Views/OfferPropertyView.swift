import SwiftUI

struct OfferPropertyView: View {
    let property: Property
    @State private var selectedFriends: Set<String> = []
    @State private var notes = ""
    @State private var expiresInDays = 7
    @State private var isLoading = false
    @State private var connections: [UserConnection] = []
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Property")) {
                    HStack {
                        Text("Item:")
                        Spacer()
                        Text(property.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Serial:")
                        Spacer()
                        Text(property.serialNumber)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Select Recipients")) {
                    if connections.isEmpty {
                        Text("No connections found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(connections) { connection in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(connection.connectedUser?.name ?? "Unknown")
                                        .font(.headline)
                                    Text("\(connection.connectedUser?.rank ?? "") - \(connection.connectedUser?.unit ?? "")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedFriends.contains(String(connection.connectedUserID)) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(for: connection)
                            }
                        }
                    }
                }
                
                Section(header: Text("Offer Details")) {
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Stepper("Expires in \(expiresInDays) days", value: $expiresInDays, in: 1...30)
                }
            }
            .navigationTitle("Offer Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send Offer") { createOffer() }
                        .disabled(selectedFriends.isEmpty || isLoading)
                }
            }
            .disabled(isLoading)
        }
        .task {
            await loadConnections()
        }
    }
    
    private func toggleSelection(for connection: UserConnection) {
        let id = String(connection.connectedUserID)
        if selectedFriends.contains(id) {
            selectedFriends.remove(id)
        } else {
            selectedFriends.insert(id)
        }
    }
    
    private func loadConnections() async {
        do {
            connections = try await UserService.shared.getConnections()
        } catch {
            print("Failed to load connections: \(error)")
        }
    }
    
    private func createOffer() {
        isLoading = true
        
        Task {
            do {
                let recipientIDs = selectedFriends.compactMap { UInt($0) }
                let request = CreateOfferInput(
                    propertyId: property.id,
                    recipientIds: recipientIDs,
                    notes: notes.isEmpty ? nil : notes,
                    expiresInDays: expiresInDays
                )
                
                try await TransferService.shared.createOffer(request)
                dismiss()
            } catch {
                print("Failed to create offer: \(error)")
            }
            
            isLoading = false
        }
    }
} 