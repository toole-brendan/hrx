//
//  GeometricRefreshView.swift
//  HandReceipt
//
//  8VC-inspired pull-to-refresh with geometric cube animation
//

import SwiftUI

// MARK: - Refresh State
enum RefreshState: Equatable {
    case idle
    case pulling(progress: CGFloat)
    case refreshing
    case finishing
}

// MARK: - Geometric Refresh View
struct GeometricRefreshView: View {
    let state: RefreshState
    
    private var progress: CGFloat {
        switch state {
        case .idle: return 0
        case .pulling(let p): return p
        case .refreshing, .finishing: return 1
        }
    }
    
    private var scale: CGFloat {
        switch state {
        case .idle: return 0.8
        case .pulling(let p): return 0.8 + (0.2 * p)
        case .refreshing: return 1.0
        case .finishing: return 0.9
        }
    }
    
    var body: some View {
        ZStack {
            // Background fade
            AppColors.secondaryBackground
                .opacity(0.98)
            
            VStack(spacing: 20) {
                // Geometric cube loader
                GeometricCubeWireframe(
                    size: 40,
                    isAnimating: state == .refreshing
                )
                .scaleEffect(scale)
                .opacity(progress)
                .animation(.easeInOut(duration: 0.3), value: scale)
                
                // Status text
                Text(statusText)
                    .font(AppFonts.monoCaption)
                    .foregroundColor(AppColors.secondaryText)
                    .kerning(AppFonts.wideKerning)
                    .opacity(progress > 0.5 ? 1 : 0)
                    .animation(.easeIn(duration: 0.2), value: progress)
            }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }
    
    private var statusText: String {
        switch state {
        case .idle:
            return ""
        case .pulling(let progress):
            return progress < 0.8 ? "PULL TO REFRESH" : "RELEASE TO REFRESH"
        case .refreshing:
            return "UPDATING"
        case .finishing:
            return "COMPLETE"
        }
    }
}

// MARK: - Geometric Cube Wireframe
struct GeometricCubeWireframe: View {
    let size: CGFloat
    let isAnimating: Bool
    
    @State private var rotation: Double = 0
    @State private var innerRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Outer cube
            CubeFrame(size: size)
                .stroke(AppColors.primaryText.opacity(0.3), lineWidth: 1)
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 1, y: 1, z: 0)
                )
            
            // Middle cube
            CubeFrame(size: size * 0.7)
                .stroke(AppColors.primaryText.opacity(0.5), lineWidth: 1)
                .rotation3DEffect(
                    .degrees(rotation * 1.5),
                    axis: (x: 0, y: 1, z: 1)
                )
            
            // Inner cube
            CubeFrame(size: size * 0.4)
                .stroke(AppColors.primaryText.opacity(0.8), lineWidth: 1)
                .rotation3DEffect(
                    .degrees(innerRotation),
                    axis: (x: 1, y: 0, z: 1)
                )
        }
        .onAppear {
            if isAnimating {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    innerRotation = -360
                }
            }
        }
        .onChange(of: isAnimating) { newValue in
            if newValue {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    innerRotation = -360
                }
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    rotation = 0
                    innerRotation = 0
                }
            }
        }
    }
}

// MARK: - Cube Frame Shape
struct CubeFrame: Shape {
    let size: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let centerX = rect.midX
        let centerY = rect.midY
        let halfSize = size / 2
        
        // Front face
        path.move(to: CGPoint(x: centerX - halfSize, y: centerY - halfSize))
        path.addLine(to: CGPoint(x: centerX + halfSize, y: centerY - halfSize))
        path.addLine(to: CGPoint(x: centerX + halfSize, y: centerY + halfSize))
        path.addLine(to: CGPoint(x: centerX - halfSize, y: centerY + halfSize))
        path.closeSubpath()
        
        // Connect to back face (simplified for 2D representation)
        let depth = halfSize * 0.5
        path.move(to: CGPoint(x: centerX - halfSize, y: centerY - halfSize))
        path.addLine(to: CGPoint(x: centerX - halfSize + depth, y: centerY - halfSize - depth))
        
        path.move(to: CGPoint(x: centerX + halfSize, y: centerY - halfSize))
        path.addLine(to: CGPoint(x: centerX + halfSize + depth, y: centerY - halfSize - depth))
        
        path.move(to: CGPoint(x: centerX + halfSize, y: centerY + halfSize))
        path.addLine(to: CGPoint(x: centerX + halfSize + depth, y: centerY + halfSize - depth))
        
        return path
    }
}

// MARK: - Refreshable Modifier
public struct MinimalRefreshableModifier: ViewModifier {
    let action: () async -> Void
    @State private var refreshState: RefreshState = .idle
    @State private var contentOffset: CGFloat = 0
    @State private var previousOffset: CGFloat = 0
    
    private let threshold: CGFloat = 80
    private let maxPull: CGFloat = 150
    
    public init(action: @escaping () async -> Void) {
        self.action = action
    }
    
    public func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            // Refresh indicator
            GeometricRefreshView(state: refreshState)
                .offset(y: refreshOffset)
            
            // Content
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Hidden spacer to detect pull
                        GeometryReader { scrollGeometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: scrollGeometry.frame(in: .named("scroll")).minY
                                )
                        }
                        .frame(height: 0)
                        
                        // Actual content
                        content
                            .offset(y: contentPullOffset)
                    }
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    handleScrollChange(offset)
                }
            }
        }
    }
    
    private var refreshOffset: CGFloat {
        switch refreshState {
        case .idle:
            return -100
        case .pulling(let progress):
            return -100 + (100 * progress)
        case .refreshing, .finishing:
            return 0
        }
    }
    
    private var contentPullOffset: CGFloat {
        switch refreshState {
        case .pulling(let progress):
            return max(0, threshold * progress)
        case .refreshing, .finishing:
            return threshold
        default:
            return 0
        }
    }
    
    private func handleScrollChange(_ offset: CGFloat) {
        // Only track when at top and pulling down
        guard offset > 0 else {
            if refreshState != .refreshing {
                withAnimation(.easeOut(duration: 0.25)) {
                    refreshState = .idle
                }
            }
            return
        }
        
        let pullDistance = min(offset, maxPull)
        let progress = pullDistance / threshold
        
        switch refreshState {
        case .idle, .pulling:
            if pullDistance > 0 {
                refreshState = .pulling(progress: progress)
            }
            
            // Check if should trigger refresh
            if previousOffset > threshold && offset <= threshold && progress >= 1 {
                triggerRefresh()
            }
            
        default:
            break
        }
        
        previousOffset = offset
    }
    
    private func triggerRefresh() {
        withAnimation(.easeInOut(duration: 0.3)) {
            refreshState = .refreshing
        }
        
        Task {
            // Ensure minimum visible time
            await action()
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    refreshState = .finishing
                }
            }
            
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    refreshState = .idle
                }
            }
        }
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View Extension
extension View {
    public func minimalRefreshable(action: @escaping () async -> Void) -> some View {
        modifier(MinimalRefreshableModifier(action: action))
    }
} 