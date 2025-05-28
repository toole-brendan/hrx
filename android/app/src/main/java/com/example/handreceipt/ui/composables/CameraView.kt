package com.example.handreceipt.ui.composables

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import java.util.concurrent.Executors
import androidx.camera.core.ImageProxy
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.util.concurrent.TimeUnit

// Debounce mechanism to avoid processing too rapidly
private var lastAnalyzedTimestamp = 0L
private const val DEBOUNCE_INTERVAL_MS = 1000 // Process once per second

@androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
@Composable
fun CameraView(
    modifier: Modifier = Modifier,
    onBarcodeScanned: (String) -> Unit,
    onTextRecognized: (String) -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var hasCameraPermission by remember { mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    val cameraExecutor = remember { Executors.newSingleThreadExecutor() }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
        onResult = { granted ->
            hasCameraPermission = granted
        }
    )

    LaunchedEffect(key1 = true) {
        if (!hasCameraPermission) {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        if (hasCameraPermission) {
            AndroidView(
                factory = { ctx ->
                    val previewView = PreviewView(ctx)
                    val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
                    cameraProviderFuture.addListener({
                        val cameraProvider = cameraProviderFuture.get()
                        val preview = Preview.Builder().build().also {
                            it.setSurfaceProvider(previewView.surfaceProvider)
                        }
                        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

                        // --- ML Kit Setup ---
                        val barcodeOptions = BarcodeScannerOptions.Builder()
                            .setBarcodeFormats(
                                Barcode.FORMAT_QR_CODE,
                                Barcode.FORMAT_CODE_128,
                                Barcode.FORMAT_CODE_39,
                                Barcode.FORMAT_EAN_13,
                                Barcode.FORMAT_EAN_8,
                                Barcode.FORMAT_UPC_A,
                                Barcode.FORMAT_UPC_E,
                                Barcode.FORMAT_DATA_MATRIX,
                                Barcode.FORMAT_AZTEC
                            )
                            .build()
                        val barcodeScanner = BarcodeScanning.getClient(barcodeOptions)
                        val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

                        // --- Image Analyzer --- 
                        val imageAnalyzer = ImageAnalysis.Builder()
                            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                            .build()
                            .also {
                                it.setAnalyzer(cameraExecutor) { imageProxy ->
                                    val currentTime = System.currentTimeMillis()
                                    if (currentTime - lastAnalyzedTimestamp >= DEBOUNCE_INTERVAL_MS) {
                                        lastAnalyzedTimestamp = currentTime
                                        val mediaImage = imageProxy.image
                                        if (mediaImage != null) {
                                            val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

                                            // 1. Try Barcode Scanning
                                            barcodeScanner.process(image)
                                                .addOnSuccessListener { barcodes ->
                                                    if (barcodes.isNotEmpty()) {
                                                        // Prioritize barcode if found
                                                        val code = barcodes.first().rawValue
                                                        if (code != null) {
                                                            Log.d("CameraView", "Barcode Success: $code")
                                                            onBarcodeScanned(code)
                                                            // Potentially stop analysis here if barcode is sufficient
                                                        }
                                                    } else {
                                                        // 2. If no barcode, try Text Recognition
                                                        textRecognizer.process(image)
                                                            .addOnSuccessListener { visionText ->
                                                                // Improve text processing: Filter for likely serial numbers
                                                                val combinedText = visionText.textBlocks.joinToString(" ") { block ->
                                                                     block.lines.joinToString(" ") { line ->
                                                                         line.text
                                                                     }
                                                                 }.replace("\n", " ").trim()
                                                                
                                                                // Basic Filtering: Check if it looks somewhat like a serial number
                                                                val potentialSN = combinedText.filter { it.isLetterOrDigit() } // Keep only letters/digits
                                                                
                                                                if (potentialSN.length > 4) { // Require a minimum length
                                                                    Log.d("CameraView", "Filtered Text Success: $potentialSN")
                                                                    onTextRecognized(potentialSN)
                                                                } else if (combinedText.isNotBlank()) {
                                                                     Log.d("CameraView", "Text Recognized but ignored (short/non-alphanumeric): $combinedText")
                                                                } else {
                                                                     Log.d("CameraView", "Text Recognition: No text found")
                                                                }
                                                            }
                                                            .addOnFailureListener { e ->
                                                                Log.e("CameraView", "Text recognition failed", e)
                                                            }
                                                    }
                                                }
                                                .addOnFailureListener { e ->
                                                    Log.e("CameraView", "Barcode scanning failed", e)
                                                    // Don't stop, maybe text recognition will work
                                                }
                                                .addOnCompleteListener {
                                                    imageProxy.close() // Ensure imageProxy is closed!
                                                }
                                        } else {
                                            imageProxy.close() // Close if mediaImage is null
                                        }
                                    } else {
                                         imageProxy.close() // Close if debounced
                                    }
                                }
                            }

                        try {
                            cameraProvider.unbindAll()
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                cameraSelector,
                                preview,
                                imageAnalyzer // Add analyzer here
                            )
                        } catch (exc: Exception) {
                            Log.e("CameraView", "Use case binding failed", exc)
                        }
                    }, ContextCompat.getMainExecutor(ctx))
                    previewView
                },
                modifier = Modifier.fillMaxSize()
            )
        } else {
            Text("Camera permission required", modifier = Modifier.align(Alignment.Center))
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            cameraExecutor.shutdown()
        }
    }
} 