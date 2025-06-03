import SwiftUI

struct AuthScreensComparison: View {
    @State private var selectedScreen = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Title
                Text("Authentication Screens Transformation")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .padding(.top, 40)
                
                // Screen selector
                Picker("Screen", selection: $selectedScreen) {
                    Text("Login").tag(0)
                    Text("Registration").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 80)
                
                if selectedScreen == 0 {
                    LoginComparisonView()
                } else {
                    RegistrationComparisonView()
                }
                
                // Key improvements summary
                ImprovementsCard()
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Color(hex: "FAFAFA"))
    }
}

// MARK: - Login Comparison

struct LoginComparisonView: View {
    var body: some View {
        VStack(spacing: 32) {
            Text("Login Screen Redesign")
                .font(.system(size: 24, weight: .semibold, design: .serif))
            
            HStack(spacing: 20) {
                // Before
                VStack(alignment: .leading, spacing: 12) {
                    Label("BEFORE", systemImage: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                    
                    OldLoginMockup()
                        .frame(width: 300, height: 600)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        )
                }
                
                // After
                VStack(alignment: .leading, spacing: 12) {
                    Label("AFTER", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                    
                    NewLoginMockup()
                        .frame(width: 300, height: 600)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        )
                }
            }
        }
    }
}

// MARK: - Registration Comparison

struct RegistrationComparisonView: View {
    var body: some View {
        VStack(spacing: 32) {
            Text("Registration Screen Redesign")
                .font(.system(size: 24, weight: .semibold, design: .serif))
            
            HStack(spacing: 20) {
                // Before
                VStack(alignment: .leading, spacing: 12) {
                    Label("BEFORE", systemImage: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                    
                    OldRegistrationMockup()
                        .frame(width: 300, height: 600)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        )
                }
                
                // After
                VStack(alignment: .leading, spacing: 12) {
                    Label("AFTER", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                    
                    NewRegistrationMockup()
                        .frame(width: 300, height: 600)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        )
                }
            }
        }
    }
}

// MARK: - Old Login Mockup

struct OldLoginMockup: View {
    var body: some View {
        ZStack {
            // Old light background
            Color(hex: "FAFAFA")
            
            VStack(spacing: 0) {
                // Large logo
                VStack(spacing: 16) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 100))
                        .foregroundColor(Color(hex: "4A4A4A"))
                    
                    Text("handreceipt")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "4A4A4A"))
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                
                // Card container (the issue!)
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text("Welcome Back")
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundColor(.black)
                        
                        Text("Enter your credentials to access\nyour account")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "6B6B6B"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "6B6B6B"))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "6B6B6B"))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                                )
                        }
                    }
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "arrow.right")
                            Text("Sign In")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.black)
                        .cornerRadius(4)
                    }
                }
                .padding(32)
                .background(Color.white)
                .cornerRadius(4)
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
}

// MARK: - New Login Mockup

struct NewLoginMockup: View {
    var body: some View {
        ZStack {
            // Clean background
            Color(hex: "FAFAFA")
            
            // Subtle pattern
            GeometryReader { geometry in
                Path { path in
                    for x in stride(from: 0, to: geometry.size.width, by: 60) {
                        for y in stride(from: 0, to: geometry.size.height, by: 60) {
                            path.addRect(CGRect(x: x, y: y, width: 30, height: 30))
                        }
                    }
                }
                .stroke(Color(hex: "E0E0E0").opacity(0.3), lineWidth: 0.5)
            }
            
            VStack(spacing: 0) {
                // Full-size logo maintained
                VStack(spacing: 24) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 100, weight: .regular))
                        .foregroundColor(Color(hex: "6B6B6B"))
                    
                    Text("Property Management System")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "4A4A4A"))
                }
                .padding(.top, 60)
                .padding(.bottom, 60)
                
                // No container - direct placement
                VStack(alignment: .leading, spacing: 48) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Welcome Back")
                            .font(.system(size: 48, weight: .bold, design: .serif))
                            .foregroundColor(.black)
                        
                        Text("Sign in to continue")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "6B6B6B"))
                    }
                    
                    // Fields with underlines only
                    VStack(spacing: 36) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("USERNAME")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "6B6B6B"))
                                .tracking(1)
                            
                            Rectangle()
                                .fill(Color(hex: "E0E0E0"))
                                .frame(height: 1)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PASSWORD")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "6B6B6B"))
                                .tracking(1)
                            
                            Rectangle()
                                .fill(Color(hex: "E0E0E0"))
                                .frame(height: 1)
                        }
                    }
                    
                    // Minimal button
                    Button(action: {}) {
                        HStack {
                            Text("Sign In")
                                .font(.system(size: 16, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.black)
                        .cornerRadius(4)
                    }
                    
                    // Text link
                    VStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "9B9B9B"))
                        
                        Text("Create one")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "0066CC"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                }
                .padding(.horizontal, 48)
                
                Spacer()
            }
        }
    }
}

// MARK: - Old Registration Mockup

struct OldRegistrationMockup: View {
    var body: some View {
        ZStack {
            Color(hex: "FAFAFA")
            
            VStack(spacing: 20) {
                // Header with system icon
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "4A4A4A"))
                    
                    Text("Create Account")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("Join HandReceipt System")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                // Form with rounded text fields
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "F0F0F0"))
                            .frame(height: 40)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "F0F0F0"))
                            .frame(height: 40)
                    }
                    
                    ForEach(0..<4) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "F0F0F0"))
                            .frame(height: 40)
                    }
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Create Account")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.gray)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
}

// MARK: - New Registration Mockup

struct NewRegistrationMockup: View {
    var body: some View {
        ZStack {
            Color(hex: "FAFAFA")
            
            VStack(alignment: .leading, spacing: 0) {
                // Clean back button
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14))
                    Text("Back")
                        .font(.system(size: 16))
                }
                .foregroundColor(Color(hex: "4A4A4A"))
                .padding(.top, 30)
                .padding(.horizontal, 48)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 56) {
                        // Serif header
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Create Account")
                                .font(.system(size: 32, weight: .bold, design: .serif))
                            
                            Text("Join the property management system")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "6B6B6B"))
                        }
                        
                        // Section 1
                        VStack(alignment: .leading, spacing: 24) {
                            Text("PERSONAL INFORMATION")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "4A4A4A"))
                                .tracking(2)
                            
                            Rectangle()
                                .fill(Color(hex: "E0E0E0"))
                                .frame(height: 1)
                            
                            HStack(spacing: 24) {
                                UnderlineFieldMockup(label: "FIRST NAME")
                                UnderlineFieldMockup(label: "LAST NAME")
                            }
                            
                            UnderlineFieldMockup(label: "USERNAME")
                            UnderlineFieldMockup(label: "EMAIL")
                        }
                        
                        // Section 2
                        VStack(alignment: .leading, spacing: 24) {
                            Text("MILITARY DETAILS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "4A4A4A"))
                                .tracking(2)
                            
                            Rectangle()
                                .fill(Color(hex: "E0E0E0"))
                                .frame(height: 1)
                            
                            HStack(spacing: 24) {
                                UnderlineFieldMockup(label: "RANK")
                                UnderlineFieldMockup(label: "UNIT")
                            }
                        }
                        
                        // Clean button
                        Button(action: {}) {
                            Text("Create Account")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.black)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.top, 40)
                }
            }
        }
    }
}

struct UnderlineFieldMockup: View {
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "6B6B6B"))
                .tracking(1)
            
            Rectangle()
                .fill(Color(hex: "E0E0E0"))
                .frame(height: 1)
        }
    }
}

// MARK: - Improvements Card

struct ImprovementsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Key Improvements")
                .font(.system(size: 20, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 16) {
                ImprovementItem(
                    icon: "square.dashed",
                    title: "No Containers",
                    description: "Removed card backgrounds for cleaner, more open design"
                )
                
                ImprovementItem(
                    icon: "textformat",
                    title: "Typography Hierarchy",
                    description: "Serif fonts for headers, monospace for technical elements"
                )
                
                ImprovementItem(
                    icon: "minus.rectangle",
                    title: "Minimal Fields",
                    description: "Simple underlines instead of boxed inputs"
                )
                
                ImprovementItem(
                    icon: "arrow.left.and.right",
                    title: "Generous Spacing",
                    description: "48px horizontal margins, increased vertical spacing"
                )
                
                ImprovementItem(
                    icon: "cube",
                    title: "Subtle Patterns",
                    description: "Geometric background inspired by 8VC's aesthetic"
                )
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
        }
    }
}

struct ImprovementItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundColor(Color(hex: "0066CC"))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6B6B6B"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

struct AuthScreensComparison_Previews: PreviewProvider {
    static var previews: some View {
        AuthScreensComparison()
            .previewDevice("iPad Pro (12.9-inch)")
    }
}