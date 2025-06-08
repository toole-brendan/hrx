import SwiftUI

struct EmailRecipientsSheet: View {
    @Binding var emailRecipients: String
    let onSend: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Email Recipients")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)
                
                Text("Enter recipient email addresses separated by commas")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                SafeTextField(
                    placeholder: "email@example.com, another@example.com",
                    text: $emailRecipients,
                    keyboardType: .emailAddress,
                    autocapitalization: .none,
                    disableAutocorrection: true,
                    contentType: nil  // Explicitly nil to prevent suggestions
                )
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Send", action: onSend)
                    .disabled(emailRecipients.trimmingCharacters(in: .whitespaces).isEmpty)
            )
        }
    }
} 