import SwiftUI
import AVFoundation
import Vision // Import Vision framework

struct CameraView: UIViewControllerRepresentable {
    @Binding var scannedCode: String? // To hold scanned barcode/OCR result
    @Binding var isScanning: Bool // To control the session

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        if isScanning {
            uiViewController.startSession()
        } else {
            uiViewController.stopSession()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CameraViewControllerDelegate {
        var parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func didScanCode(code: String) {
            parent.scannedCode = code
            parent.isScanning = false // Stop scanning after finding a code
            print("Coordinator: Scanned Code - \(code)") // Debugging
        }

        func didFail(error: Error) {
            print("Coordinator: Camera Error - \(error.localizedDescription)")
            // Handle error appropriately (e.g., show alert)
            parent.isScanning = false
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func didScanCode(code: String)
    func didFail(error: Error)
}

class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var metadataOutput: AVCaptureMetadataOutput!
    var videoDataOutput: AVCaptureVideoDataOutput!
    weak var delegate: CameraViewControllerDelegate?
    private let sessionQueue = DispatchQueue(label: "session queue")
    private var isSessionRunning = false
    
    // Debounce properties for OCR
    private var lastFrameTime = Date(timeIntervalSince1970: 0)
    private let debounceInterval: TimeInterval = 1.0 // 1 second

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraPermissions()
    }

    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
            setupCaptureSession()
        case .notDetermined: // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCaptureSession()
                    }
                } else {
                    self?.delegate?.didFail(error: CameraError.permissionDenied)
                }
            }
        default: // The user has previously denied access.
            delegate?.didFail(error: CameraError.permissionDenied)
        }
    }

    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession = AVCaptureSession()
            self.captureSession.beginConfiguration()

            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
                DispatchQueue.main.async {
                    self.delegate?.didFail(error: CameraError.noDeviceFound)
                }
                self.captureSession.commitConfiguration()
                return
            }
            let videoInput: AVCaptureDeviceInput

            do {
                videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.didFail(error: error)
                }
                self.captureSession.commitConfiguration()
                return
            }

            if (self.captureSession.canAddInput(videoInput)) {
                self.captureSession.addInput(videoInput)
            } else {
                DispatchQueue.main.async {
                    self.delegate?.didFail(error: CameraError.cannotAddInput)
                }
                self.captureSession.commitConfiguration()
                return
            }

            // --- Setup Metadata Output (Barcodes/QR Codes) ---
            self.metadataOutput = AVCaptureMetadataOutput()
            if (self.captureSession.canAddOutput(self.metadataOutput)) {
                self.captureSession.addOutput(self.metadataOutput)
                self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                // Configure for common barcode types (add more as needed)
                self.metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417, .code128, .code39, .code93, .upce, .aztec, .dataMatrix]
            } else {
                print("Could not add metadata output")
                // Optionally fail or continue without barcode scanning
            }

            // --- Setup Video Data Output (for OCR) ---
            self.videoDataOutput = AVCaptureVideoDataOutput()
            if (self.captureSession.canAddOutput(self.videoDataOutput)) {
                self.captureSession.addOutput(self.videoDataOutput)
                self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video data queue"))
                self.videoDataOutput.alwaysDiscardsLateVideoFrames = true // Recommended
                // Configure video settings if necessary (e.g., pixel format)
            } else {
                print("Could not add video data output")
                // Optionally fail or continue without OCR
            }

            self.captureSession.commitConfiguration()

            // Setup Preview Layer on Main Thread
            DispatchQueue.main.async {
                self.setupPreviewLayer()
                if !self.isSessionRunning {
                   self.startSession() // Start if configured successfully
                }
            }
        }
    }

    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.isSessionRunning, self.captureSession != nil, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            self.isSessionRunning = true
            print("Camera Session Started")
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isSessionRunning, self.captureSession != nil, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            self.isSessionRunning = false
            print("Camera Session Stopped")
        }
    }

    // AVCaptureMetadataOutputObjectsDelegate (Barcode/QR)
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Debounce slightly to avoid processing barcode and OCR from nearly the same moment
        guard Date().timeIntervalSince(lastFrameTime) > 0.2 else { return }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            lastFrameTime = Date() // Update timestamp after successful scan
            delegate?.didScanCode(code: stringValue) // Barcode takes precedence
        }
    }

    // AVCaptureVideoDataOutputSampleBufferDelegate (OCR)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentTime = Date()
        guard currentTime.timeIntervalSince(lastFrameTime) >= debounceInterval else {
            // print("Debounced frame") // Can be noisy
            return // Debounce
        }
        lastFrameTime = currentTime // Update time even if processing fails

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:]) // Assuming back camera landscape right

        let request = VNRecognizeTextRequest { [weak self] (request, error) in
            // Ensure processing happens off the main thread initially, delegate call will dispatch to main if needed
            guard let self = self else { return }

            if let error = error {
                print("OCR Error: \(error.localizedDescription)")
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                return
            }

            // Improved Text Processing:
            let recognizedStrings = observations.compactMap { observation in
                // Consider confidence thresholds: observation.confidence > 0.5
                observation.topCandidates(1).first?.string
            }
            
            let combinedText = recognizedStrings.joined().trimmingCharacters(in: .whitespacesAndNewlines)
             // Filter for alphanumeric and check length
            let potentialSN = combinedText.filter { $0.isLetter || $0.isNumber }

            if potentialSN.count > 4 { // Minimum length check
                print("Filtered OCR Result: \(potentialSN)")
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                // Still call didScanCode, but maybe add a parameter later to differentiate?
                DispatchQueue.main.async { // Ensure delegate call is on main thread
                    self.delegate?.didScanCode(code: potentialSN)
                }
            } else if !combinedText.isEmpty {
                 print("OCR Recognized but ignored (short/non-alphanumeric): \(combinedText)")
            }
        }
        
        // Configure the request (optional)
        request.recognitionLevel = .fast // Prioritize speed for live scanning
        // request.usesLanguageCorrection = false // Usually not needed for SNs

        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform text recognition request: \(error)")
        }
    }

    enum CameraError: Error {
        case permissionDenied
        case noDeviceFound
        case cannotAddInput
        case cannotAddOutput
    }
} 