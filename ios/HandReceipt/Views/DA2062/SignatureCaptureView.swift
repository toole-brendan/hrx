import SwiftUI
import PencilKit

struct SignatureCaptureView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (UIImage) -> Void      // callback to parent with drawn image
    
    // PencilKit canvas
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var hasStrokes = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 0) {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(TextLinkButtonStyle())
                        
                        Spacer()
                        
                        Text("Draw Your Signature")
                            .font(AppFonts.serifHeadline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Spacer()
                        
                        Button("Save") {
                            print("DEBUG: Save button tapped")
                            print("DEBUG: hasStrokes state: \(hasStrokes)")
                            
                            // Render the drawing to an image
                            let drawing = canvasView.drawing
                            
                            print("DEBUG: Canvas bounds: \(canvasView.bounds)")
                            print("DEBUG: Drawing bounds: \(drawing.bounds)")
                            print("DEBUG: Number of strokes: \(drawing.strokes.count)")
                            
                            // Create a signature area that's properly sized
                            let signatureRect = CGRect(x: 0, y: 0, width: 400, height: 200)
                            
                            // Generate the image using a consistent bounds
                            let image = drawing.image(from: signatureRect, scale: 2.0)
                            print("DEBUG: Generated signature image size: \(image.size)")
                            print("DEBUG: Image description: \(image)")
                            
                            // Test if the image has actual content
                            if let cgImage = image.cgImage {
                                print("DEBUG: CGImage exists with size: \(cgImage.width)x\(cgImage.height)")
                            } else {
                                print("DEBUG: WARNING - No CGImage found!")
                            }
                            
                            print("DEBUG: About to call onSave callback")
                            onSave(image)            // pass image back to DA2062ExportView
                            print("DEBUG: onSave callback completed, dismissing view")
                            dismiss()               // dismiss the signature capture view
                        }
                        .buttonStyle(TextLinkButtonStyle())
                        .disabled(!hasStrokes)  // disable if nothing drawn
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    Divider()
                        .background(AppColors.divider)
                }
                
                // Instructions
                VStack(spacing: 16) {
                    Text("Sign your name as you would on paper")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                    
                    Text("Your signature will be saved securely and applied to all future DA 2062 forms")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                // Canvas
                VStack(spacing: 16) {
                    Text("SIGNATURE")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                        .kerning(AppFonts.wideKerning)
                    
                    CanvasRepresentable(
                        canvasView: $canvasView, 
                        toolPicker: toolPicker,
                        onDrawingChanged: { hasDrawing in
                            hasStrokes = hasDrawing
                        }
                    )
                        .frame(height: 200)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                        .shadow(color: AppColors.shadowColor.opacity(0.1), radius: 4, y: 2)
                    
                    // Clear button
                    Button("Clear") {
                        canvasView.drawing = PKDrawing()  // reset the canvas
                        hasStrokes = false
                    }
                    .buttonStyle(.minimalSecondary)
                    .disabled(!hasStrokes)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Footer note
                VStack(spacing: 8) {
                    Text("This signature will be digitally applied to official forms")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                        .multilineTextAlignment(.center)
                    
                    Text("You can edit or update your signature anytime in the export settings")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(AppColors.appBackground)
        }
        .navigationBarHidden(true)
        .onAppear {
            setupCanvas()
        }
    }
    
    private func setupCanvas() {
        // Configure the canvas for signature capture
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.drawingPolicy = .anyInput  // Allow finger drawing
        canvasView.backgroundColor = UIColor.clear
        
        // Show tool picker on iPad, hide on iPhone for cleaner signature experience
        if UIDevice.current.userInterfaceIdiom == .pad {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        } else {
            toolPicker.setVisible(false, forFirstResponder: canvasView)
        }
    }
}

// UIViewRepresentable wrapper for PKCanvasView
struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let toolPicker: PKToolPicker
    let onDrawingChanged: (Bool) -> Void
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        coordinator.onDrawingChanged = onDrawingChanged
        return coordinator
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasRepresentable
        var onDrawingChanged: ((Bool) -> Void)?
        
        init(_ parent: CanvasRepresentable) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Update the drawing state when strokes change
            let hasStrokes = !canvasView.drawing.strokes.isEmpty
            onDrawingChanged?(hasStrokes)
        }
    }
}

#Preview {
    SignatureCaptureView { image in
        print("Signature captured: \(image.size)")
    }
} 