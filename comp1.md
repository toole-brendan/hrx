# Component Associations Feature Design for HandReceipt

## Overview
This feature allows users to associate components (attachments, accessories) with parent items in their property inventory. For example, attaching an ACOG sight to an M4 carbine, or a grip to a pistol.

## Database Schema Updates

### 1. Add Component Associations Table
```sql
-- New table for component associations
CREATE TABLE property_components (
    id SERIAL PRIMARY KEY,
    parent_property_id INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    component_property_id INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    attached_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    attached_by_user_id INTEGER NOT NULL REFERENCES users(id),
    notes TEXT,
    attachment_type VARCHAR(50), -- 'permanent', 'temporary', 'field'
    position VARCHAR(100), -- 'rail_top', 'rail_side', 'barrel', etc.
    
    -- Ensure a component can only be attached to one parent at a time
    UNIQUE(component_property_id),
    
    -- Prevent self-referencing
    CHECK (parent_property_id != component_property_id)
);

-- Add indexes for performance
CREATE INDEX idx_property_components_parent ON property_components(parent_property_id);
CREATE INDEX idx_property_components_component ON property_components(component_property_id);

-- Add component metadata to properties table
ALTER TABLE properties 
ADD COLUMN is_attachable BOOLEAN DEFAULT FALSE,
ADD COLUMN attachment_points JSONB, -- ["rail_top", "rail_side", "barrel"]
ADD COLUMN compatible_with JSONB; -- ["M4", "M16", "AR15"]
```

### 2. Update ImmuDB Ledger Events
```go
// New event types for component tracking
const (
    EventComponentAttached = "COMPONENT_ATTACHED"
    EventComponentDetached = "COMPONENT_DETACHED"
)
```

## Backend Implementation

### 1. Go Models (backend/internal/models/property_components.go)
```go
package models

import (
    "time"
    "encoding/json"
)

type PropertyComponent struct {
    ID                  uint      `json:"id" gorm:"primaryKey"`
    ParentPropertyID    uint      `json:"parent_property_id"`
    ComponentPropertyID uint      `json:"component_property_id"`
    AttachedAt         time.Time `json:"attached_at"`
    AttachedByUserID   uint      `json:"attached_by_user_id"`
    Notes              string    `json:"notes"`
    AttachmentType     string    `json:"attachment_type"`
    Position           string    `json:"position"`
    
    // Relationships
    ParentProperty    Property `json:"parent_property" gorm:"foreignKey:ParentPropertyID"`
    ComponentProperty Property `json:"component_property" gorm:"foreignKey:ComponentPropertyID"`
    AttachedByUser    User     `json:"attached_by_user" gorm:"foreignKey:AttachedByUserID"`
}

type AttachmentPoint struct {
    Position    string   `json:"position"`
    Types       []string `json:"types"`
    MaxItems    int      `json:"max_items"`
    CurrentItem *uint    `json:"current_item,omitempty"`
}

// Extended Property model
type PropertyWithComponents struct {
    Property
    AttachedComponents []PropertyComponent `json:"attached_components,omitempty"`
    AttachedTo         *PropertyComponent  `json:"attached_to,omitempty"`
    AttachmentPoints   []AttachmentPoint   `json:"attachment_points,omitempty"`
}
```

### 2. API Endpoints (backend/internal/api/handlers/component_handler.go)
```go
// GET /api/properties/:id/components - Get all components attached to a property
// POST /api/properties/:id/components - Attach a component
// DELETE /api/properties/:id/components/:componentId - Detach a component
// GET /api/properties/:id/available-components - Get attachable components
// PUT /api/properties/:id/components/:componentId/position - Update component position
```

### 3. Service Layer (backend/internal/services/component_service.go)
```go
type ComponentService interface {
    AttachComponent(ctx context.Context, parentID, componentID uint, userID uint, position string) error
    DetachComponent(ctx context.Context, parentID, componentID uint, userID uint) error
    GetPropertyComponents(ctx context.Context, propertyID uint) ([]PropertyComponent, error)
    GetAvailableComponents(ctx context.Context, propertyID uint, userID uint) ([]Property, error)
    ValidateAttachment(ctx context.Context, parentID, componentID uint, position string) error
}
```

## iOS Implementation

### 1. Swift Models (ios/HandReceipt/Models/PropertyComponent.swift)
```swift
import Foundation

struct PropertyComponent: Codable, Identifiable {
    let id: Int
    let parentPropertyId: Int
    let componentPropertyId: Int
    let attachedAt: Date
    let attachedByUserId: Int
    let notes: String?
    let attachmentType: String?
    let position: String?
    
    // Relationships
    let componentProperty: Property?
    let attachedByUser: User?
}

extension Property {
    var attachedComponents: [PropertyComponent]?
    var attachedTo: PropertyComponent?
    var isAttachable: Bool
    var attachmentPoints: [String]?
    var compatibleWith: [String]?
}
```

### 2. Views (ios/HandReceipt/Views/ComponentManagementView.swift)
```swift
import SwiftUI

struct ComponentManagementView: View {
    @ObservedObject var viewModel: PropertyDetailViewModel
    @State private var showAttachSheet = false
    @State private var selectedPosition: String?
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Attached Components", systemImage: "link")
                    .font(.headline)
                    .foregroundColor(AppColors.primary)
                
                Spacer()
                
                Button(action: { showAttachSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppColors.accent)
                }
                .disabled(!viewModel.canAttachComponents)
            }
            .padding(.horizontal)
            
            if viewModel.attachedComponents.isEmpty {
                EmptyStateView(
                    icon: "link.badge.plus",
                    title: "No Components Attached",
                    description: "Tap + to attach compatible components"
                )
                .padding(.vertical, 40)
            } else {
                ForEach(viewModel.attachedComponents) { component in
                    ComponentRow(component: component) {
                        viewModel.detachComponent(component)
                    }
                }
            }
        }
        .sheet(isPresented: $showAttachSheet) {
            AttachComponentSheet(
                viewModel: viewModel,
                selectedPosition: $selectedPosition
            )
        }
    }
}

struct ComponentRow: View {
    let component: PropertyComponent
    let onDetach: () -> Void
    
    var body: some View {
        HStack {
            // Component icon
            Image(systemName: getIconForCategory(component.componentProperty?.category))
                .foregroundColor(AppColors.primary)
                .frame(width: 40, height: 40)
                .background(AppColors.primaryLight.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(component.componentProperty?.name ?? "Unknown")
                    .font(.headline)
                
                HStack {
                    if let position = component.position {
                        Label(position.replacingOccurrences(of: "_", with: " ").capitalized, 
                              systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let serial = component.componentProperty?.serialNumber {
                        Text("SN: \(serial)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onDetach) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
```

### 3. Enhanced Property Detail View
```swift
// Update PropertyDetailView.swift to include component management
struct PropertyDetailView: View {
    // ... existing code ...
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ... existing sections ...
                
                // Component Management Section
                if property.canHaveComponents {
                    ComponentManagementView(viewModel: viewModel)
                        .padding(.vertical)
                }
            }
        }
    }
}
```

## Web Implementation

### 1. React Components (web/src/components/property/ComponentManager.tsx)
```typescript
import React, { useState } from 'react';
import { useQuery, useMutation } from '@tanstack/react-query';
import { 
  Link2, 
  Unlink, 
  Plus, 
  Search,
  MapPin,
  Package
} from 'lucide-react';

interface ComponentManagerProps {
  propertyId: number;
  canEdit: boolean;
  onUpdate?: () => void;
}

export const ComponentManager: React.FC<ComponentManagerProps> = ({
  propertyId,
  canEdit,
  onUpdate
}) => {
  const [showAttachDialog, setShowAttachDialog] = useState(false);
  const [selectedPosition, setSelectedPosition] = useState<string>('');
  
  const { data: components, refetch } = useQuery({
    queryKey: ['property-components', propertyId],
    queryFn: () => apiService.getPropertyComponents(propertyId)
  });
  
  const attachMutation = useMutation({
    mutationFn: (data: AttachComponentRequest) => 
      apiService.attachComponent(propertyId, data),
    onSuccess: () => {
      refetch();
      onUpdate?.();
      setShowAttachDialog(false);
    }
  });
  
  const detachMutation = useMutation({
    mutationFn: (componentId: number) => 
      apiService.detachComponent(propertyId, componentId),
    onSuccess: () => {
      refetch();
      onUpdate?.();
    }
  });
  
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold flex items-center gap-2">
          <Link2 className="w-5 h-5" />
          Attached Components
        </h3>
        
        {canEdit && (
          <Button
            onClick={() => setShowAttachDialog(true)}
            size="sm"
            variant="outline"
          >
            <Plus className="w-4 h-4 mr-1" />
            Attach Component
          </Button>
        )}
      </div>
      
      {components?.length === 0 ? (
        <div className="text-center py-8 text-gray-500">
          <Package className="w-12 h-12 mx-auto mb-2 opacity-50" />
          <p>No components attached</p>
          {canEdit && (
            <p className="text-sm mt-1">
              Click "Attach Component" to add accessories
            </p>
          )}
        </div>
      ) : (
        <div className="space-y-2">
          {components?.map((component) => (
            <ComponentCard
              key={component.id}
              component={component}
              onDetach={() => detachMutation.mutate(component.componentPropertyId)}
              canDetach={canEdit}
            />
          ))}
        </div>
      )}
      
      {showAttachDialog && (
        <AttachComponentDialog
          propertyId={propertyId}
          onClose={() => setShowAttachDialog(false)}
          onAttach={(componentId, position) => {
            attachMutation.mutate({ componentId, position });
          }}
        />
      )}
    </div>
  );
};

const ComponentCard: React.FC<{
  component: PropertyComponent;
  onDetach: () => void;
  canDetach: boolean;
}> = ({ component, onDetach, canDetach }) => {
  return (
    <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
      <div className="w-10 h-10 bg-primary/10 rounded-lg flex items-center justify-center">
        <Package className="w-5 h-5 text-primary" />
      </div>
      
      <div className="flex-1">
        <p className="font-medium">{component.componentProperty.name}</p>
        <div className="flex items-center gap-3 text-sm text-gray-600">
          {component.position && (
            <span className="flex items-center gap-1">
              <MapPin className="w-3 h-3" />
              {component.position.replace('_', ' ')}
            </span>
          )}
          <span>SN: {component.componentProperty.serialNumber}</span>
        </div>
      </div>
      
      {canDetach && (
        <Button
          onClick={onDetach}
          size="sm"
          variant="ghost"
          className="text-red-600 hover:text-red-700"
        >
          <Unlink className="w-4 h-4" />
        </Button>
      )}
    </div>
  );
};
```

### 2. Updated Property Book View
```typescript
// Add component column to PropertyBookTable.tsx
const columns = [
  // ... existing columns ...
  {
    header: "Components",
    accessorKey: "attached_components",
    cell: ({ row }) => {
      const components = row.original.attached_components || [];
      if (components.length === 0) return "-";
      
      return (
        <div className="flex items-center gap-1">
          <Link2 className="w-4 h-4" />
          <span>{components.length}</span>
        </div>
      );
    }
  }
];
```

### 3. My Properties View Enhancement
```typescript
// Update MyPropertiesView.tsx to show component relationships
const PropertyCard: React.FC<PropertyCardProps> = ({ property }) => {
  return (
    <Card className="hover:shadow-lg transition-shadow">
      <CardContent className="p-4">
        {/* ... existing content ... */}
        
        {/* Component indicators */}
        {property.attached_components?.length > 0 && (
          <div className="mt-3 pt-3 border-t">
            <p className="text-sm text-gray-600">
              {property.attached_components.length} component{property.attached_components.length > 1 ? 's' : ''} attached
            </p>
            <div className="flex flex-wrap gap-1 mt-1">
              {property.attached_components.slice(0, 3).map((comp, idx) => (
                <Badge key={idx} variant="secondary" className="text-xs">
                  {comp.componentProperty.name}
                </Badge>
              ))}
              {property.attached_components.length > 3 && (
                <Badge variant="secondary" className="text-xs">
                  +{property.attached_components.length - 3} more
                </Badge>
              )}
            </div>
          </div>
        )}
        
        {property.attached_to && (
          <div className="mt-3 pt-3 border-t">
            <p className="text-sm text-gray-600">
              Attached to: <span className="font-medium">{property.attached_to.parentProperty.name}</span>
            </p>
          </div>
        )}
      </CardContent>
    </Card>
  );
};
```

## Transfer Logic Updates

### 1. Component Transfer Rules
- When a parent item is transferred, all attached components should transfer with it by default
- User can optionally detach components before transfer
- Components cannot be transferred independently if attached
- Transfer preview shows all components that will transfer

### 2. Backend Transfer Service Update
```go
func (s *TransferService) CreateTransfer(ctx context.Context, req TransferRequest) (*Transfer, error) {
    // ... existing validation ...
    
    // Check if property has attached components
    components, err := s.componentService.GetPropertyComponents(ctx, req.PropertyID)
    if err != nil {
        return nil, err
    }
    
    // If transferring with components, validate all components belong to sender
    if req.IncludeComponents {
        for _, comp := range components {
            if comp.ComponentProperty.OwnerID != req.FromUserID {
                return nil, errors.New("cannot transfer components not owned by sender")
            }
        }
    } else if len(components) > 0 {
        // Detach all components if not including in transfer
        for _, comp := range components {
            if err := s.componentService.DetachComponent(ctx, req.PropertyID, comp.ComponentPropertyID, req.FromUserID); err != nil {
                return nil, err
            }
        }
    }
    
    // ... continue with transfer ...
}
```

## Search and Filter Enhancements

### 1. Component-aware Search
```sql
-- Add search capabilities for components
CREATE INDEX idx_properties_attachable ON properties(is_attachable) WHERE is_attachable = true;
CREATE INDEX idx_properties_compatible ON properties USING gin(compatible_with);

-- Search query example
SELECT DISTINCT p.* 
FROM properties p
LEFT JOIN property_components pc ON p.id = pc.parent_property_id
WHERE p.owner_id = $1
  AND (
    p.name ILIKE $2 
    OR p.serial_number ILIKE $2
    OR EXISTS (
      SELECT 1 FROM property_components pc2
      JOIN properties p2 ON pc2.component_property_id = p2.id
      WHERE pc2.parent_property_id = p.id
        AND p2.name ILIKE $2
    )
  );
```

### 2. Filter Options
- Filter by: Has components, Is component, Specific attachment type
- Sort by: Number of components attached

## UI/UX Considerations

### Visual Hierarchy
1. **Property Card**: Show component count badge
2. **Property Detail**: Dedicated component section with visual attachment diagram
3. **Transfer Flow**: Clear indication of what components will transfer

### Mobile Optimization
- Swipe actions for quick component detachment
- Drag-and-drop for component attachment on iPad
- Compact component list view for phones

### Accessibility
- Clear labels for screen readers
- Keyboard navigation for component management
- High contrast mode support for attachment indicators

## Security Considerations

1. **Permission Checks**
   - Only property owner can attach/detach components
   - Components must be owned by same user as parent
   - Audit all attachment/detachment actions

2. **Data Validation**
   - Validate attachment compatibility
   - Prevent circular references
   - Ensure component is not already attached

3. **Immutable Audit Trail**
   - Log all component associations to ImmuDB
   - Track who attached/detached and when
   - Maintain complete history of component relationships