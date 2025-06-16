import SwiftUI
import PencilKit

struct SignatureCaptureView: View {
    @State private var canvas = PKCanvasView()
    @State private var hasStrokes = false
    @State private var signatureAngle: Double = -45 // Default diagonal
    @Environment(\.dismiss) private var dismiss
    
    let onSave: (UIImage) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Canvas
                SignatureCanvas(canvas: $canvas, hasStrokes: $hasStrokes)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                // Angle adjustment controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signature Angle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("-90°")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $signatureAngle, in: -90...90, step: 5) {
                            Text("Angle")
                        }
                        .accentColor(AppColors.accent)
                        
                        Text("90°")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(Int(signatureAngle))°")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Preview with rotation
                if hasStrokes {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            Rectangle()
                                .fill(Color.white)
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                                )
                            
                            // Signature preview with rotation
                            SignaturePreview(canvas: canvas, angle: signatureAngle)
                                .frame(height: 60)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .background(AppColors.appBackground)
            .navigationBarTitle("Draw Signature", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    if hasStrokes {
                        AppLogger.debug("Save button tapped with angle: \(signatureAngle)")
                        AppLogger.debug("hasStrokes state: \(hasStrokes)")
                        
                        // Create signature image with rotation applied
                        let baseImage = createSignatureImage()
                        let rotatedImage = rotateImage(baseImage, angle: signatureAngle)
                        
                        AppLogger.debug("Generated signature image size: \(rotatedImage.size)")
                        AppLogger.debug("About to call onSave callback")
                        onSave(rotatedImage)
                        AppLogger.debug("onSave callback completed, dismissing view")
                        dismiss()
                    }
                }
                .disabled(!hasStrokes)
            )
        }
        .onAppear {
            setupCanvas()
        }
    }
    
    private func setupCanvas() {
        // Disable audio feedback to prevent HALC_ProxyIOContext errors
        canvas.drawingPolicy = .anyInput
        canvas.isRulerActive = false
        
        // Set up the tool
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        
        // Disable handwriting recognition to prevent handwritingd errors
        #if targetEnvironment(simulator)
        canvas.isScrollEnabled = false
        #endif
    }
    
    private func createSignatureImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 400, height: 200)))
            
            let drawingImage = canvas.drawing.image(
                from: canvas.drawing.bounds,
                scale: 2.0
            )
            drawingImage.draw(at: CGPoint(
                x: (400 - drawingImage.size.width) / 2,
                y: (200 - drawingImage.size.height) / 2
            ))
        }
    }
    
    private func rotateImage(_ image: UIImage, angle: Double) -> UIImage {
        let radians = angle * .pi / 180.0
        
        // Calculate the size of the rotated image
        let rotatedViewBox = UIView(frame: CGRect(origin: .zero, size: image.size))
        let transform = CGAffineTransform(rotationAngle: CGFloat(radians))
        rotatedViewBox.transform = transform
        let rotatedSize = rotatedViewBox.frame.size
        
        // Create the rotated image
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        // Move the origin to the center of the image
        context.translateBy(x: rotatedSize.width / 2.0, y: rotatedSize.height / 2.0)
        
        // Rotate the context
        context.rotate(by: CGFloat(radians))
        
        // Draw the image
        image.draw(in: CGRect(
            x: -image.size.width / 2.0,
            y: -image.size.height / 2.0,
            width: image.size.width,
            height: image.size.height
        ))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

struct SignaturePreview: View {
    let canvas: PKCanvasView
    let angle: Double
    
    var body: some View {
        if !canvas.drawing.bounds.isEmpty {
            Image(uiImage: createPreviewImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .rotationEffect(.degrees(angle))
                .clipped()
        }
    }
    
    private func createPreviewImage() -> UIImage {
        let drawingImage = canvas.drawing.image(
            from: canvas.drawing.bounds,
            scale: 1.0
        )
        return drawingImage
    }
}

struct SignatureCanvas: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    @Binding var hasStrokes: Bool
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        
        // Prevent PKPaletteNamedDefaults warnings
        if #available(iOS 14.0, *) {
            canvas.drawingPolicy = .anyInput
        }
        
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(hasStrokes: $hasStrokes)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var hasStrokes: Bool
        
        init(hasStrokes: Binding<Bool>) {
            _hasStrokes = hasStrokes
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            hasStrokes = !canvasView.drawing.bounds.isEmpty
        }
    }
}

#Preview {
    SignatureCaptureView { image in
        AppLogger.debug("Signature captured: \(image.size)")
    }
} 