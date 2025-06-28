# UX Improvements Specification

## Priority 1: Import Dialog Enhancements

### 1. Unit of Issue & Condition Selection

**Location**: `web/src/components/da2062/DA2062ImportDialog.tsx`

#### Add to Review Step UI:

```tsx
// In the expanded edit form section (around line 643)
<div className="grid grid-cols-3 gap-3">
  <div>
    <Label className="text-xs text-secondary-text">Unit of Issue</Label>
    <Select
      value={item.unitOfIssue || 'EA'}
      onChange={(e) => updateItemField(item.id, 'unitOfIssue', e.target.value)}
      className="mt-1"
    >
      <option value="EA">Each (EA)</option>
      <option value="PR">Pair (PR)</option>
      <option value="GAL">Gallon (GAL)</option>
      <option value="LB">Pound (LB)</option>
      <option value="FT">Feet (FT)</option>
      <option value="RD">Round (RD)</option>
      <option value="BX">Box (BX)</option>
    </Select>
  </div>
  
  <div>
    <Label className="text-xs text-secondary-text">Condition</Label>
    <Select
      value={item.conditionCode || 'A'}
      onChange={(e) => updateItemField(item.id, 'conditionCode', e.target.value)}
      className="mt-1"
    >
      <option value="A">Serviceable (A)</option>
      <option value="B">Repairable (B)</option>
      <option value="C">Condemned (C)</option>
    </Select>
  </div>
  
  <div>
    <Label className="text-xs text-secondary-text">Category</Label>
    <Select
      value={item.category || 'OTHER'}
      onChange={(e) => updateItemField(item.id, 'category', e.target.value)}
      className="mt-1"
    >
      <option value="WEAPON">Weapons</option>
      <option value="VEHICLE">Vehicles</option>
      <option value="COMMS">Communications</option>
      <option value="OPTICS">Optics</option>
      <option value="MEDICAL">Medical</option>
      <option value="OTHER">Other</option>
    </Select>
  </div>
</div>
```

### 2. Bulk Actions Bar

**Add above the items list (around line 495)**:

```tsx
{/* Bulk Actions Bar */}
<div className="bg-gradient-to-r from-blue-50 to-blue-100 rounded-lg p-4 mb-4 shadow-sm">
  <div className="flex items-center justify-between mb-3">
    <h4 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider">
      BULK ACTIONS
    </h4>
    <Badge variant="secondary">
      {selectedCount} items selected
    </Badge>
  </div>
  
  <div className="flex flex-wrap gap-2">
    <Button
      size="sm"
      variant="outline"
      onClick={applyAllSuggestions}
      disabled={!hasAnySuggestions}
      className="text-xs"
    >
      <Sparkles className="h-3 w-3 mr-1" />
      Apply All AI Suggestions
    </Button>
    
    <Button
      size="sm"
      variant="outline"
      onClick={() => setAllSelectedField('conditionCode', 'A')}
      className="text-xs"
    >
      <CheckCircle className="h-3 w-3 mr-1" />
      Mark All Serviceable
    </Button>
    
    <Button
      size="sm"
      variant="outline"
      onClick={autoDetectCategories}
      className="text-xs"
    >
      <Package className="h-3 w-3 mr-1" />
      Auto-Detect Categories
    </Button>
    
    <Button
      size="sm"
      variant="outline"
      onClick={() => setAllSelectedField('unitOfIssue', 'EA')}
      className="text-xs"
    >
      <Edit2 className="h-3 w-3 mr-1" />
      Set All to EA
    </Button>
  </div>
</div>
```

### 3. Multi-File Upload Support

**Replace current file input section (around line 295)**:

```tsx
{/* Multi-file upload area */}
<div className="mb-6">
  <input
    ref={fileInputRef}
    type="file"
    accept="image/*,.pdf"
    onChange={handleFileSelect}
    multiple
    className="hidden"
  />
  
  {selectedFiles.length > 0 ? (
    <div className="space-y-3">
      {selectedFiles.map((file, index) => (
        <div key={index} className="p-4 bg-gradient-to-r from-ios-accent/10 to-ios-accent/5 rounded-lg border border-ios-accent/20">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="relative">
                <div className="p-2.5 bg-white rounded-lg shadow-sm">
                  <FileText className="h-5 w-5 text-ios-accent" />
                </div>
                {selectedFiles.length > 1 && (
                  <div className="absolute -top-1 -right-1 w-5 h-5 bg-blue-500 text-white text-xs rounded-full flex items-center justify-center font-bold">
                    {index + 1}
                  </div>
                )}
              </div>
              <div className="text-left">
                <p className="text-sm font-medium text-ios-primary-text">{file.name}</p>
                <p className="text-xs text-ios-secondary-text font-mono">
                  {(file.size / 1024 / 1024).toFixed(2)} MB
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {/* Reorder buttons */}
              {index > 0 && (
                <button
                  onClick={() => moveFile(index, index - 1)}
                  className="p-1.5 hover:bg-white/50 rounded-lg transition-colors"
                  title="Move up"
                >
                  <ChevronUp className="h-4 w-4 text-ios-tertiary-text" />
                </button>
              )}
              {index < selectedFiles.length - 1 && (
                <button
                  onClick={() => moveFile(index, index + 1)}
                  className="p-1.5 hover:bg-white/50 rounded-lg transition-colors"
                  title="Move down"
                >
                  <ChevronDown className="h-4 w-4 text-ios-tertiary-text" />
                </button>
              )}
              <button
                onClick={() => removeFile(index)}
                className="p-1.5 hover:bg-white/50 rounded-lg transition-colors"
              >
                <X className="h-4 w-4 text-ios-tertiary-text" />
              </button>
            </div>
          </div>
        </div>
      ))}
      
      <div className="text-center">
        <p className="text-xs text-ios-secondary-text mb-2">
          {selectedFiles.length} file{selectedFiles.length > 1 ? 's' : ''} selected • 
          Total size: {(selectedFiles.reduce((sum, f) => sum + f.size, 0) / 1024 / 1024).toFixed(2)} MB
        </p>
        <Button
          onClick={() => fileInputRef.current?.click()}
          variant="outline"
          size="sm"
          className="text-xs"
        >
          <Plus className="h-3 w-3 mr-1" />
          Add More Files
        </Button>
      </div>
    </div>
  ) : (
    <div 
      className="mb-6 p-8 border-2 border-dashed border-ios-border rounded-lg hover:border-ios-accent/30 transition-colors cursor-pointer"
      onClick={() => fileInputRef.current?.click()}
    >
      <div className="text-center">
        <Upload className="h-8 w-8 text-ios-tertiary-text mx-auto mb-3" />
        <p className="text-sm text-ios-secondary-text mb-1">
          Drop your files here, or click to browse
        </p>
        <p className="text-xs text-ios-tertiary-text">
          Multiple files supported • JPG, PNG, or PDF (max 10MB each)
        </p>
      </div>
    </div>
  )}
</div>
```

### 4. Import Preview & Duplicate Detection

**Add new step before importing**:

```tsx
// Add to step types
type Step = 'upload' | 'review' | 'preview' | 'importing';

// Preview step component
const renderPreviewStep = () => {
  const duplicates = checkForDuplicates(editableItems);
  const warnings = validateItems(editableItems);
  
  return (
    <div className="space-y-6">
      {/* Summary Stats */}
      <div className="bg-gradient-to-r from-blue-50 to-green-50 rounded-xl p-6">
        <h3 className="text-lg font-semibold text-ios-primary-text mb-4">Import Summary</h3>
        <div className="grid grid-cols-3 gap-4">
          <div className="text-center">
            <div className="text-2xl font-bold text-green-600">{newItemCount}</div>
            <div className="text-xs text-ios-secondary-text">New Items</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-orange-600">{duplicates.length}</div>
            <div className="text-xs text-ios-secondary-text">Potential Duplicates</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-blue-600">{warnings.length}</div>
            <div className="text-xs text-ios-secondary-text">Warnings</div>
          </div>
        </div>
      </div>
      
      {/* Duplicates Section */}
      {duplicates.length > 0 && (
        <div className="space-y-3">
          <h4 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider">
            DUPLICATE CHECK
          </h4>
          {duplicates.map(dup => (
            <CleanCard key={dup.id} className="p-4 border-orange-200">
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-2">
                    <AlertTriangle className="h-4 w-4 text-orange-500" />
                    <span className="text-sm font-medium">
                      Potential duplicate found
                    </span>
                  </div>
                  <div className="grid grid-cols-2 gap-4 text-sm">
                    <div>
                      <div className="text-xs text-ios-secondary-text">New Item</div>
                      <div>{dup.newItem.name}</div>
                      <div className="text-xs font-mono">{dup.newItem.serialNumber}</div>
                    </div>
                    <div>
                      <div className="text-xs text-ios-secondary-text">Existing Item</div>
                      <div>{dup.existingItem.name}</div>
                      <div className="text-xs font-mono">{dup.existingItem.serialNumber}</div>
                    </div>
                  </div>
                </div>
                <Select
                  value={dup.action}
                  onChange={(e) => setDuplicateAction(dup.id, e.target.value)}
                  className="w-32"
                >
                  <option value="skip">Skip</option>
                  <option value="create">Create Anyway</option>
                  <option value="update">Update Existing</option>
                </Select>
              </div>
            </CleanCard>
          ))}
        </div>
      )}
      
      {/* Warnings Section */}
      {warnings.length > 0 && (
        <div className="space-y-3">
          <h4 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider">
            WARNINGS
          </h4>
          {warnings.map((warning, idx) => (
            <div key={idx} className="flex items-start gap-2 p-3 bg-yellow-50 rounded-lg">
              <AlertCircle className="h-4 w-4 text-yellow-600 mt-0.5" />
              <div className="flex-1">
                <p className="text-sm text-yellow-900">{warning.message}</p>
                <p className="text-xs text-yellow-700 mt-1">
                  Affected items: {warning.items.join(', ')}
                </p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
```

### 5. Mobile Camera Capture

**Add to upload options**:

```tsx
{/* Mobile camera capture option */}
{isMobileDevice() && (
  <div className="mt-3">
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
      className="w-full h-11 bg-green-500 hover:bg-green-600 text-white font-medium"
    >
      <Camera className="h-4 w-4 mr-2" />
      Take Photo of DA 2062
    </Button>
  </div>
)}
```

### 6. Enhanced Error Recovery

**Add to importing step**:

```tsx
// If partial failure occurs
{importError && importResult && (
  <div className="mt-6 space-y-4">
    <Alert variant="warning">
      <AlertCircle className="h-4 w-4" />
      <AlertTitle>Partial Import</AlertTitle>
      <AlertDescription>
        {importResult.succeeded.length} of {importResult.total} items imported successfully
      </AlertDescription>
    </Alert>
    
    {importResult.failed.length > 0 && (
      <div className="space-y-3">
        <h4 className="text-sm font-semibold">Failed Items:</h4>
        {importResult.failed.map((item, idx) => (
          <div key={idx} className="p-3 bg-red-50 rounded-lg">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-sm font-medium text-red-900">{item.name}</p>
                <p className="text-xs text-red-700 mt-1">{item.error}</p>
              </div>
              <Button
                size="sm"
                variant="outline"
                onClick={() => retryItem(item)}
              >
                Retry
              </Button>
            </div>
          </div>
        ))}
        
        <div className="flex gap-2 mt-4">
          <Button
            variant="outline"
            onClick={downloadFailedItemsCSV}
          >
            <Download className="h-4 w-4 mr-2" />
            Download Failed Items
          </Button>
          <Button
            variant="outline"
            onClick={retryAllFailed}
          >
            <RefreshCw className="h-4 w-4 mr-2" />
            Retry All Failed
          </Button>
        </div>
      </div>
    )}
  </div>
)}
```

## Priority 2: Helper Functions

### Add these utility functions:

```typescript
// Smart category detection
export function detectCategory(item: EditableDA2062Item): string {
  const name = item.name.toLowerCase();
  const nsn = item.nsn || '';
  
  // Weapons
  if (/m4|m16|m9|rifle|pistol|carbine|weapon/.test(name)) {
    return 'WEAPON';
  }
  
  // Vehicles
  if (/hmmwv|truck|vehicle|trailer/.test(name)) {
    return 'VEHICLE';
  }
  
  // Communications
  if (/radio|antenna|sincgars|asip|phone/.test(name)) {
    return 'COMMS';
  }
  
  // Optics
  if (/scope|acog|cco|nvg|night vision|binocular/.test(name)) {
    return 'OPTICS';
  }
  
  // Medical
  if (/medical|bandage|tourniquet|ifak|aid/.test(name)) {
    return 'MEDICAL';
  }
  
  // Ammunition
  if (/round|ammo|grenade|magazine/.test(name)) {
    return 'AMMO';
  }
  
  return 'OTHER';
}

// Detect unit of issue
export function detectUnitOfIssue(item: EditableDA2062Item): string {
  const name = item.name.toLowerCase();
  
  if (/round|cartridge|ammo/.test(name)) return 'RD';
  if (/gallon|fuel|oil|coolant/.test(name)) return 'GAL';
  if (/cable|rope|wire|cord/.test(name)) return 'FT';
  if (/glove|boot|shoe/.test(name)) return 'PR';
  
  return 'EA';
}

// Check for duplicates
export async function checkForDuplicates(
  items: EditableDA2062Item[]
): Promise<DuplicateCheck[]> {
  // This would call an API endpoint to check existing inventory
  const response = await fetch('/api/inventory/check-duplicates', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      items: items.map(i => ({
        serialNumber: i.serialNumber,
        nsn: i.nsn,
        name: i.name
      }))
    })
  });
  
  return response.json();
}

// Validate items before import
export function validateItems(items: EditableDA2062Item[]): ImportWarning[] {
  const warnings: ImportWarning[] = [];
  
  // Check for missing categories
  const uncategorized = items.filter(i => !i.category || i.category === 'OTHER');
  if (uncategorized.length > 5) {
    warnings.push({
      type: 'category',
      message: `${uncategorized.length} items have no specific category`,
      items: uncategorized.slice(0, 5).map(i => i.name)
    });
  }
  
  // Check for unusual quantities
  const highQuantity = items.filter(i => parseInt(i.quantity) > 100);
  if (highQuantity.length > 0) {
    warnings.push({
      type: 'quantity',
      message: 'Some items have unusually high quantities',
      items: highQuantity.map(i => `${i.name} (${i.quantity})`)
    });
  }
  
  return warnings;
}
```

## Priority 3: Keyboard Navigation

Add keyboard support to the review step:

```typescript
// Add keyboard event handler
useEffect(() => {
  const handleKeyPress = (e: KeyboardEvent) => {
    if (currentStep !== 'review') return;
    
    switch(e.key) {
      case ' ': // Spacebar
        e.preventDefault();
        if (focusedItemId) {
          toggleItemSelection(focusedItemId);
        }
        break;
      
      case 'Enter':
        e.preventDefault();
        if (focusedItemId) {
          toggleItemExpansion(focusedItemId);
        }
        break;
      
      case 'ArrowDown':
        e.preventDefault();
        moveFocus('down');
        break;
      
      case 'ArrowUp':
        e.preventDefault();
        moveFocus('up');
        break;
      
      case 'a':
        if (e.ctrlKey || e.metaKey) {
          e.preventDefault();
          toggleAllSelection();
        }
        break;
    }
  };
  
  window.addEventListener('keydown', handleKeyPress);
  return () => window.removeEventListener('keydown', handleKeyPress);
}, [currentStep, focusedItemId]);
```

## Implementation Notes

1. **State Management**: Add these to component state:
   ```typescript
   const [selectedFiles, setSelectedFiles] = useState<File[]>([]);
   const [duplicateActions, setDuplicateActions] = useState<Record<string, string>>({});
   const [focusedItemId, setFocusedItemId] = useState<string | null>(null);
   ```

2. **API Endpoints Needed**:
   - `POST /api/inventory/check-duplicates` - Check for existing items
   - `GET /api/reference/unit-of-issue` - Get U/I codes
   - `GET /api/reference/categories` - Get category list

3. **Performance Considerations**:
   - Use React.memo for item components
   - Virtualize list if > 100 items
   - Debounce bulk actions

4. **Mobile Optimizations**:
   - Larger touch targets (min 44x44px)
   - Swipe gestures for item actions
   - Simplified layout on small screens