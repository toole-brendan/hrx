import React, { useState, useCallback, useRef } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '../ui/dialog';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { Checkbox } from '../ui/checkbox';
import { useToast } from '@/hooks/use-toast';
import { 
  Upload, 
  FileText, 
  Loader2, 
  CheckCircle, 
  AlertTriangle,
  ChevronDown,
  ChevronRight,
  Edit2,
  X,
  FileImage,
  Package
} from 'lucide-react';

// iOS Components
import { CleanCard, ElegantSectionHeader, StatusBadge, MinimalLoadingView } from '@/components/ios';

// Services
import { 
  uploadDA2062, 
  batchImportItems, 
  generateSerialNumber,
  getConfidenceColor,
  getConfidenceLabel,
  formatNSN,
  DA2062Form,
  EditableDA2062Item,
  BatchImportItem,
  UploadProgress
} from '@/services/da2062Service';

interface DA2062ImportDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onImportComplete?: (importedCount: number) => void;
}

export const DA2062ImportDialog: React.FC<DA2062ImportDialogProps> = ({
  isOpen,
  onClose,
  onImportComplete
}) => {
  const [currentStep, setCurrentStep] = useState<'upload' | 'review' | 'importing'>('upload');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<UploadProgress | null>(null);
  const [parsedForm, setParsedForm] = useState<DA2062Form | null>(null);
  const [editableItems, setEditableItems] = useState<EditableDA2062Item[]>([]);
  const [expandedItems, setExpandedItems] = useState<Set<string>>(new Set());
  const [isImporting, setIsImporting] = useState(false);
  
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { toast } = useToast();

  // Reset state when dialog closes
  const handleClose = useCallback(() => {
    setCurrentStep('upload');
    setSelectedFile(null);
    setIsProcessing(false);
    setUploadProgress(null);
    setParsedForm(null);
    setEditableItems([]);
    setExpandedItems(new Set());
    setIsImporting(false);
    onClose();
  }, [onClose]);

  // Handle file selection
  const handleFileSelect = useCallback((event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      // Validate file type
      const validTypes = ['image/jpeg', 'image/png', 'image/jpg', 'application/pdf'];
      if (!validTypes.includes(file.type)) {
        toast({
          title: 'Invalid file type',
          description: 'Please upload a JPG, PNG, or PDF file',
          variant: 'destructive',
        });
        return;
      }
      
      // Validate file size (max 10MB)
      if (file.size > 10 * 1024 * 1024) {
        toast({
          title: 'File too large',
          description: 'Please upload a file smaller than 10MB',
          variant: 'destructive',
        });
        return;
      }
      
      setSelectedFile(file);
    }
  }, [toast]);

  // Process the uploaded file
  const processFile = useCallback(async () => {
    if (!selectedFile) return;
    
    setIsProcessing(true);
    try {
      const result = await uploadDA2062(selectedFile, setUploadProgress);
      setParsedForm(result);
      
      // Convert to editable items
      const editable: EditableDA2062Item[] = result.items.map((item, index) => ({
        ...item,
        id: `item-${index}`,
        description: item.itemDescription,
        nsn: item.stockNumber || '',
        quantity: item.quantity.toString(),
        serialNumber: item.serialNumber || generateSerialNumber(item.itemDescription, index + 1),
        unit: item.unitOfIssue,
        isSelected: true,
        needsVerification: item.confidence < 0.7 || !item.hasExplicitSerial || item.quantityConfidence < 0.7
      }));
      
      setEditableItems(editable);
      setCurrentStep('review');
      
      toast({
        title: 'Document processed',
        description: `Found ${result.items.length} items to import`,
      });
    } catch (error) {
      toast({
        title: 'Processing failed',
        description: error instanceof Error ? error.message : 'Failed to process document',
        variant: 'destructive',
      });
      setUploadProgress(null);
    } finally {
      setIsProcessing(false);
    }
  }, [selectedFile, toast]);

  // Toggle item expansion
  const toggleItemExpansion = useCallback((itemId: string) => {
    setExpandedItems(prev => {
      const newSet = new Set(prev);
      if (newSet.has(itemId)) {
        newSet.delete(itemId);
      } else {
        newSet.add(itemId);
      }
      return newSet;
    });
  }, []);

  // Update item field
  const updateItemField = useCallback((itemId: string, field: keyof EditableDA2062Item, value: any) => {
    setEditableItems(prev => prev.map(item => 
      item.id === itemId ? { ...item, [field]: value } : item
    ));
  }, []);

  // Toggle item selection
  const toggleItemSelection = useCallback((itemId: string) => {
    updateItemField(itemId, 'isSelected', !editableItems.find(i => i.id === itemId)?.isSelected);
  }, [editableItems, updateItemField]);

  // Select/deselect all items
  const toggleAllSelection = useCallback(() => {
    const allSelected = editableItems.every(item => item.isSelected);
    setEditableItems(prev => prev.map(item => ({ ...item, isSelected: !allSelected })));
  }, [editableItems]);

  // Import selected items
  const importItems = useCallback(async () => {
    const selectedItems = editableItems.filter(item => item.isSelected);
    if (selectedItems.length === 0) {
      toast({
        title: 'No items selected',
        description: 'Please select at least one item to import',
        variant: 'destructive',
      });
      return;
    }
    
    setIsImporting(true);
    setCurrentStep('importing');
    
    try {
      // Convert to batch import format
      const batchItems: BatchImportItem[] = selectedItems.map(item => {
        // Handle quantity - create multiple items if quantity > 1
        const qty = parseInt(item.quantity) || 1;
        const items: BatchImportItem[] = [];
        
        for (let i = 0; i < qty; i++) {
          items.push({
            name: item.description,
            serialNumber: qty > 1 && !item.hasExplicitSerial 
              ? generateSerialNumber(item.description, i + 1)
              : item.serialNumber,
            nsn: item.nsn || undefined,
            quantity: 1, // Always 1 for individual items
            description: item.description,
            unitOfIssue: item.unit,
            importMetadata: {
              source: 'da2062_scan',
              formReference: parsedForm?.formNumber,
              confidence: item.confidence,
              ocrConfidence: item.confidence,
              serialSource: item.hasExplicitSerial ? 'explicit' : 'generated',
              verificationNeeded: item.needsVerification,
              extractedAt: new Date().toISOString(),
            }
          });
        }
        
        return items;
      }).flat();
      
      const result = await batchImportItems(batchItems);
      
      // Handle results
      if (result.created_count > 0) {
        toast({
          title: 'Import successful',
          description: `Imported ${result.created_count} of ${result.total_attempted} items`,
        });
        
        onImportComplete?.(result.created_count);
        handleClose();
      } else {
        throw new Error(result.error || 'No items were imported');
      }
      
      // Show warnings for failed items
      if (result.failed_count > 0) {
        const failureReasons = result.failed_items
          .map(f => `${f.item.name}: ${f.error}`)
          .join('\n');
        
        toast({
          title: 'Some items failed to import',
          description: `${result.failed_count} items failed. Check the details.`,
          variant: 'destructive',
        });
      }
    } catch (error) {
      toast({
        title: 'Import failed',
        description: error instanceof Error ? error.message : 'Failed to import items',
        variant: 'destructive',
      });
      setCurrentStep('review');
    } finally {
      setIsImporting(false);
    }
  }, [editableItems, parsedForm, toast, onImportComplete, handleClose]);

  // Render upload step
  const renderUploadStep = () => (
    <div className="space-y-6">
      <CleanCard>
        <div className="p-8 text-center">
          <div className="mb-6">
            <div className="mx-auto w-16 h-16 rounded-full bg-ios-secondary-background flex items-center justify-center">
              <FileImage className="h-8 w-8 text-secondary-text" />
            </div>
          </div>
          
          <h3 className="text-lg font-medium text-primary-text mb-2">
            Upload DA Form 2062
          </h3>
          <p className="text-sm text-secondary-text mb-6">
            Upload a scanned image or PDF of your DA-2062 hand receipt
          </p>
          
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*,.pdf"
            onChange={handleFileSelect}
            className="hidden"
          />
          
          {selectedFile ? (
            <div className="mb-4 p-4 bg-ios-secondary-background rounded-lg">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <FileText className="h-5 w-5 text-secondary-text" />
                  <div className="text-left">
                    <p className="text-sm font-medium text-primary-text">{selectedFile.name}</p>
                    <p className="text-xs text-secondary-text">
                      {(selectedFile.size / 1024 / 1024).toFixed(2)} MB
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedFile(null)}
                  className="text-tertiary-text hover:text-primary-text"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
            </div>
          ) : null}
          
          <div className="space-y-3">
            <Button
              variant="outline"
              onClick={() => fileInputRef.current?.click()}
              className="w-full"
              disabled={isProcessing}
            >
              <Upload className="h-4 w-4 mr-2" />
              {selectedFile ? 'Choose Different File' : 'Choose File'}
            </Button>
            
            {selectedFile && (
              <Button
                onClick={processFile}
                className="w-full"
                disabled={isProcessing}
              >
                {isProcessing ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    Processing...
                  </>
                ) : (
                  <>
                    <CheckCircle className="h-4 w-4 mr-2" />
                    Process Document
                  </>
                )}
              </Button>
            )}
          </div>
        </div>
      </CleanCard>
      
      {/* Processing status */}
      {uploadProgress && (
        <CleanCard>
          <div className="p-4">
            <div className="flex items-center space-x-3">
              <Loader2 className="h-5 w-5 text-ios-accent animate-spin" />
              <div className="flex-1">
                <p className="text-sm font-medium text-primary-text capitalize">
                  {uploadProgress.phase.replace(/_/g, ' ')}
                </p>
                <p className="text-xs text-secondary-text">
                  {uploadProgress.message}
                </p>
              </div>
            </div>
          </div>
        </CleanCard>
      )}
      
      {/* Instructions */}
      <div className="space-y-2 text-sm text-secondary-text">
        <p className="flex items-start space-x-2">
          <span className="text-ios-accent">•</span>
          <span>Supported formats: JPG, PNG, PDF</span>
        </p>
        <p className="flex items-start space-x-2">
          <span className="text-ios-accent">•</span>
          <span>Maximum file size: 10MB</span>
        </p>
        <p className="flex items-start space-x-2">
          <span className="text-ios-accent">•</span>
          <span>OCR processing extracts item details automatically</span>
        </p>
      </div>
    </div>
  );

  // Render review step
  const renderReviewStep = () => {
    const selectedCount = editableItems.filter(item => item.isSelected).length;
    const allSelected = editableItems.every(item => item.isSelected);
    
    return (
      <div className="space-y-6">
        {/* Form info */}
        {parsedForm && (
          <CleanCard>
            <div className="p-4 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-sm text-secondary-text">Form Confidence</span>
                <span className={`text-sm font-medium ${getConfidenceColor(parsedForm.confidence)}`}>
                  {getConfidenceLabel(parsedForm.confidence)} ({Math.round(parsedForm.confidence * 100)}%)
                </span>
              </div>
              {parsedForm.unitName && (
                <div className="flex items-center justify-between">
                  <span className="text-sm text-secondary-text">Unit</span>
                  <span className="text-sm font-medium text-primary-text">{parsedForm.unitName}</span>
                </div>
              )}
              {parsedForm.formNumber && (
                <div className="flex items-center justify-between">
                  <span className="text-sm text-secondary-text">Form Number</span>
                  <span className="text-sm font-medium text-primary-text">{parsedForm.formNumber}</span>
                </div>
              )}
            </div>
          </CleanCard>
        )}
        
        {/* Selection controls */}
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <Checkbox
              checked={allSelected}
              onCheckedChange={toggleAllSelection}
            />
            <span className="text-sm font-medium text-primary-text">
              Select All ({selectedCount} of {editableItems.length})
            </span>
          </div>
          <StatusBadge status="pending" size="sm">
            {selectedCount} SELECTED
          </StatusBadge>
        </div>
        
        {/* Items list */}
        <div className="space-y-2 max-h-96 overflow-y-auto">
          {editableItems.map((item) => {
            const isExpanded = expandedItems.has(item.id);
            
            return (
              <CleanCard key={item.id}>
                <div className="p-4">
                  {/* Item header */}
                  <div className="flex items-start space-x-3">
                    <Checkbox
                      checked={item.isSelected}
                      onCheckedChange={() => toggleItemSelection(item.id)}
                      className="mt-0.5"
                    />
                    
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between">
                        <div className="flex-1">
                          <p className="font-medium text-primary-text">
                            {item.description}
                          </p>
                          <div className="flex items-center space-x-4 mt-1">
                            <span className="text-xs text-secondary-text">
                              Qty: {item.quantity}
                            </span>
                            {item.nsn && (
                              <span className="text-xs text-secondary-text">
                                NSN: {formatNSN(item.nsn)}
                              </span>
                            )}
                            <span className="text-xs text-secondary-text">
                              S/N: {item.serialNumber}
                            </span>
                          </div>
                        </div>
                        
                        <button
                          onClick={() => toggleItemExpansion(item.id)}
                          className="p-1 hover:bg-ios-secondary-background rounded"
                        >
                          {isExpanded ? (
                            <ChevronDown className="h-4 w-4 text-tertiary-text" />
                          ) : (
                            <ChevronRight className="h-4 w-4 text-tertiary-text" />
                          )}
                        </button>
                      </div>
                      
                      {/* Warnings */}
                      {item.needsVerification && (
                        <div className="flex items-center space-x-2 mt-2">
                          <AlertTriangle className="h-3 w-3 text-ios-warning" />
                          <span className="text-xs text-ios-warning">
                            {!item.hasExplicitSerial && 'Serial number will be generated • '}
                            {item.confidence < 0.7 && 'Low OCR confidence • '}
                            {item.quantityConfidence < 0.7 && 'Verify quantity'}
                          </span>
                        </div>
                      )}
                    </div>
                  </div>
                  
                  {/* Expanded edit form */}
                  {isExpanded && (
                    <div className="mt-4 pl-9 space-y-3">
                      <div>
                        <Label className="text-xs text-secondary-text">Description</Label>
                        <Input
                          value={item.description}
                          onChange={(e) => updateItemField(item.id, 'description', e.target.value)}
                          className="mt-1"
                        />
                      </div>
                      
                      <div className="grid grid-cols-2 gap-3">
                        <div>
                          <Label className="text-xs text-secondary-text">NSN</Label>
                          <Input
                            value={item.nsn}
                            onChange={(e) => updateItemField(item.id, 'nsn', e.target.value)}
                            placeholder="XXXX-XX-XXX-XXXX"
                            className="mt-1"
                          />
                        </div>
                        
                        <div>
                          <Label className="text-xs text-secondary-text">Quantity</Label>
                          <Input
                            type="number"
                            value={item.quantity}
                            onChange={(e) => updateItemField(item.id, 'quantity', e.target.value)}
                            min="1"
                            className="mt-1"
                          />
                        </div>
                      </div>
                      
                      <div>
                        <Label className="text-xs text-secondary-text">Serial Number</Label>
                        <Input
                          value={item.serialNumber}
                          onChange={(e) => updateItemField(item.id, 'serialNumber', e.target.value)}
                          className="mt-1"
                        />
                        {!item.hasExplicitSerial && (
                          <p className="text-xs text-tertiary-text mt-1">
                            Auto-generated serial number
                          </p>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              </CleanCard>
            );
          })}
        </div>
      </div>
    );
  };

  // Render importing step
  const renderImportingStep = () => (
    <div className="py-12">
      <MinimalLoadingView text="IMPORTING ITEMS" size="lg" />
      <p className="text-center text-secondary-text mt-4">
        Please wait while we create property records...
      </p>
    </div>
  );

  return (
    <Dialog open={isOpen} onOpenChange={handleClose}>
      <DialogContent className="max-w-3xl max-h-[90vh] overflow-hidden flex flex-col">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2 text-primary-text">
            <Package className="h-5 w-5" />
            Import DA 2062
          </DialogTitle>
        </DialogHeader>
        
        <div className="flex-1 overflow-y-auto px-1">
          {currentStep === 'upload' && renderUploadStep()}
          {currentStep === 'review' && renderReviewStep()}
          {currentStep === 'importing' && renderImportingStep()}
        </div>
        
        <DialogFooter className="gap-2 sm:gap-2">
          {currentStep === 'upload' && (
            <>
              <Button
                variant="outline"
                onClick={handleClose}
                disabled={isProcessing}
              >
                Cancel
              </Button>
            </>
          )}
          
          {currentStep === 'review' && (
            <>
              <Button
                variant="outline"
                onClick={() => setCurrentStep('upload')}
                disabled={isImporting}
              >
                Back
              </Button>
              <Button
                onClick={importItems}
                disabled={isImporting || editableItems.filter(i => i.isSelected).length === 0}
              >
                <Package className="h-4 w-4 mr-2" />
                Import {editableItems.filter(i => i.isSelected).length} Items
              </Button>
            </>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};