//
//  GeometricLoadingAnimations.swift
//  HandReceipt
//
//  8VC-inspired loading animations and states
//

import SwiftUI

// MARK: - Loading Style Configuration
struct LoadingStyleConfiguration {
    let size: CGFloat
    let scale: CGFloat
    let spacing: CGFloat
    let padding: CGFloat
    let font: Font
    let showMessage: Bool
    
    static let inline = LoadingStyleConfiguration(
        size: 24,
        scale: 0.8,
        spacing: 8,
        padding: 8,
        font: AppFonts.caption,
        showMessage: false
    )
    
    static let section = LoadingStyleConfiguration(
        size: 48,
        scale: 1.0,
        spacing: 16,
        padding: 24,
        font: AppFonts.caption,
        showMessage: true
    )
    
    static let fullScreen = LoadingStyleConfiguration(
        size: 80,
        scale: 1.2,
        spacing: 24,
        padding: 40,
        font: AppFonts.body,
        showMessage: true
    )
}

// MARK: - Minimal Loading View
public struct MinimalLoadingView: View {
    let message: String?
    let style: LoadingStyle
    
    public enum LoadingStyle {
        case inline
        case section
        case fullScreen
        
        var config: LoadingStyleConfiguration {
            switch self {
            case .inline: return .inline
            case .section: return .section
            case .fullScreen: return .fullScreen
            }
        }
    }
    
    public init(message: String? = nil, style: LoadingStyle) {
        self.message = message
        self.style = style
    }
    
    public var body: some View {
        VStack(spacing: style.config.spacing) {
            GeometricAnimationLoader(
                style: style,
                size: style.config.size
            )
            
            if style.config.showMessage, let message = message {
                Text(message.uppercased())
                    .font(style.config.font)
                    .foregroundColor(AppColors.tertiaryText)
                    .kerning(AppFonts.wideKerning)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(style.config.padding)
        .frame(maxWidth: style == .fullScreen ? .infinity : nil)
        .frame(maxHeight: style == .fullScreen ? .infinity : nil)
        .background(
            style == .fullScreen ? AppColors.appBackground : Color.clear
        )
    }
}

// MARK: - Geometric Animation Loader
struct GeometricAnimationLoader: View {
    let style: MinimalLoadingView.LoadingStyle
    let size: CGFloat
    
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Multiple nested shapes for depth
            ForEach(0..<3) { index in
                RotatingShape(
                    index: index,
                    size: size * (1.0 - CGFloat(index) * 0.25),
                    rotation: rotation + Double(index * 45),
                    opacity: 1.0 - Double(index) * 0.3
                )
            }
        }
        .scaleEffect(scale)
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Rotation animation
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        
        // Scale pulsing
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            scale = 1.1
        }
        
        // Opacity fade
        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
            opacity = 1.0
        }
    }
}

// MARK: - Rotating Shape Component
struct RotatingShape: View {
    let index: Int
    let size: CGFloat
    let rotation: Double
    let opacity: Double
    
    var body: some View {
        GeometricShape(sides: 4 + index)
            .stroke(
                AppColors.primaryText.opacity(opacity * 0.8),
                style: StrokeStyle(
                    lineWidth: 1.5 - Double(index) * 0.3,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .rotation3DEffect(
                .degrees(rotation * 0.5),
                axis: (x: index % 2 == 0 ? 1 : 0, y: index % 2 == 1 ? 1 : 0, z: 0.5)
            )
    }
}

// MARK: - Geometric Shape
struct GeometricShape: Shape {
    let sides: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angle = 2 * .pi / Double(sides)
        
        for i in 0..<sides {
            let currentAngle = angle * Double(i) - .pi / 2
            let x = center.x + radius * cos(currentAngle)
            let y = center.y + radius * sin(currentAngle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Loading State Container
public struct LoadingStateView<Content: View>: View {
    let isLoading: Bool
    let error: String?
    let isEmpty: Bool
    let loadingMessage: String?
    let emptyStateConfig: EmptyStateConfig?
    let content: () -> Content
    
    public struct EmptyStateConfig {
        let icon: String
        let title: String
        let message: String
        let actionLabel: String?
        let action: (() -> Void)?
        
        public init(icon: String, title: String, message: String, actionLabel: String? = nil, action: (() -> Void)? = nil) {
            self.icon = icon
            self.title = title
            self.message = message
            self.actionLabel = actionLabel
            self.action = action
        }
    }
    
    public init(
        isLoading: Bool,
        error: String? = nil,
        isEmpty: Bool,
        loadingMessage: String? = nil,
        emptyStateConfig: EmptyStateConfig? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.error = error
        self.isEmpty = isEmpty
        self.loadingMessage = loadingMessage
        self.emptyStateConfig = emptyStateConfig
        self.content = content
    }
    
    public var body: some View {
        ZStack {
            if let error = error {
                MinimalEmptyState(
                    icon: "exclamationmark.circle",
                    title: "Error",
                    message: error,
                    action: emptyStateConfig?.action,
                    actionLabel: "Retry"
                )
            } else if isLoading {
                MinimalLoadingView(
                    message: loadingMessage,
                    style: .section
                )
            } else if isEmpty, let config = emptyStateConfig {
                MinimalEmptyState(
                    icon: config.icon,
                    title: config.title,
                    message: config.message,
                    action: config.action,
                    actionLabel: config.actionLabel
                )
            } else {
                content()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .animation(.easeInOut(duration: 0.3), value: error != nil)
        .animation(.easeInOut(duration: 0.3), value: isEmpty)
    }
}

// MARK: - Skeleton Loading
public struct SkeletonLoadingView: View {
    let rows: Int
    
    @State private var shimmerOffset: CGFloat = -1
    
    public init(rows: Int = 5) {
        self.rows = rows
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<rows, id: \.self) { _ in
                SkeletonRow()
                    .modifier(ShimmerModifier(offset: shimmerOffset))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 2
            }
        }
    }
}

struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 16) {
            // Avatar placeholder
            Circle()
                .fill(AppColors.tertiaryBackground)
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 8) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.tertiaryBackground)
                    .frame(width: 200, height: 16)
                
                // Subtitle placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.tertiaryBackground)
                    .frame(width: 150, height: 12)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

// MARK: - Shimmer Modifier
struct ShimmerModifier: ViewModifier {
    let offset: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            AppColors.appBackground.opacity(0.6),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.3)
                    .offset(x: geometry.size.width * offset)
                    .allowsHitTesting(false)
                }
                .clipped()
            )
    }
}

// MARK: - Progress Indicator
public struct MinimalProgressIndicator: View {
    let progress: Double
    let showPercentage: Bool
    
    public init(progress: Double, showPercentage: Bool = true) {
        self.progress = progress
        self.showPercentage = showPercentage
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background track
                Circle()
                    .stroke(AppColors.tertiaryBackground, lineWidth: 4)
                
                // Progress arc
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        AppColors.primaryText,
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
                
                if showPercentage {
                    Text("\(Int(progress * 100))%")
                        .font(AppFonts.monoBody)
                        .foregroundColor(AppColors.primaryText)
                }
            }
            .frame(width: 60, height: 60)
        }
    }
}

// MARK: - Loading Button
public struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    public init(title: String, isLoading: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(isLoading ? 0 : 1)
                
                if isLoading {
                    GeometricAnimationLoader(
                        style: .inline,
                        size: 16
                    )
                }
            }
            .frame(minWidth: 120)
        }
        .buttonStyle(MinimalPrimaryButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - View Extensions
extension View {
    public func loadingState<T>(
        data: T?,
        isLoading: Bool,
        error: String? = nil,
        loadingMessage: String? = nil,
        emptyConfig: LoadingStateView<Self>.EmptyStateConfig? = nil
    ) -> some View where T: Collection {
        LoadingStateView(
            isLoading: isLoading,
            error: error,
            isEmpty: data?.isEmpty ?? true,
            loadingMessage: loadingMessage,
            emptyStateConfig: emptyConfig,
            content: { self }
        )
    }
    
    public func skeletonLoading(isLoading: Bool, rows: Int = 5) -> some View {
        ZStack {
            if isLoading {
                SkeletonLoadingView(rows: rows)
            } else {
                self
            }
        }
    }
} 