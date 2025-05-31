import SwiftUI

struct SerialNumberRequestView: View {
    @State private var serialNumber = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Property Information")) {
                    TextField("Serial Number", text: $serialNumber)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                    
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Text("Enter the serial number of the property you want to request.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Request by Serial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Request") { requestTransfer() }
                        .disabled(serialNumber.isEmpty || isLoading)
                }
            }
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
                let request = RequestBySerialInput(
                    serialNumber: serialNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notes.isEmpty ? nil : notes
                )
                
                try await TransferService.shared.requestBySerial(request)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isLoading = false
        }
    }
} 