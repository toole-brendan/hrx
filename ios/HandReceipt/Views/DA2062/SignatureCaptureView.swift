import SwiftUI
import PencilKit

struct SignatureCaptureView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (UIImage) -> Void      // callback to parent with drawn image
    
    // PencilKit canvas
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    
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
                            // Render the drawing to an image
                            let drawing = canvasView.drawing
                            
                            // Use the canvas bounds as the full signature area
                            let signatureBounds = canvasView.bounds
                            print("DEBUG: Canvas bounds: \(signatureBounds)")
                            print("DEBUG: Drawing bounds: \(drawing.bounds)")
                            print("DEBUG: Number of strokes: \(drawing.strokes.count)")
                            
                            let image = drawing.image(from: signatureBounds, scale: 2.0)
                            print("DEBUG: Generated signature image size: \(image.size)")
                            
                            onSave(image)            // pass image back to DA2062ExportView
                            dismiss()               // dismiss the signature capture view
                        }
                        .buttonStyle(TextLinkButtonStyle())
                        .disabled(canvasView.drawing.strokes.isEmpty)  // disable if nothing drawn
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
                    
                    CanvasRepresentable(canvasView: $canvasView, toolPicker: toolPicker)
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
                    }
                    .buttonStyle(.minimalSecondary)
                    .disabled(canvasView.drawing.strokes.isEmpty)
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
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasRepresentable
        
        init(_ parent: CanvasRepresentable) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // This delegate method is called when the drawing changes
            // We could use this to provide real-time feedback if needed
        }
    }
}

#Preview {
    SignatureCaptureView { image in
        print("Signature captured: \(image.size)")
    }
} 