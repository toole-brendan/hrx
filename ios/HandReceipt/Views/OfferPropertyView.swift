import SwiftUI

struct OfferPropertyView: View {
    let property: Property
    @State private var selectedFriends: Set<String> = []
    @State private var notes = ""
    @State private var expiresInDays = 7
    @State private var isLoading = false
    @State private var connections: [UserConnection] = []
    @Environment(\.dismiss) var dismiss
    
    private let apiService = APIService()
    
    var body: some View {
        NavigationView {
            Form {
                propertySection
                recipientsSection
                offerDetailsSection
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
    
    // Break up the view into smaller components to avoid type-checking timeout
    private var propertySection: some View {
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
    }
    
    private var recipientsSection: some View {
        Section(header: Text("Select Recipients")) {
            if connections.isEmpty {
                Text("No connections found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(connections) { connection in
                    OfferConnectionRow(
                        connection: connection,
                        isSelected: selectedFriends.contains(String(connection.connectedUserId)),
                        onTap: { toggleSelection(for: connection) }
                    )
                }
            }
        }
    }
    
    private var offerDetailsSection: some View {
        Section(header: Text("Offer Details")) {
            // iOS 15 compatible multi-line text field
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $notes)
                    .frame(minHeight: 60, maxHeight: 120)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            
            Stepper("Expires in \(expiresInDays) days", value: $expiresInDays, in: 1...30)
        }
    }
    
    private func toggleSelection(for connection: UserConnection) {
        let id = String(connection.connectedUserId)  // Fixed: use connectedUserId
        if selectedFriends.contains(id) {
            selectedFriends.remove(id)
        } else {
            selectedFriends.insert(id)
        }
    }
    
    private func loadConnections() async {
        do {
            connections = try await apiService.getConnections()  // Fixed: use APIService instance
        } catch {
            print("Failed to load connections: \(error)")
        }
    }
    
    private func createOffer() {
        isLoading = true
        
        Task {
            do {
                // Create individual transfer requests for each selected recipient
                for recipientIdString in selectedFriends {
                    guard let recipientId = Int(recipientIdString) else { continue }
                    
                    let expiresAt = Calendar.current.date(byAdding: .day, value: expiresInDays, to: Date())
                    
                    let request = TransferOfferRequest(  // Fixed: use correct model
                        propertyId: property.id,
                        offeredToUserId: recipientId,
                        notes: notes.isEmpty ? nil : notes,
                        expiresAt: expiresAt
                    )
                    
                    try await TransferService.shared.createOffer(request)
                }
                
                dismiss()
            } catch {
                print("Failed to create offer: \(error)")
            }
            
            isLoading = false
        }
    }
}

// Renamed to avoid conflict with ConnectionsView
struct OfferConnectionRow: View {
    let connection: UserConnection
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(connection.connectedUser?.username ?? "Unknown")
                    .font(.headline)
                if let rank = connection.connectedUser?.rank,
                   let lastName = connection.connectedUser?.lastName {
                    Text("\(rank) \(lastName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let rank = connection.connectedUser?.rank {
                    Text(rank)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
} 