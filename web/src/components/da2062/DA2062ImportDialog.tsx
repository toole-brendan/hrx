import React, { useState, useCallback, useRef } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '../ui/dialog';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { Checkbox } from '../ui/checkbox';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';
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
  Package,
  Shield
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
      <div className="text-center mb-8">
        <div className="mb-6">
          <div className="mx-auto w-20 h-20 rounded-2xl bg-gradient-to-br from-ios-accent/20 to-ios-accent/10 flex items-center justify-center shadow-sm">
            <FileImage className="h-10 w-10 text-ios-accent" />
          </div>
        </div>
        
        <h3 className="text-xl font-semibold text-ios-primary-text mb-2">
          Upload DA Form 2062
        </h3>
        <p className="text-sm text-ios-secondary-text max-w-md mx-auto">
          Upload a scanned image or PDF of your DA-2062 hand receipt for automatic item extraction
        </p>
      </div>
      
      <CleanCard className="shadow-sm border border-ios-border">
        <div className="p-6">
          
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*,.pdf"
            onChange={handleFileSelect}
            className="hidden"
          />
          
          {selectedFile ? (
            <div className="mb-6 p-4 bg-gradient-to-r from-ios-accent/10 to-ios-accent/5 rounded-lg border border-ios-accent/20">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="p-2.5 bg-white rounded-lg shadow-sm">
                    <FileText className="h-5 w-5 text-ios-accent" />
                  </div>
                  <div className="text-left">
                    <p className="text-sm font-medium text-ios-primary-text">{selectedFile.name}</p>
                    <p className="text-xs text-ios-secondary-text font-mono">
                      {(selectedFile.size / 1024 / 1024).toFixed(2)} MB
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedFile(null)}
                  className="p-1.5 hover:bg-white/50 rounded-lg transition-colors"
                >
                  <X className="h-4 w-4 text-ios-tertiary-text" />
                </button>
              </div>
            </div>
          ) : (
            <div className="mb-6 p-8 border-2 border-dashed border-ios-border rounded-lg hover:border-ios-accent/30 transition-colors">
              <div className="text-center">
                <Upload className="h-8 w-8 text-ios-tertiary-text mx-auto mb-3" />
                <p className="text-sm text-ios-secondary-text mb-1">Drop your file here, or click to browse</p>
                <p className="text-xs text-ios-tertiary-text">JPG, PNG, or PDF (max 10MB)</p>
              </div>
            </div>
          )}
          
          <div className="space-y-3">
            <Button
              variant="outline"
              onClick={() => fileInputRef.current?.click()}
              className="w-full h-11 border-ios-border hover:border-ios-accent/30 hover:bg-ios-tertiary-background font-medium transition-all duration-200"
              disabled={isProcessing}
            >
              <Upload className="h-4 w-4 mr-2" />
              {selectedFile ? 'Choose Different File' : 'Choose File'}
            </Button>
            
            {selectedFile && (
              <Button
                onClick={processFile}
                className="w-full h-11 bg-ios-accent hover:bg-ios-accent/90 text-white font-medium shadow-sm transition-all duration-200"
                disabled={isProcessing}
              >
                {isProcessing ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    Processing Document...
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
        <div className="bg-gradient-to-r from-blue-500/10 to-blue-500/5 rounded-lg p-4 border border-blue-500/20">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-white rounded-lg shadow-sm">
              <Loader2 className="h-5 w-5 text-blue-500 animate-spin" />
            </div>
            <div className="flex-1">
              <p className="text-sm font-semibold text-ios-primary-text capitalize">
                {uploadProgress.phase.replace(/_/g, ' ')}
              </p>
              <p className="text-xs text-ios-secondary-text mt-0.5">
                {uploadProgress.message}
              </p>
            </div>
          </div>
        </div>
      )}
      
      {/* Instructions Card */}
      <div className="bg-ios-tertiary-background/50 rounded-lg p-4">
        <h4 className="text-xs font-semibold text-ios-primary-text uppercase tracking-wider mb-3 font-mono">
          UPLOAD GUIDELINES
        </h4>
        <div className="space-y-2">
          <div className="flex items-start gap-2">
            <CheckCircle className="h-3.5 w-3.5 text-green-500 mt-0.5 flex-shrink-0" />
            <p className="text-xs text-ios-secondary-text">Supported formats: JPG, PNG, PDF</p>
          </div>
          <div className="flex items-start gap-2">
            <CheckCircle className="h-3.5 w-3.5 text-green-500 mt-0.5 flex-shrink-0" />
            <p className="text-xs text-ios-secondary-text">Maximum file size: 10MB</p>
          </div>
          <div className="flex items-start gap-2">
            <CheckCircle className="h-3.5 w-3.5 text-green-500 mt-0.5 flex-shrink-0" />
            <p className="text-xs text-ios-secondary-text">OCR extracts item details automatically</p>
          </div>
          <div className="flex items-start gap-2">
            <AlertTriangle className="h-3.5 w-3.5 text-orange-500 mt-0.5 flex-shrink-0" />
            <p className="text-xs text-ios-secondary-text">Ensure text is clear and readable for best results</p>
          </div>
        </div>
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
          <div className="bg-gradient-to-r from-ios-accent/10 to-ios-accent/5 rounded-xl p-5 border border-ios-accent/20">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2.5 bg-white rounded-lg shadow-sm">
                <FileText className="h-5 w-5 text-ios-accent" />
              </div>
              <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-mono">
                FORM DETAILS
              </h3>
            </div>
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-xs text-ios-secondary-text uppercase tracking-wider">Confidence Score</span>
                <div className="flex items-center gap-2">
                  <div className="flex gap-1">
                    {[1, 2, 3, 4, 5].map((level) => (
                      <div
                        key={level}
                        className={cn(
                          "h-2 w-6 rounded-full transition-colors",
                          parsedForm.confidence >= level * 0.2
                            ? "bg-green-500"
                            : "bg-ios-tertiary-background"
                        )}
                      />
                    ))}
                  </div>
                  <span className={`text-sm font-bold ${getConfidenceColor(parsedForm.confidence)}`}>
                    {Math.round(parsedForm.confidence * 100)}%
                  </span>
                </div>
              </div>
              {parsedForm.unitName && (
                <div className="flex items-center justify-between">
                  <span className="text-xs text-ios-secondary-text uppercase tracking-wider">Unit</span>
                  <span className="text-sm font-medium text-ios-primary-text font-mono">{parsedForm.unitName}</span>
                </div>
              )}
              {parsedForm.formNumber && (
                <div className="flex items-center justify-between">
                  <span className="text-xs text-ios-secondary-text uppercase tracking-wider">Form Number</span>
                  <span className="text-sm font-medium text-ios-primary-text font-mono">{parsedForm.formNumber}</span>
                </div>
              )}
            </div>
          </div>
        )}
        
        {/* Selection controls */}
        <div className="bg-white rounded-lg p-4 shadow-sm border border-ios-border">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Checkbox
                checked={allSelected}
                onCheckedChange={toggleAllSelection}
                className="data-[state=checked]:bg-ios-accent data-[state=checked]:border-ios-accent"
              />
              <label className="text-sm font-medium text-ios-primary-text cursor-pointer select-none">
                Select All Items
              </label>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-xs text-ios-secondary-text">
                {selectedCount} of {editableItems.length} selected
              </span>
              <div className="px-3 py-1 bg-ios-accent text-white text-xs font-semibold rounded-full uppercase tracking-wider">
                {selectedCount} ITEMS
              </div>
            </div>
          </div>
        </div>
        
        {/* Items list */}
        <div className="space-y-3 max-h-[400px] overflow-y-auto pr-2">
          {editableItems.map((item) => {
            const isExpanded = expandedItems.has(item.id);
            
            return (
              <CleanCard key={item.id} className="shadow-sm border border-ios-border hover:border-ios-accent/30 transition-all duration-200">
                <div className="p-4">
                  {/* Item header */}
                  <div className="flex items-start gap-3">
                    <Checkbox
                      checked={item.isSelected}
                      onCheckedChange={() => toggleItemSelection(item.id)}
                      className="mt-0.5 data-[state=checked]:bg-ios-accent data-[state=checked]:border-ios-accent"
                    />
                    
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between">
                        <div className="flex-1">
                          <h4 className="font-semibold text-ios-primary-text">
                            {item.description}
                          </h4>
                          <div className="flex flex-wrap items-center gap-3 mt-2">
                            <span className="inline-flex items-center gap-1 text-xs text-ios-secondary-text">
                              <Package className="h-3 w-3" />
                              Qty: <span className="font-semibold">{item.quantity}</span>
                            </span>
                            {item.nsn && (
                              <span className="inline-flex items-center gap-1 text-xs text-ios-secondary-text">
                                <FileText className="h-3 w-3" />
                                NSN: <span className="font-mono">{formatNSN(item.nsn)}</span>
                              </span>
                            )}
                            <span className="inline-flex items-center gap-1 text-xs text-ios-secondary-text">
                              <Shield className="h-3 w-3" />
                              S/N: <span className="font-mono">{item.serialNumber}</span>
                            </span>
                          </div>
                        </div>
                        
                        <button
                          onClick={() => toggleItemExpansion(item.id)}
                          className="p-1.5 hover:bg-ios-tertiary-background rounded-lg transition-colors"
                        >
                          {isExpanded ? (
                            <ChevronDown className="h-4 w-4 text-ios-tertiary-text" />
                          ) : (
                            <ChevronRight className="h-4 w-4 text-ios-tertiary-text" />
                          )}
                        </button>
                      </div>
                      
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
      <DialogContent className="max-w-3xl max-h-[90vh] overflow-hidden flex flex-col bg-gradient-to-b from-white to-ios-tertiary-background/30">
        <DialogHeader className="border-b border-ios-divider pb-4">
          <DialogTitle className="flex items-center gap-3">
            <div className="p-2.5 bg-gradient-to-br from-ios-accent to-ios-accent/80 rounded-lg shadow-sm">
              <Package className="h-5 w-5 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-semibold text-ios-primary-text">
                Import DA 2062
              </h2>
              <p className="text-xs text-ios-secondary-text mt-0.5">
                {currentStep === 'upload' && 'Upload your form'}
                {currentStep === 'review' && `Review ${editableItems.length} items`}
                {currentStep === 'importing' && 'Processing import'}
              </p>
            </div>
          </DialogTitle>
        </DialogHeader>
        
        <div className="flex-1 overflow-y-auto px-1">
          {currentStep === 'upload' && renderUploadStep()}
          {currentStep === 'review' && renderReviewStep()}
          {currentStep === 'importing' && renderImportingStep()}
        </div>
        
        <DialogFooter className="border-t border-ios-divider pt-4">
          {currentStep === 'upload' && (
            <Button
              variant="outline"
              onClick={handleClose}
              disabled={isProcessing}
              className="border-ios-border hover:bg-ios-tertiary-background font-medium"
            >
              Cancel
            </Button>
          )}
          
          {currentStep === 'review' && (
            <>
              <Button
                variant="outline"
                onClick={() => setCurrentStep('upload')}
                disabled={isImporting}
                className="border-ios-border hover:bg-ios-tertiary-background font-medium"
              >
                Back
              </Button>
              <Button
                onClick={importItems}
                disabled={isImporting || editableItems.filter(i => i.isSelected).length === 0}
                className="bg-ios-accent hover:bg-ios-accent/90 text-white font-medium shadow-sm transition-all duration-200"
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