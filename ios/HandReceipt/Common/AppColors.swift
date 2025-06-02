// handreceipt/ios/HandReceipt/Common/AppColors.swift

import SwiftUI

// Make the struct public so it can be accessed across the module
public struct AppColors {
    // MARK: - Background Colors (Light, sophisticated palette)
    public static let appBackground = Color(hex: "FAFAFA") ?? Color(.systemBackground)
    public static let secondaryBackground = Color(hex: "FFFFFF") ?? Color.white
    public static let tertiaryBackground = Color(hex: "F5F5F5") ?? Color(.systemGray6)
    public static let elevatedBackground = Color(hex: "FFFFFF") ?? Color.white
    
    // MARK: - Text Colors (High contrast black-based hierarchy)
    public static let primaryText = Color(hex: "000000") ?? Color.black
    public static let secondaryText = Color(hex: "4A4A4A") ?? Color(.label).opacity(0.7)
    public static let tertiaryText = Color(hex: "6B6B6B") ?? Color(.label).opacity(0.5)
    public static let quaternaryText = Color(hex: "9B9B9B") ?? Color(.label).opacity(0.3)
    
    // MARK: - Accent Colors (Minimal, professional)
    public static let accent = Color(hex: "0066CC") ?? Color.blue
    public static let accentHover = Color(hex: "0052A3") ?? Color.blue.opacity(0.8)
    public static let accentMuted = Color(hex: "E6F0FF") ?? Color.blue.opacity(0.1)
    public static let accentDim = Color(hex: "0052A3") ?? Color.blue.opacity(0.8) // Legacy compatibility
    public static let accentHighlight = Color(hex: "0052A3") ?? Color.blue.opacity(0.9) // Legacy compatibility
    
    // MARK: - Status Colors (Subtle, muted)
    public static let destructive = Color(hex: "DC3545") ?? Color.red.opacity(0.9)
    public static let destructiveDim = Color(hex: "B02A37") ?? Color.red.opacity(0.7)
    public static let warning = Color(hex: "FFC107") ?? Color.orange
    public static let warningDim = Color(hex: "E6AC00") ?? Color.orange.opacity(0.8)
    public static let success = Color(hex: "28A745") ?? Color.green.opacity(0.9)
    public static let successDim = Color(hex: "1E7B34") ?? Color.green.opacity(0.7)
    
    // MARK: - Border & Divider Colors (Subtle definition)
    public static let border = Color(hex: "E0E0E0") ?? Color.gray.opacity(0.2)
    public static let borderStrong = Color(hex: "CCCCCC") ?? Color.gray.opacity(0.3)
    public static let borderHighlight = Color(hex: "CCCCCC") ?? Color.gray.opacity(0.3) // Legacy compatibility
    public static let borderAccent = accent.opacity(0.3)
    public static let divider = Color(hex: "F0F0F0") ?? Color.gray.opacity(0.1)
    public static let borderMuted = Color(hex: "F0F0F0") ?? Color.gray.opacity(0.1)
    
    // MARK: - Special Purpose Colors (Refined)
    public static let shadowColor = Color.black.opacity(0.08)
    public static let overlayBackground = Color.black.opacity(0.5)
    
    // MARK: - Legacy/Web-aligned colors (updated for compatibility)
    public static let mutedBackground = tertiaryBackground
    public static let cardBackground = secondaryBackground
    public static let statusGreen = success
    public static let statusAmber = warning
    public static let statusRed = destructive
    public static let statusBlue = accent
    
    // MARK: - Updated category colors (more subtle)
    public static let weaponsCategory = Color(hex: "DC3545") ?? Color.red.opacity(0.8)
    public static let communicationsCategory = Color(hex: "0066CC") ?? Color.blue.opacity(0.8)
    public static let opticsCategory = Color(hex: "28A745") ?? Color.green.opacity(0.8)
    public static let vehiclesCategory = Color(hex: "FFC107") ?? Color.orange.opacity(0.8)
    public static let electronicsCategory = Color(hex: "6F42C1") ?? Color.purple.opacity(0.8)
    
    // MARK: - Compatibility mappings (legacy names)
    public static let military = Color(hex: "6B6B6B") ?? Color.gray
    public static let neonGlow = accent // Mapped to subtle accent
    public static let tacticalGreen = success // Mapped to success color
    public static let cautionYellow = warning // Mapped to warning color
    
    // MARK: - Updated zinc colors (light theme)
    public static let zinc900 = Color(hex: "FAFAFA") ?? Color(.systemGray6)
    public static let zinc800 = Color(hex: "F5F5F5") ?? Color(.systemGray5)
    public static let zinc700 = Color(hex: "E0E0E0") ?? Color(.systemGray4)
    public static let zinc600 = Color(hex: "CCCCCC") ?? Color(.systemGray3)
}

// Helper extension to initialize Color from hex string
// Ensures the hex string is valid and parses correctly.
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        // Use Scanner to parse the hex string into a 64-bit unsigned integer.
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            // Return nil if the hex string is invalid.
            return nil
        }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        // Initialize the Color with the extracted RGB values.
        self.init(red: red, green: green, blue: blue)
    }
} 