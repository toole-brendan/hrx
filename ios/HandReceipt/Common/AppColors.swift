import SwiftUI

// Make the struct public so it can be accessed across the module
public struct AppColors {
    // Background Colors (Dark, more industrial) - Web Aligned
    public static let appBackground = Color(hex: "0A0A0A") ?? Color(.black) // Nearly black for higher contrast
    public static let secondaryBackground = Color(hex: "1A1A1A") ?? Color(.systemGray6) // Darker gray
    public static let tertiaryBackground = Color(hex: "252525") ?? Color(.systemGray5) // For subtle layering
    
    // Web-aligned muted backgrounds
    public static let mutedBackground = Color(hex: "1F1F1F") ?? Color(.systemGray6) // Matches web's bg-muted/80
    public static let cardBackground = Color(hex: "1A1A1A") ?? Color(.systemGray6) // Card backgrounds
    
    // Text Colors (High contrast for military/industrial legibility)
    public static let primaryText = Color(hex: "F5F5F5") ?? Color(.white) // Brighter white for better contrast
    public static let secondaryText = Color(hex: "A0A0A0") ?? Color(.systemGray) // Medium gray
    public static let tertiaryText = Color(hex: "6A6A6A") ?? Color(.systemGray2) // Darker gray for less important text

    // Accent Colors (Industrial/Military palette)
    public static let accent = Color(hex: "2A5885") ?? Color.blue // Desaturated blue - primary accent
    public static let accentHighlight = Color(hex: "3A78B5") ?? Color.blue.opacity(0.8) // Slightly lighter for highlights

    // Status Colors - Web Aligned
    public static let destructive = Color(hex: "A02C2C") ?? Color.red // Darker desaturated red
    public static let warning = Color(hex: "9D6E21") ?? Color.orange // Desaturated orange/amber 
    public static let success = Color(hex: "29683F") ?? Color.green // Desaturated military green
    public static let military = Color(hex: "4A7C59") ?? Color.green.opacity(0.8) // Military olive green
    
    // Web-aligned status colors
    public static let statusGreen = Color(hex: "16A34A") ?? Color.green // green-600
    public static let statusAmber = Color(hex: "D97706") ?? Color.orange // amber-600
    public static let statusRed = Color(hex: "DC2626") ?? Color.red // red-600
    public static let statusBlue = Color(hex: "2563EB") ?? Color.blue // blue-600
    
    // Military Category Colors (for different types of equipment)
    public static let weaponsCategory = Color(hex: "8B2E2E") ?? Color.red.opacity(0.7) // Dark red
    public static let communicationsCategory = Color(hex: "395F94") ?? Color.blue.opacity(0.7) // Navy blue
    public static let opticsCategory = Color(hex: "3A633A") ?? Color.green.opacity(0.7) // Military green
    public static let vehiclesCategory = Color(hex: "6B5226") ?? Color.brown.opacity(0.7) // Brown/tan
    public static let electronicsCategory = Color(hex: "494A73") ?? Color.indigo.opacity(0.7) // Deep blue/indigo
    
    // Border/Divider Colors - Web Aligned
    public static let border = Color(hex: "323232") ?? Color.gray.opacity(0.3) // Subtle border - matches web's border-border
    public static let divider = Color(hex: "3A3A3A") ?? Color.gray.opacity(0.5) // Slightly more visible divider
    public static let borderMuted = Color(hex: "2A2A2A") ?? Color.gray.opacity(0.2) // Even more subtle borders
    
    // Zinc colors to match web dashboard
    public static let zinc900 = Color(hex: "18181B") ?? Color(.systemGray6) // Dark zinc for dark mode
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