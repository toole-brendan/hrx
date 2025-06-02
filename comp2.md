// ComponentManagementView.swift
// Complete iOS implementation for component attachment UI

import SwiftUI

// MARK: - Main Component Management View
struct ComponentManagementView: View {
    @ObservedObject var viewModel: PropertyDetailViewModel
    @State private var showAttachSheet = false
    @State private var selectedPosition: String?
    @State private var showDetachConfirmation = false
    @State private var componentToDetach: PropertyComponent?
    
    var property: Property { viewModel.property }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header Section
            ComponentHeaderView(
                componentCount: viewModel.attachedComponents.count,
                showAttachSheet: $showAttachSheet,
                canAttach: viewModel.canAttachComponents
            )
            
            // Visual Attachment Diagram (for weapons/equipment with positions)
            if let attachmentPoints = property.attachmentPoints, !attachmentPoints.isEmpty {
                AttachmentDiagramView(
                    category: property.category,
                    attachmentPoints: attachmentPoints,
                    attachedComponents: viewModel.attachedComponents
                )
                .padding(.horizontal)
            }
            
            // Component List
            if viewModel.attachedComponents.isEmpty {
                EmptyComponentsView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.attachedComponents) { component in
                            ComponentRowView(
                                component: component,
                                onDetach: {
                                    componentToDetach = component
                                    showDetachConfirmation = true
                                },
                                onPositionChange: { newPosition in
                                    viewModel.updateComponentPosition(component, position: newPosition)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showAttachSheet) {
            AttachComponentSheet(viewModel: viewModel)
        }
        .alert("Detach Component?", isPresented: $showDetachConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Detach", role: .destructive) {
                if let component = componentToDetach {
                    viewModel.detachComponent(component)
                }
            }
        } message: {
            Text("Are you sure you want to detach \(componentToDetach?.componentProperty?.name ?? "this component")?")
        }
    }
}

// MARK: - Header View
struct ComponentHeaderView: View {
    let componentCount: Int
    @Binding var showAttachSheet: Bool
    let canAttach: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Attached Components", systemImage: "link.circle.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.text)
                
                Text("\(componentCount) component\(componentCount == 1 ? "" : "s") attached")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            Button(action: { showAttachSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(canAttach ? AppColors.accent : Color.gray)
            }
            .disabled(!canAttach)
        }
        .padding(.horizontal)
    }
}

// MARK: - Visual Attachment Diagram
struct AttachmentDiagramView: View {
    let category: String
    let attachmentPoints: [String]
    let attachedComponents: [PropertyComponent]
    
    var body: some View {
        ZStack {
            // Base item silhouette
            ItemSilhouetteView(category: category)
                .frame(height: 150)
            
            // Attachment point indicators
            ForEach(attachmentPoints, id: \.self) { point in
                AttachmentPointIndicator(
                    position: point,
                    isOccupied: attachedComponents.contains { $0.position == point },
                    component: attachedComponents.first { $0.position == point }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(AppColors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Item Silhouette View
struct ItemSilhouetteView: View {
    let category: String
    
    var silhouetteImage: String {
        switch category.lowercased() {
        case "weapons": return "rifle_silhouette"
        case "optics": return "scope_silhouette"
        case "equipment": return "gear_silhouette"
        default: return "generic_item"
        }
    }
    
    var body: some View {
        Image(silhouetteImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(Color.gray.opacity(0.3))
    }
}

// MARK: - Attachment Point Indicator
struct AttachmentPointIndicator: View {
    let position: String
    let isOccupied: Bool
    let component: PropertyComponent?
    
    var offset: CGSize {
        switch position {
        case "rail_top": return CGSize(width: 0, height: -60)
        case "rail_side": return CGSize(width: 80, height: 0)
        case "barrel": return CGSize(width: -100, height: 0)
        case "grip": return CGSize(width: 0, height: 60)
        case "stock": return CGSize(width: 120, height: 0)
        default: return .zero
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isOccupied ? AppColors.success : AppColors.primaryLight)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: isOccupied ? "checkmark" : "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                )
            
            if let componentName = component?.componentProperty?.name {
                Text(componentName)
                    .font(.caption2)
                    .foregroundColor(AppColors.text)
                    .lineLimit(1)
                    .frame(maxWidth: 80)
            } else {
                Text(position.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .offset(offset)
    }
}

// MARK: - Component Row View
struct ComponentRowView: View {
    let component: PropertyComponent
    let onDetach: () -> Void
    let onPositionChange: (String) -> Void
    
    @State private var showPositionMenu = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Component Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.primaryLight.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: iconForCategory(component.componentProperty?.category))
                    .font(.title3)
                    .foregroundColor(AppColors.primary)
            }
            
            // Component Details
            VStack(alignment: .leading, spacing: 6) {
                Text(component.componentProperty?.name ?? "Unknown Component")
                    .font(.headline)
                    .foregroundColor(AppColors.text)
                
                HStack(spacing: 12) {
                    // Position Badge
                    if let position = component.position {
                        Button(action: { showPositionMenu = true }) {
                            Label(
                                position.replacingOccurrences(of: "_", with: " ").capitalized,
                                systemImage: "location.fill"
                            )
                            .font(.caption)
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.accent.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    
                    // Serial Number
                    if let serial = component.componentProperty?.serialNumber {
                        Text("SN: \(serial)")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                // Attachment Info
                if let attachedBy = component.attachedByUser?.displayName,
                   let date = component.attachedAt {
                    Text("Attached by \(attachedBy) • \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            Spacer()
            
            // Actions
            Menu {
                if showPositionMenu {
                    ForEach(availablePositions(), id: \.self) { position in
                        Button(action: { onPositionChange(position) }) {
                            Label(
                                position.replacingOccurrences(of: "_", with: " ").capitalized,
                                systemImage: "location"
                            )
                        }
                    }
                    Divider()
                }
                
                Button(role: .destructive, action: onDetach) {
                    Label("Detach Component", systemImage: "minus.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
    }
    
    func availablePositions() -> [String] {
        // This would be populated from the parent property's attachment points
        ["rail_top", "rail_side", "barrel", "grip", "stock"]
    }
    
    func iconForCategory(_ category: String?) -> String {
        switch category?.lowercased() {
        case "optics": return "scope"
        case "grips": return "hand.raised.fill"
        case "lights": return "flashlight.on.fill"
        case "suppressors": return "speaker.slash.fill"
        default: return "cube.fill"
        }
    }
}

// MARK: - Empty Components View
struct EmptyComponentsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(AppColors.primaryLight)
            
            Text("No Components Attached")
                .font(.headline)
                .foregroundColor(AppColors.text)
            
            Text("Tap the + button to attach compatible accessories and components")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Attach Component Sheet
struct AttachComponentSheet: View {
    @ObservedObject var viewModel: PropertyDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var selectedComponent: Property?
    @State private var selectedPosition = ""
    @State private var notes = ""
    @State private var isLoading = false
    
    let categories = ["All", "Optics", "Grips", "Lights", "Suppressors", "Other"]
    
    var filteredComponents: [Property] {
        viewModel.availableComponents.filter { component in
            let matchesSearch = searchText.isEmpty || 
                component.name.localizedCaseInsensitiveContains(searchText) ||
                component.serialNumber.localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedCategory == "All" || 
                component.category.localizedCaseInsensitiveContains(selectedCategory)
            
            return matchesSearch && matchesCategory
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textSecondary)
                    
                    TextField("Search components...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(AppColors.inputBackground)
                .cornerRadius(10)
                .padding()
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryChip(
                                title: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                
                // Component List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredComponents) { component in
                            AvailableComponentRow(
                                component: component,
                                isSelected: selectedComponent?.id == component.id,
                                onTap: { selectedComponent = component }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Selected Component & Position
                if let selected = selectedComponent {
                    VStack(spacing: 16) {
                        Divider()
                        
                        // Selected Component Info
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.success)
                            
                            VStack(alignment: .leading) {
                                Text(selected.name)
                                    .font(.headline)
                                Text("SN: \(selected.serialNumber)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Position Selection
                        if let attachmentPoints = viewModel.property.attachmentPoints {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Attachment Position")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(attachmentPoints, id: \.self) { position in
                                            PositionChip(
                                                position: position,
                                                isSelected: selectedPosition == position,
                                                isOccupied: viewModel.isPositionOccupied(position),
                                                onTap: {
                                                    if !viewModel.isPositionOccupied(position) {
                                                        selectedPosition = position
                                                    }
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Notes Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (Optional)")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            
                            TextField("Add notes about this attachment...", text: $notes, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(AppColors.inputBackground)
                                .cornerRadius(8)
                                .lineLimit(2...4)
                        }
                        .padding(.horizontal)
                        
                        // Attach Button
                        Button(action: attachComponent) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Attach Component")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedPosition.isEmpty ? Color.gray : AppColors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(selectedPosition.isEmpty || isLoading)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle("Attach Component")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    func attachComponent() {
        guard let component = selectedComponent else { return }
        
        isLoading = true
        viewModel.attachComponent(
            componentId: component.id,
            position: selectedPosition,
            notes: notes
        ) { success in
            isLoading = false
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Supporting Views
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(isSelected ? .white : AppColors.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.accent : AppColors.chipBackground)
                .cornerRadius(20)
        }
    }
}

struct PositionChip: View {
    let position: String
    let isSelected: Bool
    let isOccupied: Bool
    let onTap: () -> Void
    
    var displayName: String {
        position.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if isOccupied {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
                Text(displayName)
                    .font(.subheadline)
            }
            .foregroundColor(isOccupied ? .white : (isSelected ? .white : AppColors.text))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isOccupied ? Color.red :
                (isSelected ? AppColors.accent : AppColors.chipBackground)
            )
            .cornerRadius(20)
            .opacity(isOccupied ? 0.6 : 1.0)
        }
        .disabled(isOccupied)
    }
}

struct AvailableComponentRow: View {
    let component: Property
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Component Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? AppColors.accent.opacity(0.1) : AppColors.primaryLight.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "cube.fill")
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.primary)
                }
                
                // Component Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(component.name)
                        .font(.headline)
                        .foregroundColor(AppColors.text)
                    
                    HStack(spacing: 8) {
                        Text("SN: \(component.serialNumber)")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        if let compatible = component.compatibleWith, !compatible.isEmpty {
                            Text("• Compatible")
                                .font(.caption)
                                .foregroundColor(AppColors.success)
                        }
                    }
                }
                
                Spacer()
                
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textTertiary)
            }
            .padding()
            .background(isSelected ? AppColors.accent.opacity(0.05) : AppColors.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}