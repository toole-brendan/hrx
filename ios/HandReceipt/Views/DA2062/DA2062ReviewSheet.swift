import SwiftUI

struct DA2062ReviewSheet: View {
    let form: DA2062Form?
    let scannedPages: [DA2062DocumentScannerViewModel.ScannedPage]
    let onConfirm: ([DA2062PropertyRequest]) -> Void
    
    @State private var editableItems: [EditableDA2062Item] = []
    @State private var selectedPageIndex = 0
    @State private var showingPagePreview = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
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
                        .padding(.horizontal)
                    }
                    .frame(height: 100)
                    .background(Color.gray.opacity(0.1))
                }
                
                // Form header info
                if let form = form {
                    VStack(alignment: .leading, spacing: 8) {
                        if let unitName = form.unitName {
                            HStack {
                                Text("Unit:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(unitName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        if let dodaac = form.dodaac {
                            HStack {
                                Text("DODAAC:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(dodaac)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        HStack {
                            Text("Items found:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(editableItems.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.05))
                }
                
                // Items list
                List {
                    ForEach($editableItems) { $item in
                        DA2062ItemRowWithVerification(item: $item)
                    }
                    .onDelete(perform: deleteItems)
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                    
                    Button("Create Properties") {
                        // Use the enhanced property creation method from view model
                        let viewModel = DA2062ScanViewModel()
                        viewModel.currentForm = form
                        let requests = viewModel.createPropertiesFromParsedItems(editableItems)
                        onConfirm(requests)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(editableItems.contains { $0.isValid } ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(!editableItems.contains { $0.isValid })
                }
                .padding()
            }
            .navigationTitle("Review Scanned Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Item") {
                        addNewItem()
                    }
                }
            }
            .sheet(isPresented: $showingPagePreview) {
                PagePreviewView(
                    page: scannedPages[selectedPageIndex],
                    onDismiss: { showingPagePreview = false }
                )
            }
        }
        .onAppear {
            loadEditableItems()
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

// MARK: - UI Updates for Verification Indicators

// Enhanced row for editing individual items with verification indicators
struct DA2062ItemRowWithVerification: View {
    @Binding var item: EditableDA2062Item
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row content with selection toggle
            HStack {
                Toggle("", isOn: $item.isSelected)
                    .labelsHidden()
                    .toggleStyle(CheckboxToggleStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.description.isEmpty ? "New Item" : item.description)
                            .font(.headline)
                            .foregroundColor(item.isValid ? .primary : .red)
                        
                        if item.needsVerification {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                                .help("Requires verification")
                        }
                        
                        Spacer()
                        
                        ConfidenceIndicator(confidence: item.confidence)
                    }
                    
                    HStack(spacing: 12) {
                        if !item.serialNumber.isEmpty {
                            HStack(spacing: 4) {
                                Label(item.serialNumber, systemImage: "number")
                                    .font(.caption)
                                
                                if !item.hasExplicitSerial {
                                    Text("GEN")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        
                        if !item.nsn.isEmpty {
                            Label(item.nsn, systemImage: "tag")
                                .font(.caption)
                        }
                        
                        HStack(spacing: 4) {
                            Label("Qty: \(item.quantity)", systemImage: "cube.box")
                                .font(.caption)
                            
                            if item.quantityConfidence < 0.8 {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.orange)
                                    .font(.caption2)
                            }
                        }
                        
                        if let unit = item.unit {
                            Text(unit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.secondary)
                    
                    if Int(item.quantity) ?? 1 > 1 && !item.hasExplicitSerial {
                        Text("Will create \(item.quantity) separate items with generated serial numbers")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.top, 2)
                    }
                }
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }
            
            // Expanded edit fields
            if isExpanded {
                VStack(spacing: 12) {
                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Item Description *")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter item description", text: $item.description)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack(spacing: 12) {
                        // NSN
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NSN")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("XXXX-XX-XXX-XXXX", text: $item.nsn)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Quantity
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Qty *")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if item.quantityConfidence < 0.8 {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundColor(.orange)
                                        .font(.caption2)
                                        .help("Low confidence in quantity detection")
                                }
                            }
                            TextField("1", text: $item.quantity)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                        }
                        
                        // Unit
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unit")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("EA", text: Binding(
                                get: { item.unit ?? "EA" },
                                set: { item.unit = $0 }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60)
                        }
                    }
                    
                    // Serial Number
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Serial Number")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if !item.hasExplicitSerial && !item.serialNumber.isEmpty {
                                Text("(Generated)")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        TextField("Enter serial number or leave blank to auto-generate", text: $item.serialNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: item.serialNumber) { newValue in
                                // If user enters a serial, mark it as manual
                                if !newValue.isEmpty && !item.hasExplicitSerial {
                                    item.hasExplicitSerial = false // Keep as generated unless explicitly found
                                }
                            }
                    }
                    
                    // Verification reasons if any
                    if item.needsVerification {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Verification Required:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            
                            ForEach(getVerificationReasons(for: item), id: \.self) { reason in
                                HStack {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.caption2)
                                    Text(reason)
                                        .font(.caption2)
                                }
                                .foregroundColor(.orange)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 8)
                .padding(.leading, 28) // Align with toggle
            }
        }
        .padding(.vertical, 8)
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
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.shield")
                .font(.caption)
            Text("\(Int(confidence * 100))%")
                .font(.caption2)
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
                    .foregroundColor(configuration.isOn ? .blue : .gray)
                    .font(.system(size: 20))
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
                .frame(width: 60, height: 80)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.blue : Color.gray, lineWidth: 2)
                )
            
            Text("Page \(page.pageNumber)")
                .font(.caption2)
                .foregroundColor(isSelected ? .blue : .secondary)
            
            Text("\(Int(page.confidence * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
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
        NavigationView {
            ScrollView {
                ZStack(alignment: .topLeading) {
                    Image(uiImage: page.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                    
                    // Optional: Show text overlay with bounding boxes
                    if showingTextOverlay {
                        // This would show the recognized text regions
                        // Implementation depends on your needs
                    }
                }
            }
            .navigationTitle("Page \(page.pageNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done", action: onDismiss)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(showingTextOverlay ? "Hide Text" : "Show Text") {
                        showingTextOverlay.toggle()
                    }
                }
            }
        }
    }
} 