import SwiftUI
import PencilKit

struct SignatureCaptureView: View {
    @State private var canvas = PKCanvasView()
    @State private var hasStrokes = false
    @Environment(\.dismiss) private var dismiss
    
    let onSave: (UIImage) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Canvas
                SignatureCanvas(canvas: $canvas, hasStrokes: $hasStrokes)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                    .padding()
            }
            .background(AppColors.appBackground)
            .navigationBarTitle("Draw Signature", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    if hasStrokes {
                        AppLogger.debug("Save button tapped")
                        AppLogger.debug("hasStrokes state: \(hasStrokes)")
                        
                        // Create signature image with white background
                        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200))
                        let image = renderer.image { context in
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
                        
                        AppLogger.debug("Generated signature image size: \(image.size)")
                        AppLogger.debug("About to call onSave callback")
                        onSave(image)
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