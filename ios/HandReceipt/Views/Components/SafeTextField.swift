import SwiftUI
import UIKit

// Custom text field that prevents emoji keyboard and RTI errors
struct SafeTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var disableAutocorrection: Bool = false
    var contentType: UITextContentType? = nil
    
    func makeUIView(context: Context) -> UITextField {
        let textField = EmojiDisabledTextField()
        textField.placeholder = placeholder
        textField.text = text
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = autocapitalization
        textField.autocorrectionType = disableAutocorrection ? .no : .default
        textField.textContentType = contentType
        textField.delegate = context.coordinator
        
        // Additional configurations to prevent RTI errors
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: SafeTextField
        
        init(_ parent: SafeTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

// Custom UITextField that disables emoji keyboard
class EmojiDisabledTextField: UITextField {
    override var textInputMode: UITextInputMode? {
        // Return the first non-emoji keyboard
        for mode in UITextInputMode.activeInputModes {
            if mode.primaryLanguage != nil && mode.primaryLanguage != "emoji" {
                return mode
            }
        }
        return super.textInputMode
    }
    
    override var textInputContextIdentifier: String? {
        // Provide a stable identifier to prevent RTI errors
        return "com.handreceipt.textfield"
    }
} 