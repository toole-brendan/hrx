import SwiftUI

// Make the struct public so it can be accessed across the module
public struct AppColors {
    // MARK: - Background Colors (Enhanced contrast with subtle depth)
    public static let appBackground = Color(hex: "000000") ?? Color.black // Pure black for maximum contrast
    public static let secondaryBackground = Color(hex: "0F0F0F") ?? Color(.systemGray6) // Slightly elevated
    public static let tertiaryBackground = Color(hex: "1A1A1A") ?? Color(.systemGray5) // Card backgrounds
    public static let elevatedBackground = Color(hex: "242424") ?? Color(.systemGray4) // Elevated UI elements
    
    // MARK: - Text Colors (Enhanced contrast hierarchy)
    public static let primaryText = Color(hex: "FFFFFF") ?? Color.white // Pure white for maximum readability
    public static let secondaryText = Color(hex: "B8B8B8") ?? Color(.systemGray) // Brighter secondary
    public static let tertiaryText = Color(hex: "808080") ?? Color(.systemGray2) // Mid-tone for labels
    public static let quaternaryText = Color(hex: "4A4A4A") ?? Color(.systemGray3) // Subtle text
    
    // MARK: - Accent Colors (Modern industrial with neon highlights)
    public static let accent = Color(hex: "00D4FF") ?? Color.cyan // Bright cyan for primary actions
    public static let accentDim = Color(hex: "0096B8") ?? Color.blue // Dimmed accent
    public static let accentHighlight = Color(hex: "00F0FF") ?? Color.cyan // Ultra-bright for hover/press
    public static let accentMuted = Color(hex: "005C73") ?? Color.blue.opacity(0.6) // Muted for backgrounds
    
    // MARK: - Status Colors (High contrast warning system)
    public static let destructive = Color(hex: "FF3B30") ?? Color.red // Bright red for errors
    public static let destructiveDim = Color(hex: "8B1A1A") ?? Color.red.opacity(0.6)
    public static let warning = Color(hex: "FFB800") ?? Color.orange // Bright amber
    public static let warningDim = Color(hex: "B37E00") ?? Color.orange.opacity(0.6)
    public static let success = Color(hex: "32D74B") ?? Color.green // Bright green
    public static let successDim = Color(hex: "1B7A2A") ?? Color.green.opacity(0.6)
    
    // MARK: - Special Purpose Colors
    public static let neonGlow = Color(hex: "00FFD4") ?? Color.cyan // For glowing effects
    public static let tacticalGreen = Color(hex: "00FF41") ?? Color.green // Night vision green
    public static let cautionYellow = Color(hex: "FFD700") ?? Color.yellow // High visibility
    
    // MARK: - Border Colors (Subtle but visible)
    public static let border = Color(hex: "2A2A2A") ?? Color.gray.opacity(0.3)
    public static let borderHighlight = Color(hex: "404040") ?? Color.gray.opacity(0.5)
    public static let borderAccent = accent.opacity(0.5)
    
    // MARK: - Category Colors (Military equipment categories)
    public static let weaponsCategory = Color(hex: "FF4444") ?? Color.red
    public static let communicationsCategory = Color(hex: "4A90E2") ?? Color.blue
    public static let opticsCategory = Color(hex: "00D97E") ?? Color.green
    public static let vehiclesCategory = Color(hex: "F5A623") ?? Color.orange
    public static let electronicsCategory = Color(hex: "BD10E0") ?? Color.purple
    
    // MARK: - Legacy/Web-aligned colors (for compatibility)
    public static let mutedBackground = tertiaryBackground
    public static let cardBackground = secondaryBackground
    public static let military = tacticalGreen.opacity(0.8)
    public static let statusGreen = success
    public static let statusAmber = warning
    public static let statusRed = destructive
    public static let statusBlue = accent
    public static let divider = border
    public static let borderMuted = Color(hex: "1F1F1F") ?? Color.gray.opacity(0.2)
    public static let zinc900 = Color(hex: "18181B") ?? Color(.systemGray6)
    public static let zinc800 = Color(hex: "27272A") ?? Color(.systemGray5)
    public static let zinc700 = Color(hex: "3F3F46") ?? Color(.systemGray4)
    public static let zinc600 = Color(hex: "52525B") ?? Color(.systemGray3)
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