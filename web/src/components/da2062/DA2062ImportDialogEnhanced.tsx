import React, { useState, useCallback, useRef, useEffect } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '../ui/dialog';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { Checkbox } from '../ui/checkbox';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/select';
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
  Shield,
  Sparkles,
  Lightbulb,
  AlertCircle,
  Camera,
  Info,
  Settings
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
  UploadProgress,
  AISuggestion
} from '@/services/da2062Service';

import {
  getUnitOfIssueCodes,
  getPropertyCategories,
  getConditionCodes,
  getSecurityClassifications,
  detectCategoryFromDescription,
  detectUnitOfIssue
} from '@/services/referenceDataService';

import { UnitOfIssueCode, PropertyCategory } from '@/types';

interface DA2062ImportDialogEnhancedProps {
  isOpen: boolean;
  onClose: () => void;
  onImportComplete?: (importedCount: number) => void;
}

export const DA2062ImportDialogEnhanced: React.FC<DA2062ImportDialogEnhancedProps> = ({
  isOpen,
  onClose,
  onImportComplete
}) => {
  const [currentStep, setCurrentStep] = useState<'upload' | 'review' | 'importing'>('upload');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [selectedFiles, setSelectedFiles] = useState<File[]>([]); // For multi-file
  const [isProcessing, setIsProcessing] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<UploadProgress | null>(null);
  const [parsedForm, setParsedForm] = useState<DA2062Form | null>(null);
  const [editableItems, setEditableItems] = useState<EditableDA2062Item[]>([]);
  const [expandedItems, setExpandedItems] = useState<Set<string>>(new Set());
  const [isImporting, setIsImporting] = useState(false);
  const [showBulkActions, setShowBulkActions] = useState(false);
  
  // Reference data
  const [unitOfIssueCodes, setUnitOfIssueCodes] = useState<UnitOfIssueCode[]>([]);
  const [propertyCategories, setPropertyCategories] = useState<PropertyCategory[]>([]);
  const conditionCodes = getConditionCodes();
  const securityClasses = getSecurityClassifications();
  
  const fileInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);
  const { toast } = useToast();

  // Load reference data
  useEffect(() => {
    if (isOpen) {
      loadReferenceData();
    }
  }, [isOpen]);

  const loadReferenceData = async () => {
    try {
      const [units, categories] = await Promise.all([
        getUnitOfIssueCodes(),
        getPropertyCategories()
      ]);
      setUnitOfIssueCodes(units);
      setPropertyCategories(categories);
    } catch (error) {
      console.error('Failed to load reference data:', error);
    }
  };

  // Reset state when dialog closes
  const handleClose = useCallback(() => {
    setCurrentStep('upload');
    setSelectedFile(null);
    setSelectedFiles([]);
    setIsProcessing(false);
    setUploadProgress(null);
    setParsedForm(null);
    setEditableItems([]);
    setExpandedItems(new Set());
    setIsImporting(false);
    setShowBulkActions(false);
    onClose();
  }, [onClose]);

  // Handle file selection
  const handleFileSelect = useCallback((event: React.ChangeEvent<HTMLInputElement>) => {
    const files = event.target.files;
    if (files && files.length > 0) {
      // Validate file types
      const validTypes = ['image/jpeg', 'image/png', 'image/jpg', 'application/pdf'];
      const validFiles: File[] = [];
      
      for (let i = 0; i < files.length; i++) {
        const file = files[i];
        
        if (!validTypes.includes(file.type)) {
          toast({
            title: 'Invalid file type',
            description: `${file.name} is not a valid file type`,
            variant: 'destructive',
          });
          continue;
        }
        
        // Validate file size (max 10MB)
        if (file.size > 10 * 1024 * 1024) {
          toast({
            title: 'File too large',
            description: `${file.name} is larger than 10MB`,
            variant: 'destructive',
          });
          continue;
        }
        
        validFiles.push(file);
      }
      
      if (validFiles.length > 0) {
        setSelectedFiles(validFiles);
        setSelectedFile(validFiles[0]); // For single file compatibility
      }
    }
  }, [toast]);

  // Process the uploaded file(s)
  const processFiles = useCallback(async () => {
    if (selectedFiles.length === 0) return;
    
    setIsProcessing(true);
    try {
      // For now, process first file (multi-file support to be implemented)
      const result = await uploadDA2062(selectedFiles[0], setUploadProgress);
      setParsedForm(result);
      
      // Convert to editable items with enhanced fields
      const editable: EditableDA2062Item[] = result.items.map((item, index) => {
        const detectedCategory = detectCategoryFromDescription(item.itemDescription, propertyCategories);
        const detectedUnitOfIssue = detectUnitOfIssue(item.itemDescription, item.quantity);
        
        return {
          ...item,
          id: `item-${index}`,
          description: item.itemDescription,
          nsn: item.stockNumber || '',
          quantity: item.quantity.toString(),
          serialNumber: item.serialNumber || generateSerialNumber(item.itemDescription, index + 1),
          unit: item.unitOfIssue,
          isSelected: true,
          // DA 2062 fields with defaults
          unitOfIssue: item.unitOfIssue || detectedUnitOfIssue,
          conditionCode: 'A', // Default to serviceable
          category: detectedCategory || undefined,
          manufacturer: undefined,
          partNumber: undefined,
          securityClassification: detectedCategory && propertyCategories.find(c => c.code === detectedCategory)?.defaultSecurityClass || 'U',
          // AI fields
          suggestions: item.suggestions,
          aiGrouped: item.aiGrouped,
          needsReview: item.needsReview,
          validationIssues: item.validationIssues,
        };
      });
      
      setEditableItems(editable);
      setCurrentStep('review');
      
      toast({
        title: 'Claude AI processing complete',
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
  }, [selectedFiles, propertyCategories, toast]);

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

  // Bulk Actions
  const applyAllSuggestions = useCallback(() => {
    setEditableItems(prev => prev.map(item => {
      if (!item.suggestions || item.suggestions.length === 0) return item;
      
      let updatedItem = { ...item };
      item.suggestions.forEach(suggestion => {
        if (suggestion.field in updatedItem) {
          (updatedItem as any)[suggestion.field] = suggestion.value;
        }
      });
      updatedItem.suggestions = [];
      return updatedItem;
    }));
    
    toast({
      title: 'AI suggestions applied',
      description: 'All AI suggestions have been applied to the items',
    });
  }, [toast]);

  const setAllConditions = useCallback((conditionCode: string) => {
    setEditableItems(prev => prev.map(item => ({ ...item, conditionCode })));
  }, []);

  const autoDetectCategories = useCallback(() => {
    setEditableItems(prev => prev.map(item => {
      const detected = detectCategoryFromDescription(item.description, propertyCategories);
      if (detected && !item.category) {
        return { 
          ...item, 
          category: detected,
          securityClassification: propertyCategories.find(c => c.code === detected)?.defaultSecurityClass || item.securityClassification
        };
      }
      return item;
    }));
    
    toast({
      title: 'Categories detected',
      description: 'Auto-detected categories for items based on descriptions',
    });
  }, [propertyCategories, toast]);

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
            unitOfIssue: item.unitOfIssue,
            conditionCode: item.conditionCode,
            category: item.category,
            manufacturer: item.manufacturer,
            partNumber: item.partNumber,
            securityClassification: item.securityClassification,
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
        <div className="mt-3 inline-flex items-center gap-2 px-3 py-1.5 bg-blue-50 text-blue-700 rounded-full text-xs font-medium">
          <div className="w-2 h-2 bg-blue-500 rounded-full animate-pulse" />
          AI-Enhanced Processing
        </div>
      </div>
      
      <CleanCard className="shadow-sm border border-ios-border">
        <div className="p-6">
          
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*,.pdf"
            onChange={handleFileSelect}
            className="hidden"
            multiple
          />
          
          <input
            ref={cameraInputRef}
            type="file"
            accept="image/*"
            capture="environment"
            onChange={handleFileSelect}
            className="hidden"
          />
          
          {selectedFiles.length > 0 ? (
            <div className="mb-6 space-y-3">
              {selectedFiles.map((file, index) => (
                <div key={index} className="p-4 bg-gradient-to-r from-ios-accent/10 to-ios-accent/5 rounded-lg border border-ios-accent/20">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4">
                      <div className="p-2.5 bg-white rounded-lg shadow-sm">
                        <FileText className="h-5 w-5 text-ios-accent" />
                      </div>
                      <div className="text-left">
                        <p className="text-sm font-medium text-ios-primary-text">{file.name}</p>
                        <p className="text-xs text-ios-secondary-text font-mono">
                          {(file.size / 1024 / 1024).toFixed(2)} MB
                        </p>
                      </div>
                    </div>
                    <button
                      onClick={() => {
                        setSelectedFiles(prev => prev.filter((_, i) => i !== index));
                        if (selectedFiles.length === 1) {
                          setSelectedFile(null);
                        }
                      }}
                      className="p-1.5 hover:bg-white/50 rounded-lg transition-colors"
                    >
                      <X className="h-4 w-4 text-ios-tertiary-text" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="mb-6 p-8 border-2 border-dashed border-ios-border rounded-lg hover:border-ios-accent/30 transition-colors">
              <div className="text-center">
                <Upload className="h-8 w-8 text-ios-tertiary-text mx-auto mb-3" />
                <p className="text-sm text-ios-secondary-text mb-1">Drop your files here, or click to browse</p>
                <p className="text-xs text-ios-tertiary-text">JPG, PNG, or PDF (max 10MB per file)</p>
              </div>
            </div>
          )}
          
          <div className="space-y-3">
            <div className="grid grid-cols-2 gap-3">
              <Button
                onClick={() => fileInputRef.current?.click()}
                className="h-11 bg-blue-500 hover:bg-blue-600 text-white font-medium transition-all duration-200 border-0"
                disabled={isProcessing}
              >
                <Upload className="h-4 w-4 mr-2" />
                Choose Files
              </Button>
              
              <Button
                onClick={() => cameraInputRef.current?.click()}
                className="h-11 bg-blue-500 hover:bg-blue-600 text-white font-medium transition-all duration-200 border-0"
                disabled={isProcessing}
              >
                <Camera className="h-4 w-4 mr-2" />
                Take Photo
              </Button>
            </div>
            
            {selectedFiles.length > 0 && (
              <Button
                onClick={processFiles}
                className="w-full h-11 bg-blue-500 hover:bg-blue-600 text-white font-medium shadow-sm transition-all duration-200 border-0"
                disabled={isProcessing}
              >
                {isProcessing ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    Processing Documents...
                  </>
                ) : (
                  <>
                    <CheckCircle className="h-4 w-4 mr-2" />
                    Process {selectedFiles.length} {selectedFiles.length === 1 ? 'Document' : 'Documents'}
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
            <p className="text-xs text-ios-secondary-text">Maximum file size: 10MB per file</p>
          </div>
          <div className="flex items-start gap-2">
            <CheckCircle className="h-3.5 w-3.5 text-green-500 mt-0.5 flex-shrink-0" />
            <p className="text-xs text-ios-secondary-text">Multi-page upload supported</p>
          </div>
          <div className="flex items-start gap-2">
            <CheckCircle className="h-3.5 w-3.5 text-green-500 mt-0.5 flex-shrink-0" />
            <p className="text-xs text-ios-secondary-text">Claude AI extracts item details with high accuracy</p>
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
              {parsedForm.metadata && (
                <>
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-ios-secondary-text uppercase tracking-wider">AI Processing</span>
                    <div className="flex items-center gap-2">
                      <Sparkles className="h-3 w-3 text-blue-500" />
                      <span className="text-sm font-medium text-ios-primary-text">
                        {parsedForm.metadata.groupedItems} multi-line items grouped
                      </span>
                    </div>
                  </div>
                  {parsedForm.processingTimeMs && (
                    <div className="flex items-center justify-between">
                      <span className="text-xs text-ios-secondary-text uppercase tracking-wider">Processing Time</span>
                      <span className="text-sm font-medium text-ios-primary-text font-mono">
                        {(parsedForm.processingTimeMs / 1000).toFixed(2)}s
                      </span>
                    </div>
                  )}
                </>
              )}
            </div>
          </div>
        )}
        
        {/* Selection controls and Bulk Actions */}
        <div className="space-y-3">
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
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowBulkActions(!showBulkActions)}
                  className="ml-2"
                >
                  <Settings className="h-4 w-4" />
                </Button>
              </div>
            </div>
          </div>
          
          {/* Bulk Actions Panel */}
          {showBulkActions && (
            <div className="bg-ios-tertiary-background/50 rounded-lg p-4 space-y-3">
              <h4 className="text-xs font-semibold text-ios-primary-text uppercase tracking-wider mb-3">
                BULK ACTIONS
              </h4>
              <div className="grid grid-cols-2 gap-3">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={applyAllSuggestions}
                  className="justify-start"
                >
                  <Sparkles className="h-4 w-4 mr-2" />
                  Apply All AI Suggestions
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={autoDetectCategories}
                  className="justify-start"
                >
                  <Package className="h-4 w-4 mr-2" />
                  Auto-Detect Categories
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setAllConditions('A')}
                  className="justify-start"
                >
                  <CheckCircle className="h-4 w-4 mr-2 text-green-500" />
                  Set All Serviceable
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setAllConditions('B')}
                  className="justify-start"
                >
                  <AlertTriangle className="h-4 w-4 mr-2 text-orange-500" />
                  Set All Repairable
                </Button>
              </div>
            </div>
          )}
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
                          <div className="flex items-center gap-2">
                            <h4 className="font-semibold text-ios-primary-text">
                              {item.description}
                            </h4>
                            {item.aiGrouped && (
                              <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-blue-50 text-blue-700 rounded-full text-xs font-medium">
                                <Sparkles className="h-3 w-3" />
                                AI Grouped
                              </span>
                            )}
                            {item.needsReview && (
                              <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-amber-50 text-amber-700 rounded-full text-xs font-medium">
                                <AlertCircle className="h-3 w-3" />
                                Review
                              </span>
                            )}
                          </div>
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
                            {item.confidence && (
                              <span className={`inline-flex items-center gap-1 text-xs ${getConfidenceColor(item.confidence)}`}>
                                {getConfidenceLabel(item.confidence)} confidence
                              </span>
                            )}
                          </div>
                          
                          {/* Quick edit fields - always visible */}
                          <div className="mt-3 grid grid-cols-3 gap-2">
                            <div>
                              <Label className="text-xs text-ios-secondary-text">Unit of Issue</Label>
                              <Select
                                value={item.unitOfIssue}
                                onValueChange={(value) => updateItemField(item.id, 'unitOfIssue', value)}
                              >
                                <SelectTrigger className="h-8 text-xs">
                                  <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                  {unitOfIssueCodes.map(unit => (
                                    <SelectItem key={unit.code} value={unit.code}>
                                      {unit.description} ({unit.code})
                                    </SelectItem>
                                  ))}
                                </SelectContent>
                              </Select>
                            </div>
                            
                            <div>
                              <Label className="text-xs text-ios-secondary-text">Condition</Label>
                              <Select
                                value={item.conditionCode}
                                onValueChange={(value) => updateItemField(item.id, 'conditionCode', value)}
                              >
                                <SelectTrigger className="h-8 text-xs">
                                  <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                  {conditionCodes.map(condition => (
                                    <SelectItem key={condition.code} value={condition.code}>
                                      {condition.label}
                                    </SelectItem>
                                  ))}
                                </SelectContent>
                              </Select>
                            </div>
                            
                            <div>
                              <Label className="text-xs text-ios-secondary-text">Category</Label>
                              <Select
                                value={item.category || ''}
                                onValueChange={(value) => {
                                  updateItemField(item.id, 'category', value);
                                  // Update security classification based on category
                                  const category = propertyCategories.find(c => c.code === value);
                                  if (category) {
                                    updateItemField(item.id, 'securityClassification', category.defaultSecurityClass);
                                  }
                                }}
                              >
                                <SelectTrigger className="h-8 text-xs">
                                  <SelectValue placeholder="Select..." />
                                </SelectTrigger>
                                <SelectContent>
                                  {propertyCategories.map(category => (
                                    <SelectItem key={category.code} value={category.code}>
                                      {category.name}
                                    </SelectItem>
                                  ))}
                                </SelectContent>
                              </Select>
                            </div>
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
                  
                  {/* AI Suggestions */}
                  {item.suggestions && item.suggestions.length > 0 && (
                    <div className="mt-3 ml-9 space-y-2">
                      {item.suggestions.map((suggestion, idx) => (
                        <div key={idx} className="flex items-start gap-2 p-2 bg-blue-50 rounded-lg">
                          <Lightbulb className="h-4 w-4 text-blue-600 mt-0.5 flex-shrink-0" />
                          <div className="flex-1 text-xs">
                            <span className="font-medium text-blue-900">
                              {suggestion.field}: 
                            </span>
                            <span className="text-blue-700 ml-1">
                              {suggestion.value}
                            </span>
                            {suggestion.reasoning && (
                              <p className="text-blue-600 mt-0.5">{suggestion.reasoning}</p>
                            )}
                          </div>
                          <button
                            onClick={() => {
                              updateItemField(item.id, suggestion.field as any, suggestion.value);
                              // Remove the suggestion after applying
                              const newSuggestions = item.suggestions?.filter((_, i) => i !== idx);
                              updateItemField(item.id, 'suggestions', newSuggestions);
                            }}
                            className="px-2 py-1 bg-blue-600 text-white text-xs rounded hover:bg-blue-700 transition-colors"
                          >
                            Apply
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                  
                  {/* Validation Issues */}
                  {item.validationIssues && item.validationIssues.length > 0 && (
                    <div className="mt-3 ml-9">
                      <div className="flex items-start gap-2 p-2 bg-red-50 rounded-lg">
                        <AlertCircle className="h-4 w-4 text-red-600 mt-0.5 flex-shrink-0" />
                        <div className="flex-1">
                          <p className="text-xs font-medium text-red-900">Validation Issues:</p>
                          <ul className="text-xs text-red-700 mt-1 space-y-0.5">
                            {item.validationIssues.map((issue, idx) => (
                              <li key={idx}>• {issue}</li>
                            ))}
                          </ul>
                        </div>
                      </div>
                    </div>
                  )}
                  
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
                      
                      <div className="grid grid-cols-2 gap-3">
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
                        
                        <div>
                          <Label className="text-xs text-secondary-text">Security Classification</Label>
                          <Select
                            value={item.securityClassification}
                            onValueChange={(value) => updateItemField(item.id, 'securityClassification', value)}
                          >
                            <SelectTrigger className="mt-1">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              {securityClasses.map(sc => (
                                <SelectItem key={sc.code} value={sc.code}>
                                  {sc.label}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </div>
                      </div>
                      
                      <div className="grid grid-cols-2 gap-3">
                        <div>
                          <Label className="text-xs text-secondary-text">Manufacturer</Label>
                          <Input
                            value={item.manufacturer || ''}
                            onChange={(e) => updateItemField(item.id, 'manufacturer', e.target.value)}
                            placeholder="Optional"
                            className="mt-1"
                          />
                        </div>
                        
                        <div>
                          <Label className="text-xs text-secondary-text">Part Number</Label>
                          <Input
                            value={item.partNumber || ''}
                            onChange={(e) => updateItemField(item.id, 'partNumber', e.target.value)}
                            placeholder="Optional"
                            className="mt-1"
                          />
                        </div>
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
      <DialogContent className="max-w-4xl max-h-[90vh] overflow-hidden flex flex-col bg-gradient-to-b from-white to-ios-tertiary-background/30">
        <DialogHeader className="border-b border-ios-divider pb-4">
          <DialogTitle className="flex items-center gap-3">
            <div className="p-2.5 bg-blue-500 rounded-lg shadow-sm">
              <Package className="h-5 w-5 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-semibold text-ios-primary-text">
                Import DA 2062 (Enhanced)
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
              className="text-blue-500 border border-blue-500 hover:bg-blue-500 hover:border-blue-500 hover:text-white font-medium transition-all duration-200 hover:scale-105"
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
                className="bg-blue-500 hover:bg-blue-600 text-white font-medium shadow-sm transition-all duration-200 border-0"
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