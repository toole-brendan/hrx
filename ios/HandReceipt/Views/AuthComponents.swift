import SwiftUI

// MARK: - Underlined Text Field Components

struct UnderlinedTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var textContentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .sentences
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(isFocused ? AppColors.primaryText : AppColors.tertiaryText)
                .kerning(AppFonts.wideKerning)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            TextField(placeholder, text: $text)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .tint(AppColors.accent)
                .textFieldStyle(PlainTextFieldStyle())
                .textContentType(textContentType)
                .keyboardType(keyboardType)
                .autocapitalization(autocapitalization)
                .disableAutocorrection(true)
                .focused($isFocused)
                .padding(.vertical, 8)
            
            Rectangle()
                .fill(isFocused ? AppColors.primaryText : AppColors.border)
                .frame(height: isFocused ? 2 : 1)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

struct UnderlinedSecureField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var textContentType: UITextContentType? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(isFocused ? AppColors.primaryText : AppColors.tertiaryText)
                .kerning(AppFonts.wideKerning)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            SecureField(placeholder, text: $text)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .tint(AppColors.accent)
                .textFieldStyle(PlainTextFieldStyle())
                .textContentType(textContentType)
                .focused($isFocused)
                .padding(.vertical, 8)
            
            Rectangle()
                .fill(isFocused ? AppColors.primaryText : AppColors.border)
                .frame(height: isFocused ? 2 : 1)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// MARK: - Loading Button Component

struct MinimalLoadingButton: View {
    let isLoading: Bool
    let title: String
    let icon: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    // Minimal three dots loading animation
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                                .scaleEffect(isLoading ? 1 : 0.3)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: isLoading
                                )
                        }
                    }
                } else {
                    Text(title)
                        .font(AppFonts.bodyMedium)
                    
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .regular))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        }
        .buttonStyle(MinimalPrimaryButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - Section Header Component
// Note: SectionHeader is defined in AppStyles.swift

// MARK: - Minimal Dropdown Component

struct MinimalDropdown: View {
    let label: String
    @Binding var selection: String
    let placeholder: String
    let options: [String]
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
                .kerning(AppFonts.wideKerning)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection = option
                    }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? placeholder : selection)
                        .font(AppFonts.body)
                        .foregroundColor(selection.isEmpty ? AppColors.tertiaryText : AppColors.primaryText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(AppColors.tertiaryText)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
        }
    }
}

// MARK: - Password Requirement Component

struct PasswordRequirement: View {
    let met: Bool
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(met ? AppColors.success : AppColors.border)
            
            Text(text)
                .font(AppFonts.caption)
                .foregroundColor(met ? AppColors.secondaryText : AppColors.tertiaryText)
        }
        .animation(.easeInOut(duration: 0.2), value: met)
    }
}

// MARK: - Minimal Back Button Component
// Note: MinimalBackButton is defined in AppStyles.swift

// MARK: - Geometric Pattern Background

struct GeometricPatternBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Create subtle geometric pattern inspired by 8VC
                let spacing: CGFloat = 120
                let lineWidth: CGFloat = 0.5
                
                // Draw grid of subtle lines
                for x in stride(from: 0, to: size.width, by: spacing) {
                    for y in stride(from: 0, to: size.height, by: spacing) {
                        // Draw subtle square
                        let rect = CGRect(x: x, y: y, width: spacing * 0.6, height: spacing * 0.6)
                        context.stroke(
                            Path(rect),
                            with: .color(AppColors.border.opacity(0.5)),
                            lineWidth: lineWidth
                        )
                        
                        // Add inner square for depth
                        let innerRect = CGRect(x: x + 20, y: y + 20, width: spacing * 0.3, height: spacing * 0.3)
                        context.stroke(
                            Path(innerRect),
                            with: .color(AppColors.border.opacity(0.3)),
                            lineWidth: lineWidth
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Text Link Button Style
// Note: TextLinkButtonStyle is defined in AppStyles.swift 