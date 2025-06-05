import SwiftUI

struct DA2062ReviewSheet: View {
    let form: DA2062Form?
    let scannedPages: [DA2062DocumentScannerViewModel.ScannedPage]
    let onConfirm: ([DA2062PropertyRequest]) -> Void
    
    @State private var editableItems: [EditableDA2062Item] = []
    @State private var selectedPageIndex = 0
    @State private var showingPagePreview = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showingImportProgress = false
    @StateObject private var scanViewModel = DA2062ScanViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: "REVIEW ITEMS",
                titleStyle: .mono,
                showBackButton: false,
                trailingItems: [
                    .init(text: "Cancel", style: .text, action: { 
                        presentationMode.wrappedValue.dismiss() 
                    }),
                    .init(text: "Add Item", style: .text, action: addNewItem)
                ]
            )
            
            // Page thumbnail strip
            if !scannedPages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(scannedPages.indices, id: \.self) { index in
                            PageThumbnail(
                                page: scannedPages[index],
                                isSelected: selectedPageIndex == index
                            ) {
                                selectedPageIndex = index
                                showingPagePreview = true
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 80)
                .background(AppColors.tertiaryBackground)
            }
            
            // Form header info
            if let form = form {
                VStack(alignment: .leading, spacing: 8) {
                    if let unitName = form.unitName {
                        HStack {
                            Text("Unit:")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                            Text(unitName)
                                .font(AppFonts.bodyMedium)
                                .foregroundColor(AppColors.primaryText)
                        }
                    }
                    
                    if let dodaac = form.dodaac {
                        HStack {
                            Text("DODAAC:")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                            Text(dodaac)
                                .font(AppFonts.monoBody)
                                .foregroundColor(AppColors.primaryText)
                        }
                    }
                    
                    HStack {
                        Text("Items found:")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        Text("\(editableItems.count)")
                            .font(AppFonts.monoBody)
                            .foregroundColor(AppColors.primaryText)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.secondaryBackground)
                .overlay(
                    Rectangle()
                        .fill(AppColors.divider)
                        .frame(height: 1),
                    alignment: .bottom
                )
            }
            
            // Items list
            List {
                ForEach($editableItems) { $item in
                    DA2062ItemRowWithVerification(item: $item)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(PlainListStyle())
            .background(AppColors.appBackground)
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(MinimalSecondaryButtonStyle())
                
                Button("Import Items") {
                    Task {
                        await importItemsToBackend()
                    }
                }
                .buttonStyle(MinimalPrimaryButtonStyle())
                .disabled(isImporting || !editableItems.contains { $0.isValid && $0.isSelected })
            }
            .padding(20)
            .background(AppColors.secondaryBackground)
            .overlay(
                Rectangle()
                    .fill(AppColors.divider)
                    .frame(height: 1),
                alignment: .top
            )
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showingPagePreview) {
            PagePreviewView(
                page: scannedPages[selectedPageIndex],
                onDismiss: { showingPagePreview = false }
            )
        }
        .sheet(isPresented: $showingImportProgress) {
            DA2062ImportProgressView(sourceImage: scannedPages.first?.image ?? UIImage())
        }
        .onAppear {
            loadEditableItems()
        }
    }
    
    // MARK: - Azure OCR Import Methods
    
    private func importItemsToBackend() async {
        isImporting = true
        importError = nil
        showingImportProgress = true
        
        scanViewModel.currentForm = form
        
        let result = await scanViewModel.importVerifiedItems(editableItems)
        
        switch result {
        case .success(let response):
            print("Successfully imported \(response.createdCount) items")
            isImporting = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showingImportProgress = false
                presentationMode.wrappedValue.dismiss()
            }
            
        case .failure(let error):
            importError = error.localizedDescription
            isImporting = false
        }
    }
    
    private func loadEditableItems() {
        guard let form = form else { return }
        
        editableItems = form.items.map { item in
            EditableDA2062Item(from: item)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        editableItems.remove(atOffsets: offsets)
    }
    
    private func addNewItem() {
        let newItem = EditableDA2062Item(
            description: "",
            nsn: "",
            quantity: "1",
            serialNumber: "",
            unit: "EA",
            confidence: 1.0,
            quantityConfidence: 1.0,
            hasExplicitSerial: false
        )
        editableItems.append(newItem)
    }
}

// MARK: - Enhanced row for editing individual items with verification indicators
struct DA2062ItemRowWithVerification: View {
    @Binding var item: EditableDA2062Item
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row content with selection toggle
            HStack(spacing: 12) {
                Toggle("", isOn: $item.isSelected)
                    .labelsHidden()
                    .toggleStyle(CheckboxToggleStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.description.isEmpty ? "New Item" : item.description)
                            .font(AppFonts.bodyMedium)
                            .foregroundColor(item.isValid ? AppColors.primaryText : AppColors.destructive)
                        
                        if item.needsVerification {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.warning)
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        ConfidenceIndicator(confidence: item.confidence)
                    }
                    
                    HStack(spacing: 12) {
                        if !item.serialNumber.isEmpty {
                            HStack(spacing: 4) {
                                Label(item.serialNumber, systemImage: "number")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                
                                if !item.hasExplicitSerial {
                                    Text("GEN")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.accent)
                                        .padding(.horizontal, 4)
                                        .background(AppColors.accentMuted)
                                        .cornerRadius(2)
                                }
                            }
                        }
                        
                        if !item.nsn.isEmpty {
                            Label(item.nsn, systemImage: "tag")
                                .font(AppFonts.monoCaption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        HStack(spacing: 4) {
                            Label("Qty: \(item.quantity)", systemImage: "cube.box")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                            
                            if item.quantityConfidence < 0.8 {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(AppColors.warning)
                                    .font(.caption2)
                            }
                        }
                        
                        if let unit = item.unit {
                            Text(unit)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                        }
                    }
                    
                    if Int(item.quantity) ?? 1 > 1 && !item.hasExplicitSerial {
                        Text("Will create \(item.quantity) separate items with generated serial numbers")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.accent)
                            .padding(.top, 2)
                    }
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppColors.secondaryText)
                        .font(.system(size: 14, weight: .light))
                        .frame(width: 20)
                }
            }
            .padding(.vertical, 12)
            
            // Expanded edit fields
            if isExpanded {
                VStack(spacing: 16) {
                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Item Description *")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        TextField("Enter item description", text: $item.description)
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppColors.secondaryBackground)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                    }
                    
                    HStack(spacing: 12) {
                        // NSN
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NSN")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                            TextField("XXXX-XX-XXX-XXXX", text: $item.nsn)
                                .font(AppFonts.monoBody)
                                .foregroundColor(AppColors.primaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppColors.secondaryBackground)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                        }
                        
                        // Quantity
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Qty *")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                
                                if item.quantityConfidence < 0.8 {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundColor(AppColors.warning)
                                        .font(.caption2)
                                }
                            }
                            TextField("1", text: $item.quantity)
                                .font(AppFonts.monoBody)
                                .foregroundColor(AppColors.primaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppColors.secondaryBackground)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                        }
                        
                        // Unit
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Unit")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                            TextField("EA", text: Binding(
                                get: { item.unit ?? "EA" },
                                set: { item.unit = $0 }
                            ))
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppColors.secondaryBackground)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                            .frame(width: 80)
                        }
                    }
                    
                    // Serial Number
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Serial Number")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                            
                            if !item.hasExplicitSerial && !item.serialNumber.isEmpty {
                                Text("(Generated)")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        TextField("Enter serial number or leave blank to auto-generate", text: $item.serialNumber)
                            .font(AppFonts.monoBody)
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppColors.secondaryBackground)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                            .onChange(of: item.serialNumber) { newValue in
                                if !newValue.isEmpty && !item.hasExplicitSerial {
                                    item.hasExplicitSerial = false
                                }
                            }
                    }
                    
                    // Verification reasons if any
                    if item.needsVerification {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Verification Required:")
                                .font(AppFonts.captionMedium)
                                .foregroundColor(AppColors.warning)
                            
                            ForEach(getVerificationReasons(for: item), id: \.self) { reason in
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.caption2)
                                    Text(reason)
                                        .font(AppFonts.caption)
                                }
                                .foregroundColor(AppColors.warning)
                            }
                        }
                        .padding(12)
                        .background(AppColors.warning.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                .padding(.leading, 32)
                .padding(.bottom, 12)
            }
        }
        .cleanCard(padding: 16)
    }
    
    private func getVerificationReasons(for item: EditableDA2062Item) -> [String] {
        var reasons: [String] = []
        
        if item.confidence < 0.7 {
            reasons.append("Low OCR confidence (\(Int(item.confidence * 100))%)")
        }
        
        if !item.hasExplicitSerial && !item.serialNumber.isEmpty {
            reasons.append("Serial number will be auto-generated")
        }
        
        if item.quantityConfidence < 0.8 && Int(item.quantity) ?? 1 > 1 {
            reasons.append("Quantity field had low confidence")
        }
        
        if item.nsn.isEmpty {
            reasons.append("No NSN detected")
        }
        
        return reasons
    }
}

// Confidence indicator component
struct ConfidenceIndicator: View {
    let confidence: Double
    
    var color: Color {
        switch confidence {
        case 0.8...1.0:
            return AppColors.success
        case 0.6..<0.8:
            return AppColors.warning
        default:
            return AppColors.destructive
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.shield")
                .font(.caption)
            Text("\(Int(confidence * 100))%")
                .font(AppFonts.caption)
        }
        .foregroundColor(color)
    }
}

// Checkbox toggle style for item selection
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? AppColors.accent : AppColors.tertiaryText)
                    .font(.system(size: 18))
                configuration.label
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Page thumbnail component
struct PageThumbnail: View {
    let page: DA2062DocumentScannerViewModel.ScannedPage
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Image(uiImage: page.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 65)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
                )
            
            Text("Page \(page.pageNumber)")
                .font(AppFonts.caption)
                .foregroundColor(isSelected ? AppColors.accent : AppColors.secondaryText)
            
            Text("\(Int(page.confidence * 100))%")
                .font(.caption2)
                .foregroundColor(AppColors.tertiaryText)
        }
        .onTapGesture(perform: onTap)
    }
}

// Page preview view
struct PagePreviewView: View {
    let page: DA2062DocumentScannerViewModel.ScannedPage
    let onDismiss: () -> Void
    @State private var showingTextOverlay = false
    
    var body: some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: "PAGE \(page.pageNumber)",
                titleStyle: .mono,
                showBackButton: false,
                trailingItems: [
                    .init(text: "Done", style: .text, action: onDismiss),
                    .init(text: showingTextOverlay ? "Hide Text" : "Show Text", style: .text, action: {
                        showingTextOverlay.toggle()
                    })
                ]
            )
            
            ScrollView {
                ZStack(alignment: .topLeading) {
                    Image(uiImage: page.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(20)
                    
                    if showingTextOverlay {
                        // Optional: Show text overlay with bounding boxes
                    }
                }
            }
            .background(AppColors.appBackground)
        }
        .navigationBarHidden(true)
    }
} 