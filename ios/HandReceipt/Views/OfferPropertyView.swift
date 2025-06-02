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
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Property Section
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "PROPERTY DETAILS")
                            
                            WebAlignedCard {
                                VStack(spacing: 0) {
                                    PropertyInfoRow(label: "NAME", value: property.name)
                                    Divider().background(AppColors.border)
                                    PropertyInfoRow(label: "SERIAL", value: property.serialNumber)
                                    if let nsn = property.nsn {
                                        Divider().background(AppColors.border)
                                        PropertyInfoRow(label: "NSN", value: nsn)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Recipients Section
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                SectionHeader(title: "SELECT RECIPIENTS")
                                Spacer()
                                if !selectedFriends.isEmpty {
                                    Text("\(selectedFriends.count) SELECTED")
                                        .font(AppFonts.captionBold)
                                        .foregroundColor(AppColors.accent)
                                        .compatibleKerning(AppFonts.militaryTracking)
                                        .padding(.trailing)
                                }
                            }
                            
                            if connections.isEmpty && !isLoading {
                                EmptyConnectionsMessage()
                                    .padding()
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(connections) { connection in
                                        OfferConnectionRow(
                                            connection: connection,
                                            isSelected: selectedFriends.contains(String(connection.connectedUserId)),
                                            onTap: { toggleSelection(for: connection) }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Offer Details Section
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "OFFER DETAILS")
                            
                            VStack(spacing: 16) {
                                // Notes Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("NOTES (OPTIONAL)")
                                        .font(AppFonts.captionBold)
                                        .foregroundColor(AppColors.tertiaryText)
                                        .compatibleKerning(AppFonts.militaryTracking)
                                    
                                    ZStack(alignment: .topLeading) {
                                        TextEditor(text: $notes)
                                            .frame(minHeight: 80, maxHeight: 120)
                                            .font(AppFonts.body)
                                            .padding(12)
                                            .background(AppColors.secondaryBackground)
                                            .overlay(
                                                Rectangle()
                                                    .stroke(AppColors.border, lineWidth: 1)
                                            )
                                        
                                        if notes.isEmpty {
                                            Text("Add a message to the recipients...")
                                                .font(AppFonts.body)
                                                .foregroundColor(AppColors.tertiaryText)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 16)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                }
                                
                                // Expiration Stepper
                                WebAlignedCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("OFFER EXPIRES IN")
                                                .font(AppFonts.captionBold)
                                                .foregroundColor(AppColors.tertiaryText)
                                                .compatibleKerning(AppFonts.militaryTracking)
                                            
                                            Text("\(expiresInDays) DAYS")
                                                .font(AppFonts.headline)
                                                .foregroundColor(AppColors.primaryText)
                                        }
                                        
                                        Spacer()
                                        
                                        Stepper("", value: $expiresInDays, in: 1...30)
                                            .labelsHidden()
                                    }
                                    .padding()
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Action Button
                        Button(action: createOffer) {
                            HStack(spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                                Text(isLoading ? "SENDING OFFERS..." : "SEND OFFERS")
                                    .compatibleKerning(AppFonts.militaryTracking)
                            }
                            .font(AppFonts.bodyBold)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primary)
                        .disabled(selectedFriends.isEmpty || isLoading)
                        .padding(.horizontal)
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationTitle("Offer Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.accent)
                }
            }
            .disabled(isLoading)
        }
        .task {
            await loadConnections()
        }
    }
    
    private func toggleSelection(for connection: UserConnection) {
        let id = String(connection.connectedUserId)
        if selectedFriends.contains(id) {
            selectedFriends.remove(id)
        } else {
            selectedFriends.insert(id)
        }
    }
    
    private func loadConnections() async {
        isLoading = true
        do {
            connections = try await apiService.getConnections()
        } catch {
            print("Failed to load connections: \(error)")
        }
        isLoading = false
    }
    
    private func createOffer() {
        isLoading = true
        
        Task {
            do {
                // Create individual transfer requests for each selected recipient
                for recipientIdString in selectedFriends {
                    guard let recipientId = Int(recipientIdString) else { continue }
                    
                    let expiresAt = Calendar.current.date(byAdding: .day, value: expiresInDays, to: Date())
                    
                    _ = try await TransferService.shared.createOffer(
                        propertyId: property.id,
                        offeredToUserId: recipientId,
                        notes: notes.isEmpty ? nil : notes,
                        expiresAt: expiresAt
                    )
                }
                
                dismiss()
            } catch {
                print("Failed to create offer: \(error)")
            }
            
            isLoading = false
        }
    }
}

// MARK: - Property Info Row
struct PropertyInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .font(AppFonts.captionBold)
                .foregroundColor(AppColors.tertiaryText)
                .compatibleKerning(AppFonts.militaryTracking)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
    }
}

// MARK: - Empty Connections Message
struct EmptyConnectionsMessage: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(AppColors.tertiaryText)
            
            Text("NO CONNECTIONS")
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.secondaryText)
                .compatibleKerning(AppFonts.militaryTracking)
            
            Text("Add connections to offer property transfers")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Offer Connection Row
struct OfferConnectionRow: View {
    let connection: UserConnection
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.accent.opacity(0.2) : AppColors.tertiaryBackground)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
                        )
                    
                    Text((connection.connectedUser?.lastName ?? connection.connectedUser?.username ?? "?").prefix(1))
                        .font(AppFonts.bodyBold)
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.secondaryText)
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    if let user = connection.connectedUser {
                        Text("\(user.rank ?? "") \(user.lastName ?? user.username)")
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("@\(user.username)")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                Spacer()
                
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.tertiaryText)
            }
            .padding()
            .background(isSelected ? AppColors.accent.opacity(0.05) : AppColors.secondaryBackground)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 