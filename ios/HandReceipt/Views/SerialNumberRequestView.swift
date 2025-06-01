import SwiftUI

struct SerialNumberRequestView: View {
    @State private var serialNumber = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) var dismiss
    // AuthService no longer needed - authentication handled by AuthManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Property Information")) {
                    TextField("Serial Number", text: $serialNumber)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                    
                    TextField("Notes (Optional)", text: $notes)
                }
                
                Section {
                    Text("Enter the serial number of the property you want to request.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Request by Serial")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Request") { requestTransfer() }
                    .disabled(serialNumber.isEmpty || isLoading)
            )
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
    
    private func requestTransfer() {
        isLoading = true
        
        Task {
            do {
                let trimmedSerial = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                let requestNotes: String? = notes.isEmpty ? nil : notes
                
                _ = try await TransferService.shared.requestBySerial(
                    serialNumber: trimmedSerial,
                    notes: requestNotes
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isLoading = false
        }
    }
} 