import SwiftUI

struct LoadingView: View {
    @State private var isRotating = 0.0
    @State private var isScaling = false
    @State private var textOpacity = 0.0
    @State private var dotCount = 0
    
    var error: Error? = nil
    var onRetry: (() -> Void)? = nil
    var onSkipToLogin: (() -> Void)? = nil
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Background
            AppColors.appBackground.ignoresSafeArea()
            
            // Subtle grid pattern overlay
            GeometryReader { geometry in
                Path { path in
                    let gridSize: CGFloat = 50
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    // Vertical lines
                    for x in stride(from: 0, through: width, by: gridSize) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    
                    // Horizontal lines
                    for y in stride(from: 0, through: height, by: gridSize) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(AppColors.border.opacity(0.1), lineWidth: 0.5)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 48) {
                // Logo and spinning element
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppColors.accent,
                                    AppColors.accent.opacity(0.3),
                                    AppColors.accent.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(isRotating))
                        .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: isRotating)
                    
                    // Inner rotating ring (opposite direction)
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppColors.accent.opacity(0.1),
                                    AppColors.accent.opacity(0.3),
                                    AppColors.accent
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-isRotating * 1.5))
                        .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: isRotating)
                    
                    // Center icon
                    VStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(AppColors.accent)
                            .scaleEffect(isScaling ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isScaling)
                        
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.success)
                            .offset(y: -5)
                    }
                }
                
                VStack(spacing: 16) {
                    // App name with military stencil style
                    Text("HAND RECEIPT")
                        .font(.system(size: 36, weight: .heavy, design: .default))
                        .tracking(4)
                        .foregroundColor(AppColors.primaryText)
                        .opacity(textOpacity)
                        .animation(.easeIn(duration: 1.0), value: textOpacity)
                    
                    // Subtitle
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(AppColors.accent)
                            .frame(width: 30, height: 2)
                        
                        Text("PROPERTY ACCOUNTABILITY SYSTEM")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(2)
                            .foregroundColor(AppColors.secondaryText)
                        
                        Rectangle()
                            .fill(AppColors.accent)
                            .frame(width: 30, height: 2)
                    }
                    .opacity(textOpacity)
                    .animation(.easeIn(duration: 1.0).delay(0.3), value: textOpacity)
                    
                    // Loading status or error state
                    if let error = error {
                        // Error state
                        VStack(spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.destructive)
                                
                                Text("AUTHENTICATION FAILED")
                                    .font(.system(size: 14, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundColor(AppColors.destructive)
                            }
                            
                            Text(error.localizedDescription)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.tertiaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            HStack(spacing: 16) {
                                if let onRetry = onRetry {
                                    Button(action: onRetry) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 12))
                                            Text("RETRY")
                                                .font(.system(size: 12, weight: .bold))
                                                .tracking(1.0)
                                        }
                                        .foregroundColor(AppColors.primaryText)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(AppColors.accent)
                                        .cornerRadius(4)
                                    }
                                }
                                
                                if let onSkipToLogin = onSkipToLogin {
                                    Button(action: onSkipToLogin) {
                                        Text("LOGIN")
                                            .font(.system(size: 12, weight: .bold))
                                            .tracking(1.0)
                                            .foregroundColor(AppColors.accent)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(AppColors.accent, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.top, 32)
                        .opacity(textOpacity)
                        .animation(.easeIn(duration: 1.0).delay(0.6), value: textOpacity)
                    } else {
                        // Loading state
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Text("AUTHENTICATING")
                                    .font(.system(size: 14, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundColor(AppColors.tertiaryText)
                                
                                // Animated dots
                                HStack(spacing: 2) {
                                    ForEach(0..<3) { index in
                                        Text(".")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(AppColors.accent)
                                            .opacity(dotCount > index ? 1.0 : 0.3)
                                    }
                                }
                            }
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background
                                    Rectangle()
                                        .fill(AppColors.secondaryBackground)
                                        .frame(height: 4)
                                        .overlay(
                                            Rectangle()
                                                .stroke(AppColors.border, lineWidth: 1)
                                        )
                                    
                                    // Animated fill
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    AppColors.accent,
                                                    AppColors.accent.opacity(0.7)
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * 0.7, height: 4)
                                        .scaleEffect(x: isScaling ? 1.0 : 0.3, y: 1.0, anchor: .leading)
                                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isScaling)
                                }
                            }
                            .frame(height: 4)
                            .frame(maxWidth: 200)
                        }
                        .padding(.top, 32)
                        .opacity(textOpacity)
                        .animation(.easeIn(duration: 1.0).delay(0.6), value: textOpacity)
                    }
                }
                
                // Version info
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("v\(version) (\(build))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.tertiaryText.opacity(0.5))
                        .opacity(textOpacity)
                        .animation(.easeIn(duration: 1.0).delay(0.9), value: textOpacity)
                }
            }
        }
        .onAppear {
            withAnimation {
                isRotating = 360
                isScaling = true
                textOpacity = 1.0
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

// Military-style badge component
struct MilitaryBadge: View {
    let text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.0)
        }
        .foregroundColor(AppColors.primaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(AppColors.accent.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppColors.accent, lineWidth: 1)
                )
        )
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
            .preferredColorScheme(.dark)
    }
} 