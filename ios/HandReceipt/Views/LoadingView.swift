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
            // Light background
            AppColors.appBackground.ignoresSafeArea()
            
            // Subtle geometric pattern overlay
            GeometryReader { geometry in
                Path { path in
                    let gridSize: CGFloat = 80
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    // Create a minimal grid pattern
                    for x in stride(from: 0, through: width, by: gridSize) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    
                    for y in stride(from: 0, through: height, by: gridSize) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(AppColors.border.opacity(0.05), lineWidth: 0.5)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 60) {
                // Elegant loading animation
                ZStack {
                    // Single minimal loading ring
                    Circle()
                        .stroke(AppColors.border, lineWidth: 2)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(AppColors.primaryText, lineWidth: 2)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(isRotating))
                        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isRotating)
                    
                    // Center dot
                    Circle()
                        .fill(AppColors.primaryText)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isScaling ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isScaling)
                }
                
                VStack(spacing: 24) {
                    // App name with elegant serif
                    Text("HandReceipt")
                        .font(AppFonts.serifHero)
                        .foregroundColor(AppColors.primaryText)
                        .opacity(textOpacity)
                        .animation(.easeIn(duration: 1.0), value: textOpacity)
                    
                    // Minimal subtitle
                    Text("Property Management System")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                        .opacity(textOpacity)
                        .animation(.easeIn(duration: 1.0).delay(0.3), value: textOpacity)
                    
                    // Loading status or error state
                    if let error = error {
                        // Minimal error state
                        VStack(spacing: 20) {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(AppColors.destructive)
                                
                                Text("Connection Error")
                                    .font(AppFonts.headline)
                                    .foregroundColor(AppColors.primaryText)
                            }
                            
                            Text(error.localizedDescription)
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            HStack(spacing: 16) {
                                if let onRetry = onRetry {
                                    Button(action: onRetry) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 14, weight: .light))
                                            Text("Retry")
                                        }
                                    }
                                    .buttonStyle(MinimalPrimaryButtonStyle())
                                }
                                
                                if let onSkipToLogin = onSkipToLogin {
                                    Button(action: onSkipToLogin) {
                                        Text("Continue to Login")
                                    }
                                    .buttonStyle(MinimalSecondaryButtonStyle())
                                }
                            }
                        }
                        .padding(.top, 32)
                        .opacity(textOpacity)
                        .animation(.easeIn(duration: 1.0).delay(0.6), value: textOpacity)
                    } else {
                        // Minimal loading state
                        VStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Text("Loading")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.secondaryText)
                                
                                // Subtle animated dots
                                HStack(spacing: 4) {
                                    ForEach(0..<3) { index in
                                        Circle()
                                            .fill(AppColors.secondaryText)
                                            .frame(width: 4, height: 4)
                                            .opacity(dotCount > index ? 1.0 : 0.3)
                                    }
                                }
                            }
                        }
                        .padding(.top, 32)
                        .opacity(textOpacity)
                        .animation(.easeIn(duration: 1.0).delay(0.6), value: textOpacity)
                    }
                }
                
                // Minimal version info
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("Version \(version) (\(build))")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText.opacity(0.7))
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

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
            .previewDisplayName("8VC Style Loading")
        
        LoadingView(error: NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network connection failed"]))
            .previewDisplayName("Error State")
    }
} 