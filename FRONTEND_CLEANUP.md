# Frontend Cleanup Guide

## Fields to Remove from Frontend

### 1. Remove from `web/src/types/index.ts`

These fields are not needed for DA 2062 form generation and add unnecessary complexity:

```typescript
// REMOVE these fields from Property interface:
- position?: LatLngExpression;      // Map coordinates - not on DA 2062
- requiresCalibration?: boolean;     // Calibration tracking - separate concern
- calibrationInfo?: CalibrationInfo; // Calibration details - separate concern
- components?: Component[];          // Component relationships - use backend table
- isComponent?: boolean;             // Component flag - use backend relationship
- parentItemId?: string;             // Parent reference - use backend relationship
```

### 2. Remove Related Types

Remove these type definitions that are no longer needed:

```typescript
// REMOVE from types/index.ts:
- export interface CalibrationInfo { ... }
- export interface Component { ... }
- export type LatLngExpression = ...
```

### 3. Update Property Forms

Remove UI elements for these fields from:

- `web/src/components/forms/PropertyForm.tsx`
- `web/src/components/property/PropertyEditDialog.tsx`
- `web/src/pages/PropertyDetail.tsx`

### 4. Clean Up Map Integration

Since we're removing position tracking:

- Remove map display from property details
- Remove location picker from property forms
- Keep only text-based location field (building/room)

### 5. Component Management

Move component relationships to a separate feature:

- Create dedicated "Components" section if needed
- Use backend `property_components` table
- Don't mix with main property data

## Fields to Keep/Add

### Essential DA 2062 Fields:

```typescript
export interface Property {
  // Identification
  id: string;
  name: string;
  description?: string;
  serialNumber: string;
  nsn?: string;
  lin?: string;
  
  // DA 2062 Required
  unitOfIssue: string;        // NEW: EA, PR, GAL, etc.
  conditionCode: string;      // NEW: A, B, C
  category: string;           // KEEP: Already exists
  securityClass?: string;     // NEW: U, FOUO, C, S
  
  // Additional Info
  manufacturer?: string;      // NEW: For descriptions
  partNumber?: string;       // NEW: For technical items
  location: string;          // KEEP: Building/room only
  
  // Status & Assignment
  status: PropertyStatus;     // KEEP: Operational status
  assignedTo?: string;       // KEEP: User assignment
  assignedDate?: string;     // KEEP: Assignment date
  
  // Tracking
  quantity: number;          // KEEP: Required for DA 2062
  value?: number;           // KEEP: Unit price
  acquisitionDate?: string;  // KEEP: Purchase date
  lastInventoryDate?: string; // KEEP: Last verified
  
  // Flags
  isSensitive?: boolean;     // KEEP: Maps to security
  
  // Metadata
  createdAt?: string;
  updatedAt?: string;
}
```

## Migration Steps

1. **Update TypeScript Types** (Week 1)
   - Remove unused interfaces
   - Add new DA 2062 fields
   - Update type exports

2. **Update Forms** (Week 1)
   - Remove UI for deleted fields
   - Add dropdowns for new fields
   - Update validation rules

3. **Update API Calls** (Week 2)
   - Remove deleted fields from payloads
   - Add new fields to requests
   - Update response handling

4. **Update Display Components** (Week 2)
   - Remove map displays
   - Remove calibration sections
   - Add new field displays

5. **Testing** (Week 3)
   - Test all CRUD operations
   - Verify DA 2062 generation
   - Check mobile responsiveness

## Benefits of Cleanup

1. **Simpler Data Model**: Focus on DA 2062 requirements
2. **Better Performance**: Less data to transfer/store
3. **Clearer Purpose**: Property tracking for hand receipts
4. **Easier Maintenance**: Fewer fields to validate/display

## Backwards Compatibility

For existing deployments with data in removed fields:

1. **Backend Migration**: Keep columns but stop using them
2. **Export Option**: Provide CSV export of old data
3. **Archive Table**: Move old data to archive table
4. **Grace Period**: Show read-only old data for 90 days

## Component Tracking Alternative

If component tracking is needed, implement separately:

```typescript
// Separate component management
interface ComponentRelationship {
  id: string;
  parentPropertyId: string;
  childPropertyId: string;
  attachmentPoint?: string;
  attachedDate: string;
  attachedBy: string;
}

// Use dedicated API endpoints
GET  /api/properties/:id/components
POST /api/properties/:id/attach-component
DELETE /api/properties/:id/detach-component
```

This keeps the main Property model focused on DA 2062 requirements while allowing optional component tracking through a separate feature.