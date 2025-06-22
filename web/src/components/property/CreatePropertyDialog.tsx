import React, { useState } from 'react';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { Loader2, Plus, Package, AlertCircle, Hash, FileText, Tag, ScanLine, StickyNote, UserCheck } from 'lucide-react';
import { categoryOptions } from '@/lib/propertyUtils';
import { useToast } from '@/hooks/use-toast';
import { checkSerialExists, syncProperties } from '@/services/syncService';
import { cn } from '@/lib/utils';
import { CleanCard } from '@/components/ios';

// Enhanced form field component
const FormField: React.FC<{
  label: string;
  icon: React.ReactNode;
  children: React.ReactNode;
  required?: boolean;
  error?: string | null;
}> = ({ label, icon, children, required, error }) => (
  <div className="space-y-2">
    <div className="flex items-center gap-2">
      <div className="p-1.5 bg-blue-500/10 rounded-md">
        {icon}
      </div>
      <Label className="text-xs font-medium text-ios-primary-text uppercase tracking-wider font-mono">
        {label}
        {required && <span className="text-ios-destructive ml-1">*</span>}
      </Label>
    </div>
    {children}
    {error && (
      <div className="flex items-center gap-2 text-sm text-destructive mt-1">
        <AlertCircle className="h-4 w-4" />
        {error}
      </div>
    )}
  </div>
);

interface CreatePropertyDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: {
    name: string;
    serialNumber: string;
    description?: string;
    category: string;
    nsn?: string;
    lin?: string;
    assignToSelf: boolean;
  }) => Promise<void>;
}

const CreatePropertyDialog: React.FC<CreatePropertyDialogProps> = ({
  isOpen,
  onClose,
  onSubmit,
}) => {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isValidatingSerial, setIsValidatingSerial] = useState(false);
  const [serialError, setSerialError] = useState<string | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    serialNumber: '',
    description: '',
    category: 'other',
    nsn: '',
    lin: '',
    assignToSelf: true,
  });

  const { toast } = useToast();

  const validateSerialNumber = async (serialNumber: string) => {
    if (!serialNumber.trim()) {
      setSerialError(null);
      return;
    }

    if (serialNumber.length < 3) {
      setSerialError("Serial number must be at least 3 characters");
      return;
    }

    setIsValidatingSerial(true);
    try {
      const exists = await checkSerialExists(serialNumber);
      if (exists) {
        setSerialError("A property with this serial number already exists");
      } else {
        setSerialError(null);
      }
    } catch (error) {
      console.error('Error validating serial number:', error);
      // Don't show error to user for validation failures
      setSerialError(null);
    } finally {
      setIsValidatingSerial(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    // Validate serial number format
    if (!formData.serialNumber.trim()) {
      toast({
        title: "Validation Error",
        description: "Serial number is required",
        variant: "destructive"
      });
      return;
    }

    // Check for existing serial error
    if (serialError) {
      toast({
        title: "Validation Error",
        description: serialError,
        variant: "destructive"
      });
      return;
    }

    setIsSubmitting(true);
    try {
      await onSubmit(formData);

      // Trigger sync after successful creation
      syncProperties();

      // Reset form on success
      setFormData({
        name: '',
        serialNumber: '',
        description: '',
        category: 'other',
        nsn: '',
        lin: '',
        assignToSelf: true,
      });
      setSerialError(null);
      onClose();
    } catch (error) {
      // Error handling is done in the parent component
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleChange = (field: string, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }));

    // Validate serial number on change with debouncing
    if (field === 'serialNumber') {
      const timer = setTimeout(() => validateSerialNumber(value), 500);
      return () => clearTimeout(timer);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && !isSubmitting && onClose()}>
      <DialogContent className="sm:max-w-lg bg-gradient-to-b from-white to-ios-tertiary-background/30 rounded-xl border-ios-border shadow-xl">
        <DialogHeader className="border-b border-ios-divider pb-4">
          <DialogTitle className="flex items-center gap-3">
            <div className="p-2.5 bg-gradient-to-br from-blue-500 to-blue-500/80 rounded-lg shadow-sm">
              <Package className="h-5 w-5 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-semibold text-ios-primary-text">
                Add New Item
              </h2>
              <p className="text-xs text-ios-secondary-text mt-0.5">
                Register a new equipment item with a unique serial number
              </p>
            </div>
          </DialogTitle>
        </DialogHeader>

        <form id="create-item-form" onSubmit={handleSubmit}>
          <div className="grid gap-6 py-6">
            {/* Item Identification Section */}
            <div className="space-y-4">
              <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-mono flex items-center gap-2">
                <div className="h-px flex-1 bg-ios-border" />
                <span>Item Identification</span>
                <div className="h-px flex-1 bg-ios-border" />
              </h3>
              
              <FormField
                label="Serial Number"
                icon={<Hash className="h-4 w-4 text-blue-500" />}
                required
                error={serialError}
              >
                <div className="relative">
                  <Input
                    id="serial-number"
                    value={formData.serialNumber}
                    onChange={(e) => handleChange('serialNumber', e.target.value.toUpperCase())}
                    placeholder="e.g., W123456 or 12345678"
                    className={cn(
                      "border-ios-border bg-ios-tertiary-background/50 rounded-lg h-12 text-base placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-blue-500 transition-all duration-200 font-mono pr-10",
                      serialError && "border-destructive focus-visible:ring-destructive"
                    )}
                    required
                    disabled={isSubmitting}
                  />
                  {isValidatingSerial && (
                    <div className="absolute right-3 top-1/2 -translate-y-1/2">
                      <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />
                    </div>
                  )}
                </div>
                {!serialError && (
                  <p className="text-xs text-ios-tertiary-text mt-1">
                    This must match the physical serial number on the equipment
                  </p>
                )}
              </FormField>

              <FormField
                label="Item Name"
                icon={<Package className="h-4 w-4 text-blue-500" />}
                required
              >
                <Input
                  id="item-name"
                  value={formData.name}
                  onChange={(e) => handleChange('name', e.target.value)}
                  placeholder="e.g., M4A1 Carbine, PRC-152 Radio"
                  className="border-ios-border bg-ios-tertiary-background/50 rounded-lg h-12 text-base placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-blue-500 transition-all duration-200"
                  required
                  disabled={isSubmitting}
                />
              </FormField>

              <FormField
                label="Category"
                icon={<Tag className="h-4 w-4 text-blue-500" />}
                required
              >
                <Select
                  value={formData.category}
                  onValueChange={(value) => handleChange('category', value)}
                  disabled={isSubmitting}
                >
                  <SelectTrigger id="category" className="border-ios-border bg-ios-tertiary-background/50 rounded-lg h-12 text-base focus-visible:ring-2 focus-visible:ring-blue-500 transition-all duration-200">
                    <SelectValue placeholder="Select category" />
                  </SelectTrigger>
                  <SelectContent>
                    {categoryOptions.map(option => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </FormField>
            </div>

            {/* Additional Details Section */}
            <div className="space-y-4">
              <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-mono flex items-center gap-2">
                <div className="h-px flex-1 bg-ios-border" />
                <span>Additional Details</span>
                <div className="h-px flex-1 bg-ios-border" />
              </h3>
              
              <div className="grid grid-cols-2 gap-4">
                <FormField
                  label="NSN"
                  icon={<ScanLine className="h-4 w-4 text-blue-500" />}
                >
                  <Input
                    id="nsn"
                    value={formData.nsn}
                    onChange={(e) => handleChange('nsn', e.target.value)}
                    placeholder="1234-56-789-0123"
                    className="border-ios-border bg-ios-tertiary-background/50 rounded-lg h-10 text-sm placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-blue-500 transition-all duration-200 font-mono"
                    disabled={isSubmitting}
                  />
                </FormField>
                
                <FormField
                  label="LIN"
                  icon={<FileText className="h-4 w-4 text-blue-500" />}
                >
                  <Input
                    id="lin"
                    value={formData.lin}
                    onChange={(e) => handleChange('lin', e.target.value.toUpperCase())}
                    placeholder="A12345"
                    className="border-ios-border bg-ios-tertiary-background/50 rounded-lg h-10 text-sm placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-blue-500 transition-all duration-200 font-mono"
                    disabled={isSubmitting}
                  />
                </FormField>
              </div>

              <FormField
                label="Description"
                icon={<StickyNote className="h-4 w-4 text-blue-500" />}
              >
                <Textarea
                  id="description"
                  value={formData.description}
                  onChange={(e) => handleChange('description', e.target.value)}
                  placeholder="Additional details about the item..."
                  className="border-ios-border bg-ios-tertiary-background/50 rounded-lg text-base placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-blue-500 transition-all duration-200 resize-none"
                  rows={3}
                  disabled={isSubmitting}
                />
              </FormField>

              <CleanCard className="p-4 bg-gradient-to-r from-ios-tertiary-background/30 to-ios-tertiary-background/10">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="p-1.5 bg-green-500/10 rounded-md">
                      <UserCheck className="h-4 w-4 text-green-500" />
                    </div>
                    <div>
                      <Label htmlFor="assign-to-self" className="text-sm font-medium text-ios-primary-text cursor-pointer">
                        Auto-assign to me
                      </Label>
                      <p className="text-xs text-ios-secondary-text mt-0.5">
                        I will be the initial custodian of this item
                      </p>
                    </div>
                  </div>
                  <input
                    type="checkbox"
                    id="assign-to-self"
                    checked={formData.assignToSelf}
                    onChange={(e) => handleChange('assignToSelf', e.target.checked)}
                    className="h-5 w-5 rounded border-ios-border text-blue-500 focus:ring-2 focus:ring-blue-500 focus:ring-offset-0 transition-all duration-200"
                    disabled={isSubmitting}
                  />
                </div>
              </CleanCard>
            </div>
          </div>

          <DialogFooter className="gap-3 sm:gap-3">
            <Button
              type="button"
              variant="outline"
              className="border-ios-border hover:bg-ios-tertiary-background text-ios-secondary-text rounded-lg px-6 py-2.5 font-medium transition-all duration-200"
              onClick={onClose}
              disabled={isSubmitting}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              className="bg-blue-500 hover:bg-blue-500/90 text-white rounded-lg px-6 py-2.5 font-medium shadow-sm transition-all duration-200 flex items-center gap-2"
              disabled={isSubmitting || isValidatingSerial || !!serialError}
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  <span>Creating...</span>
                </>
              ) : (
                <>
                  <Plus className="h-4 w-4" />
                  <span>Add Item</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
};

export default CreatePropertyDialog; 