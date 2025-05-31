import SwiftUI
import AVFoundation
import Vision

// Camera view for barcode and text scanning
struct CameraView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var isScanning: Bool
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        if isScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraViewControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func didScanCode(_ code: String) {
            parent.scannedCode = code
        }
    }
}

// MARK: - Camera View Controller

protocol CameraViewControllerDelegate: AnyObject {
    func didScanCode(_ code: String)
}

class CameraViewController: UIViewController {
    weak var delegate: CameraViewControllerDelegate?
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var isProcessing = false
    private var lastScannedCode: String?
    private var lastScanTime: Date?
    private var isConfigured = false
    private var shouldStartWhenReady = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        // Check camera permissions first
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCameraSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.configureCameraSession()
                } else {
                    print("Camera access denied")
                }
            }
        case .denied, .restricted:
            print("Camera access denied or restricted")
        @unknown default:
            print("Unknown camera authorization status")
        }
    }
    
    private func configureCameraSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            defer {
                self.captureSession.commitConfiguration()
                self.isConfigured = true
                
                // Start scanning if it was requested while configuring
                if self.shouldStartWhenReady {
                    self.shouldStartWhenReady = false
                    if !self.captureSession.isRunning {
                        self.captureSession.startRunning()
                    }
                }
            }
            
            // Add video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("Failed to get video device")
                return
            }
            
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                } else {
                    print("Cannot add video input to session")
                    return
                }
            } catch {
                print("Failed to create video input: \(error)")
                return
            }
            
            // Configure video output
            self.videoOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
            self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            } else {
                print("Cannot add video output to session")
                return
            }
            
            // Set up preview layer
            DispatchQueue.main.async {
                self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                self.previewLayer?.videoGravity = .resizeAspectFill
                self.previewLayer?.frame = self.view.bounds
                
                if let previewLayer = self.previewLayer {
                    self.view.layer.insertSublayer(previewLayer, at: 0)
                }
            }
        }
    }
    
    func startScanning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.isConfigured {
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
            } else {
                // Mark that we should start when configuration is complete
                self.shouldStartWhenReady = true
            }
        }
    }
    
    func stopScanning() {
        sessionQueue.async { [weak self] in
            if self?.captureSession.isRunning ?? false {
                self?.captureSession.stopRunning()
            }
        }
    }
}

// MARK: - Video Output Delegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessing else { return }
        
        // Debounce scanning - wait at least 1 second between scans
        if let lastTime = lastScanTime, Date().timeIntervalSince(lastTime) < 1.0 {
            return
        }
        
        isProcessing = true
        
        // Process the frame for barcodes and text
        processFrame(sampleBuffer: sampleBuffer)
    }
    
    private func processFrame(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessing = false
            return
        }
        
        // Try barcode detection first
        detectBarcode(in: pixelBuffer) { [weak self] barcodeResult in
            if let code = barcodeResult {
                self?.handleScannedCode(code)
                return
            }
            
            // If no barcode found, try text recognition
            self?.detectText(in: pixelBuffer) { textResult in
                if let code = textResult {
                    self?.handleScannedCode(code)
                } else {
                    self?.isProcessing = false
                }
            }
        }
    }
    
    private func detectBarcode(in pixelBuffer: CVPixelBuffer, completion: @escaping (String?) -> Void) {
        let request = VNDetectBarcodesRequest { request, error in
            guard error == nil,
                  let results = request.results as? [VNBarcodeObservation],
                  let barcode = results.first,
                  let payload = barcode.payloadStringValue else {
                completion(nil)
                return
            }
            
            completion(payload)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            completion(nil)
        }
    }
    
    private func detectText(in pixelBuffer: CVPixelBuffer, completion: @escaping (String?) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let results = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            // Look for serial number patterns
            for observation in results {
                guard let candidate = observation.topCandidates(1).first else { continue }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check if it looks like a serial number (alphanumeric, reasonable length)
                if self.isValidSerialNumber(text) {
                    completion(text)
                    return
                }
            }
            
            completion(nil)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            completion(nil)
        }
    }
    
    private func isValidSerialNumber(_ text: String) -> Bool {
        // Basic validation - adjust based on your serial number format
        let cleanText = text.replacingOccurrences(of: " ", with: "")
        let isValidLength = cleanText.count >= 6 && cleanText.count <= 20
        let isAlphanumeric = cleanText.range(of: "^[A-Z0-9-]+$", options: [.regularExpression, .caseInsensitive]) != nil
        
        return isValidLength && isAlphanumeric
    }
    
    private func handleScannedCode(_ code: String) {
        // Avoid duplicate scans
        if code == lastScannedCode {
            isProcessing = false
            return
        }
        
        lastScannedCode = code
        lastScanTime = Date()
        
        DispatchQueue.main.async { [weak self] in
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Notify delegate
            self?.delegate?.didScanCode(code)
            
            // Reset processing flag after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.isProcessing = false
            }
        }
    }
}

// MARK: - Preview Provider

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(scannedCode: .constant(nil), isScanning: .constant(true))
            .ignoresSafeArea()
    }
} 