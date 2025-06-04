import SwiftUI
import VisionKit

struct DA2062ScanView: View {
    @StateObject private var scannerViewModel = DA2062DocumentScannerViewModel()
    @StateObject private var da2062ViewModel = DA2062ScanViewModel()
    @State private var showingScanner = false
    @State private var showingProcessingView = false
    @State private var showingReviewSheet = false
    @State private var scannerAvailable = VNDocumentCameraViewController.isSupported
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom navigation bar
                MinimalNavigationBar(
                    title: "Import DA 2062",
                    titleStyle: .mono,
                    showBackButton: false,
                    trailingItems: [
                        .init(text: "Cancel", style: .text, action: { dismiss() })
                    ]
                )
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Scan Your Form")
                                .font(AppFonts.serifTitle)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("Digitize your DA-2062 form to quickly import property records")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Scanner Availability Warning
                        if !scannerAvailable {
                            MinimalWarningCard(
                                message: "Document scanner not available on this device"
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Main Scan Button
                        Button(action: { showingScanner = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 20, weight: .light))
                                Text("Scan DA-2062 Form")
                                    .font(AppFonts.bodyMedium)
                            }
                        }
                        .buttonStyle(.minimalPrimary)
                        .disabled(!scannerAvailable)
                        .padding(.horizontal, 20)
                        
                        // Features Section
                        VStack(spacing: 16) {
                            ElegantSectionHeader(
                                title: "Scanner Features",
                                style: .uppercase
                            )
                            
                            VStack(spacing: 12) {
                                MinimalFeatureRow(icon: "doc.on.doc", text: "Multi-page scanning support")
                                MinimalFeatureRow(icon: "viewfinder.rectangular", text: "Automatic edge detection")
                                MinimalFeatureRow(icon: "perspective", text: "Perspective correction")
                                MinimalFeatureRow(icon: "text.viewfinder", text: "Enhanced OCR accuracy")
                            }
                            .cleanCard(padding: 16)
                        }
                        .padding(.horizontal, 20)
                        
                        // Recent Scans Section
                        if !da2062ViewModel.recentScans.isEmpty {
                            VStack(spacing: 16) {
                                ElegantSectionHeader(
                                    title: "Recent Scans",
                                    subtitle: "\(da2062ViewModel.recentScans.count) saved",
                                    style: .uppercase
                                )
                                
                                VStack(spacing: 8) {
                                    ForEach(da2062ViewModel.recentScans) { scan in
                                        MinimalRecentScanRow(scan: scan) {
                                            da2062ViewModel.selectScan(scan)
                                            showingReviewSheet = true
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Bottom padding
                        Color.clear.frame(height: 20)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingScanner) {
            VisionDocumentScanner(
                onCompletion: { images in
                    showingScanner = false
                    showingProcessingView = true
                    scannerViewModel.processScannedDocuments(images)
                },
                onCancel: {
                    showingScanner = false
                }
            )
        }
        .sheet(isPresented: $showingProcessingView) {
            MinimalProcessingView(
                viewModel: scannerViewModel,
                da2062ViewModel: da2062ViewModel
            ) {
                // Processing complete
                showingProcessingView = false
                
                Task {
                    let result = await da2062ViewModel.uploadScannedFormToAzure(
                        pages: scannerViewModel.scannedPages
                    )
                    
                    switch result {
                    case .success:
                        showingReviewSheet = true
                    case .failure(let error):
                        print("Azure OCR failed: \(error)")
                        
                        // Fallback to on-device OCR
                        if da2062ViewModel.useAzureOCR {
                            print("Falling back to on-device OCR...")
                            da2062ViewModel.processExtractedText(
                                scannerViewModel.extractedText,
                                pages: scannerViewModel.scannedPages.map { $0.image },
                                confidence: scannerViewModel.ocrConfidence
                            ) { fallbackResult in
                                switch fallbackResult {
                                case .success:
                                    showingReviewSheet = true
                                case .failure(let fallbackError):
                                    print("Fallback OCR also failed: \(fallbackError)")
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingReviewSheet) {
            DA2062ReviewSheet(
                form: da2062ViewModel.currentForm,
                scannedPages: scannerViewModel.scannedPages,
                onConfirm: { items in
                    showingReviewSheet = false
                }
            )
        }
    }
}

// MARK: - Minimal Processing View
struct MinimalProcessingView: View {
    @ObservedObject var viewModel: DA2062DocumentScannerViewModel
    @ObservedObject var da2062ViewModel: DA2062ScanViewModel
    let onComplete: () -> Void
    
    var progress: Double {
        da2062ViewModel.isProcessing ? da2062ViewModel.processingProgress : viewModel.processingProgress
    }
    
    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                MinimalNavigationBar(
                    title: "Processing",
                    titleStyle: .mono,
                    showBackButton: false
                )
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Minimal Progress Indicator
                    ZStack {
                        Circle()
                            .stroke(AppColors.border, lineWidth: 2)
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(AppColors.primaryText, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: progress)
                        
                        Text("\(Int(progress * 100))%")
                            .font(AppFonts.monoHeadline)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    VStack(spacing: 16) {
                        Text("PROCESSING DOCUMENT")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .kerning(AppFonts.ultraWideKerning)
                        
                        Text(da2062ViewModel.processingMessage.isEmpty ? 
                             "Extracting text from \(viewModel.scannedPages.count) pages" : 
                             da2062ViewModel.processingMessage)
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                        
                        if da2062ViewModel.isProcessing && !da2062ViewModel.processingMethod.isEmpty {
                            Text(da2062ViewModel.processingMethod.uppercased())
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.accent)
                                .kerning(AppFonts.wideKerning)
                        }
                        
                        if progress == 1.0 {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(AppColors.success)
                                Text("COMPLETE")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.success)
                                    .kerning(AppFonts.wideKerning)
                            }
                        }
                        
                        // OCR Method Info
                        HStack(spacing: 8) {
                            Image(systemName: da2062ViewModel.useAzureOCR ? "cloud" : "cpu")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(AppColors.accent)
                            Text(da2062ViewModel.useAzureOCR ? 
                                 "Using cloud OCR for best accuracy" : 
                                 "Using on-device recognition")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.accentMuted)
                        .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    if progress == 1.0 {
                        Button("Continue") {
                            onComplete()
                        }
                        .buttonStyle(.minimalPrimary)
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Supporting Views

struct MinimalFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundColor(AppColors.accent)
                .frame(width: 24)
            Text(text)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
            Spacer()
        }
    }
}

struct MinimalWarningCard: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(AppColors.warning)
            Text(message)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.warning.opacity(0.1))
        .cornerRadius(4)
    }
}

struct MinimalRecentScanRow: View {
    let scan: DA2062Scan
    let onTap: () -> Void
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Date icon
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(AppColors.tertiaryText)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(dateFormatter.string(from: scan.date))
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(AppColors.primaryText)
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text("\(scan.pageCount)")
                                .font(AppFonts.monoCaption)
                                .foregroundColor(AppColors.secondaryText)
                            Text("PAGES")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.tertiaryText)
                                .kerning(AppFonts.wideKerning)
                        }
                        
                        HStack(spacing: 4) {
                            Text("\(scan.itemCount)")
                                .font(AppFonts.monoCaption)
                                .foregroundColor(AppColors.secondaryText)
                            Text("ITEMS")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.tertiaryText)
                                .kerning(AppFonts.wideKerning)
                        }
                        
                        HStack(spacing: 4) {
                            Text("\(Int(scan.confidence * 100))%")
                                .font(AppFonts.monoCaption)
                                .foregroundColor(AppColors.accent)
                            Text("ACCURACY")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.tertiaryText)
                                .kerning(AppFonts.wideKerning)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding(12)
            .background(AppColors.secondaryBackground)
            .cornerRadius(4)
            .shadow(color: AppColors.shadowColor, radius: 2, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

 