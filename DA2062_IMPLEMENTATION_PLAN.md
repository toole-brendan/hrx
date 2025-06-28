# DA 2062 Implementation Plan

## Overview
This plan addresses data schema alignment, UX improvements, and proper DA 2062 form support across the HandReceipt application.

## Progress Update - June 28, 2025

### ✅ Completed Tasks:

1. **Drizzle Schema Synchronization**
   - Updated `sql/schema.ts` to include all DA2062 fields
   - Added reference tables: `unitOfIssueCodes`, `propertyCategories`, `propertyConditionHistory`

2. **Backend Go Models**
   - Updated `domain.Property` model with DA2062 fields
   - Added reference models for new tables
   - Created TableName methods for proper GORM mapping

3. **API Endpoints**
   - Created handlers for unit of issue codes and property categories
   - Added routes: `/api/reference/unit-of-issue` and `/api/reference/categories`
   - Implemented repository methods in PostgresRepository

4. **Frontend TypeScript Updates**
   - Updated `Property` interface with DA2062 fields
   - Removed deprecated fields (position, calibration, components)
   - Added reference data interfaces
   - Created `referenceDataService.ts` for fetching reference data

### 🔄 In Progress:
- None - All tasks completed!

### ✅ Additional Completed Tasks:

5. **Frontend UX Improvements**
   - Created enhanced DA2062ImportDialog with unit of issue and condition selectors
   - Added bulk actions (Apply All AI Suggestions, Auto-Detect Categories, Set All Conditions)
   - Implemented multi-file upload support
   - Added camera capture option for mobile devices
   - Created reference data service for dropdowns

6. **Duplicate Detection**
   - Created duplicateDetectionService.ts
   - Client-side duplicate checking with serial number and NSN matching
   - Levenshtein distance algorithm for fuzzy matching
   - Resolution options: skip, update existing, or create anyway

### 📦 New Files Created:
- `/web/src/services/referenceDataService.ts`
- `/web/src/components/da2062/DA2062ImportDialogEnhanced.tsx`
- `/web/src/services/duplicateDetectionService.ts`

## Phase 1: Database Schema Updates

### 1.1 Add Required DA 2062 Fields to Properties Table

```sql
-- Migration: 028_add_da2062_fields.sql
ALTER TABLE properties 
ADD COLUMN unit_of_issue VARCHAR(10) DEFAULT 'EA',
ADD COLUMN condition_code VARCHAR(10) DEFAULT 'A',
ADD COLUMN category VARCHAR(50),
ADD COLUMN manufacturer VARCHAR(100),
ADD COLUMN part_number VARCHAR(50),
ADD COLUMN security_classification VARCHAR(10) DEFAULT 'U';

-- Add indexes for common queries
CREATE INDEX idx_properties_category ON properties(category);
CREATE INDEX idx_properties_condition ON properties(condition_code);
```

### 1.2 Create Condition History Table

```sql
-- Track condition changes over time
CREATE TABLE property_condition_history (
    id SERIAL PRIMARY KEY,
    property_id INTEGER NOT NULL REFERENCES properties(id),
    condition_code VARCHAR(10) NOT NULL,
    changed_by INTEGER REFERENCES users(id),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason TEXT,
    notes TEXT
);
```

### 1.3 Create Unit of Issue Reference Table

```sql
-- Standard unit of issue codes
CREATE TABLE unit_of_issue_codes (
    code VARCHAR(10) PRIMARY KEY,
    description VARCHAR(100) NOT NULL,
    category VARCHAR(50)
);

-- Populate with standard military codes
INSERT INTO unit_of_issue_codes (code, description, category) VALUES
('EA', 'Each', 'General'),
('PR', 'Pair', 'General'),
('DZ', 'Dozen', 'General'),
('HD', 'Hundred', 'General'),
('TH', 'Thousand', 'General'),
('GAL', 'Gallon', 'Liquid'),
('QT', 'Quart', 'Liquid'),
('PT', 'Pint', 'Liquid'),
('LTR', 'Liter', 'Liquid'),
('LB', 'Pound', 'Weight'),
('OZ', 'Ounce', 'Weight'),
('KG', 'Kilogram', 'Weight'),
('FT', 'Feet', 'Length'),
('YD', 'Yard', 'Length'),
('M', 'Meter', 'Length'),
('RD', 'Round', 'Ammunition'),
('BX', 'Box', 'Container'),
('CN', 'Can', 'Container'),
('PG', 'Package', 'Container'),
('RL', 'Roll', 'Material');
```

## Phase 2: Backend Updates

### 2.1 Update Property Model

```go
// backend/internal/domain/models.go
type Property struct {
    // Existing fields...
    
    // DA 2062 Required Fields
    UnitOfIssue           string  `json:"unit_of_issue" gorm:"type:varchar(10);default:'EA'"`
    ConditionCode         string  `json:"condition_code" gorm:"type:varchar(10);default:'A'"`
    Category              string  `json:"category" gorm:"type:varchar(50)"`
    Manufacturer          string  `json:"manufacturer" gorm:"type:varchar(100)"`
    PartNumber            string  `json:"part_number" gorm:"type:varchar(50)"`
    SecurityClassification string  `json:"security_classification" gorm:"type:varchar(10);default:'U'"`
}
```

### 2.2 Update Import Metadata Structure

```go
// backend/internal/models/import.go
type ImportMetadata struct {
    // Existing fields...
    
    // DA 2062 extracted fields
    ExtractedUnitOfIssue string `json:"extracted_unit_of_issue,omitempty"`
    ExtractedCondition   string `json:"extracted_condition,omitempty"`
    ExtractedCategory    string `json:"extracted_category,omitempty"`
}
```

### 2.3 Update DA 2062 Handler

- Modify `BatchCreateInventory` to accept and store new fields
- Update import logic to extract U/I and condition from forms
- Remove guessing functions, use actual stored values

## Phase 3: Frontend Updates

### 3.1 Remove Unnecessary Fields

Remove from `web/src/types/index.ts`:
```typescript
// REMOVE these fields - not needed for DA 2062
- position?: LatLngExpression;  // Map position
- requiresCalibration?: boolean;
- calibrationInfo?: CalibrationInfo;
- components?: Component[];      // Move to separate component tracking
- isComponent?: boolean;
- parentItemId?: string;
```

### 3.2 Update Property Interface

```typescript
// web/src/types/property.ts
export interface Property {
  id: string;
  name: string;
  description?: string;
  serialNumber: string;
  nsn?: string;
  lin?: string;
  category: PropertyCategory;
  location: string;
  status: PropertyStatus;
  
  // DA 2062 specific fields
  unitOfIssue: UnitOfIssue;
  conditionCode: ConditionCode;
  manufacturer?: string;
  partNumber?: string;
  securityClassification: SecurityClass;
  
  // Assignment and tracking
  assignedTo?: string;
  assignedDate?: string;
  lastInventoryDate?: string;
  acquisitionDate?: string;
  value?: number;
  quantity: number;
  
  // Metadata
  isSensitive?: boolean;
  updatedAt?: string;
  createdAt?: string;
}

export enum UnitOfIssue {
  EA = 'EA',
  PR = 'PR',
  GAL = 'GAL',
  LB = 'LB',
  FT = 'FT',
  // ... etc
}

export enum ConditionCode {
  A = 'A', // Serviceable
  B = 'B', // Unserviceable (Repairable)
  C = 'C', // Unserviceable (Condemned)
}

export enum SecurityClass {
  U = 'U',      // Unclassified
  FOUO = 'FOUO', // For Official Use Only
  C = 'C',      // Confidential
  S = 'S',      // Secret
}
```

## Phase 4: UX Improvements

### 4.1 Import Dialog Enhancements

#### Add Unit of Issue Selection
```typescript
// In DA2062ImportDialog.tsx review step
<Select
  value={item.unitOfIssue}
  onChange={(value) => updateItemField(item.id, 'unitOfIssue', value)}
>
  <option value="EA">Each (EA)</option>
  <option value="PR">Pair (PR)</option>
  <option value="GAL">Gallon (GAL)</option>
  {/* Load from backend reference table */}
</Select>
```

#### Add Condition Code Selection
```typescript
<Select
  value={item.conditionCode}
  onChange={(value) => updateItemField(item.id, 'conditionCode', value)}
>
  <option value="A">Serviceable (A)</option>
  <option value="B">Unserviceable - Repairable (B)</option>
  <option value="C">Unserviceable - Condemned (C)</option>
</Select>
```

#### Smart Category Detection
```typescript
// Auto-detect category based on item name/NSN
const detectCategory = (item: EditableDA2062Item): PropertyCategory => {
  const name = item.name.toLowerCase();
  if (name.includes('m4') || name.includes('m16') || name.includes('pistol')) {
    return PropertyCategory.Weapon;
  }
  if (name.includes('radio') || name.includes('antenna')) {
    return PropertyCategory.Comms;
  }
  // ... etc
  return PropertyCategory.Other;
};
```

### 4.2 Multi-Page Upload Support

```typescript
// New component: MultiPageUpload.tsx
interface MultiPageUploadProps {
  onFilesSelected: (files: File[]) => void;
  maxFiles?: number;
}

export const MultiPageUpload: React.FC<MultiPageUploadProps> = ({
  onFilesSelected,
  maxFiles = 10
}) => {
  const [files, setFiles] = useState<File[]>([]);
  
  return (
    <div>
      <DropZone 
        multiple
        maxFiles={maxFiles}
        accept="image/*,application/pdf"
        onDrop={handleDrop}
      />
      <FileList>
        {files.map((file, index) => (
          <FileItem key={index}>
            <Thumbnail src={URL.createObjectURL(file)} />
            <FileName>{file.name}</FileName>
            <RemoveButton onClick={() => removeFile(index)} />
          </FileItem>
        ))}
      </FileList>
      <ReorderHint>Drag to reorder pages</ReorderHint>
    </div>
  );
};
```

### 4.3 Bulk Actions in Review

```typescript
// Add to review step
<BulkActions>
  <Button onClick={applyAllSuggestions}>
    <Sparkles className="h-4 w-4 mr-2" />
    Apply All AI Suggestions
  </Button>
  <Button onClick={setAllConditionsServiceable}>
    Set All to Serviceable
  </Button>
  <Button onClick={autoDetectCategories}>
    Auto-Detect Categories
  </Button>
</BulkActions>
```

### 4.4 Import Preview & Duplicate Detection

```typescript
interface ImportPreview {
  newItems: number;
  duplicates: DuplicateItem[];
  warnings: ImportWarning[];
}

interface DuplicateItem {
  importItem: EditableDA2062Item;
  existingItem: Property;
  matchType: 'serial' | 'nsn_and_name';
}

// Show before final import
<ImportPreviewDialog>
  <Summary>
    <Stat label="New Items" value={preview.newItems} />
    <Stat label="Duplicates Found" value={preview.duplicates.length} />
  </Summary>
  
  {preview.duplicates.length > 0 && (
    <DuplicatesList>
      {preview.duplicates.map(dup => (
        <DuplicateItem>
          <ExistingInfo>{dup.existingItem.name}</ExistingInfo>
          <Actions>
            <Button onClick={() => skipItem(dup)}>Skip</Button>
            <Button onClick={() => updateExisting(dup)}>Update</Button>
            <Button onClick={() => createAnyway(dup)}>Create Anyway</Button>
          </Actions>
        </DuplicateItem>
      ))}
    </DuplicatesList>
  )}
</ImportPreviewDialog>
```

### 4.5 Enhanced Error Recovery

```typescript
// If import partially fails
interface PartialImportResult {
  succeeded: ImportedItem[];
  failed: FailedItem[];
  canRetry: boolean;
}

<PartialImportDialog result={partialResult}>
  <SuccessSection>
    <CheckCircle className="h-5 w-5 text-green-500" />
    {result.succeeded.length} items imported successfully
  </SuccessSection>
  
  <FailureSection>
    <AlertCircle className="h-5 w-5 text-red-500" />
    {result.failed.length} items failed
    
    <FailedItemsList>
      {result.failed.map(item => (
        <FailedItem key={item.id}>
          <ItemName>{item.name}</ItemName>
          <ErrorReason>{item.error}</ErrorReason>
          <FixButton onClick={() => openFixDialog(item)}>
            Fix & Retry
          </FixButton>
        </FailedItem>
      ))}
    </FailedItemsList>
  </FailureSection>
  
  <Actions>
    <Button onClick={downloadFailedAsCSV}>
      Download Failed Items CSV
    </Button>
    <Button onClick={retryAllFailed} disabled={!result.canRetry}>
      Retry All Failed
    </Button>
  </Actions>
</PartialImportDialog>
```

### 4.6 Mobile-Optimized Camera Capture

```typescript
// Add camera capture option
<CameraCapture>
  <input
    type="file"
    accept="image/*"
    capture="environment"
    onChange={handleCameraCapture}
    className="hidden"
    ref={cameraInputRef}
  />
  <Button
    onClick={() => cameraInputRef.current?.click()}
    className="w-full"
  >
    <Camera className="h-4 w-4 mr-2" />
    Take Photo of DA 2062
  </Button>
</CameraCapture>
```

## Phase 5: API Updates

### 5.1 Update Batch Import Endpoint

```go
// Accept new fields in batch import
type DA2062ImportItem struct {
    // Existing fields...
    UnitOfIssue    string `json:"unit_of_issue"`
    ConditionCode  string `json:"condition_code"`
    Category       string `json:"category"`
    Manufacturer   string `json:"manufacturer"`
}
```

### 5.2 Add Reference Data Endpoints

```go
// GET /api/reference/unit-of-issue
func GetUnitOfIssueCodes(c *gin.Context) {
    // Return all U/I codes with descriptions
}

// GET /api/reference/categories
func GetPropertyCategories(c *gin.Context) {
    // Return standard property categories
}
```

## Phase 6: Claude AI Enhancement

### 6.1 Update AI Parsing Prompt

```go
// In claude_da2062_service.go
prompt := `Extract items including:
- Unit of Issue (EA, PR, GAL, etc.)
- Condition code if visible (A, B, C)
- Category (weapon, vehicle, comms, etc.)
- Manufacturer if listed`
```

### 6.2 Add Smart Suggestions

```go
// Suggest U/I based on item type
func SuggestUnitOfIssue(itemName string) string {
    // Use AI or rule-based logic
}
```

## Phase 7: Testing Plan

### 7.1 Migration Testing
- Backup database before migration
- Test migration on dev environment
- Verify no data loss
- Test rollback procedure

### 7.2 Import/Export Testing
- Test import with new fields
- Verify DA 2062 generation uses stored values
- Test multi-page import
- Test duplicate detection

### 7.3 UX Testing
- Mobile camera capture
- Bulk actions performance
- Error recovery flows
- Keyboard navigation

## Phase 8: Deployment

### 8.1 Deployment Order
1. Database migration (with rollback plan)
2. Backend API deployment
3. Frontend deployment
4. Update mobile apps

### 8.2 Feature Flags
```typescript
// Enable features progressively
const FEATURES = {
  multiPageUpload: process.env.REACT_APP_ENABLE_MULTI_PAGE === 'true',
  smartCategoryDetection: true,
  bulkActions: true,
  cameraCapture: isMobile(),
};
```

## Phase 9: Documentation

### 9.1 Update API Documentation
- Document new fields
- Update import/export examples
- Add U/I reference guide

### 9.2 User Training
- Create guide for new import features
- Document U/I and condition codes
- Add tooltips in UI

## Timeline

- **Week 1**: Database changes and backend updates
- **Week 2**: Frontend updates and basic UX improvements
- **Week 3**: Advanced UX features (multi-page, bulk actions)
- **Week 4**: Testing and bug fixes
- **Week 5**: Deployment and monitoring

## Rollback Plan

1. Database: Keep migration rollback script ready
2. API: Use blue-green deployment
3. Frontend: Keep previous version available
4. Have hotfix procedure documented

## Success Metrics

- Import accuracy > 95%
- DA 2062 generation requires < 5% manual edits
- Import time reduced by 50%
- User satisfaction score > 4.5/5