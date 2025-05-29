import React, { useState } from 'react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { Loader2, Plus, Package } from 'lucide-react';
import { categoryOptions } from '@/lib/inventoryUtils';
import { useToast } from '@/hooks/use-toast';

interface CreateItemDialogProps {
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

const CreateItemDialog: React.FC<CreateItemDialogProps> = ({
  isOpen,
  onClose,
  onSubmit,
}) => {
  const [isSubmitting, setIsSubmitting] = useState(false);
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

    setIsSubmitting(true);
    try {
      await onSubmit(formData);
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
      onClose();
    } catch (error) {
      // Error handling is done in the parent component
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleChange = (field: string, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && !isSubmitting && onClose()}>
      <DialogContent className="sm:max-w-lg bg-card rounded-none">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Package className="h-5 w-5" />
            Create Digital Twin
          </DialogTitle>
          <DialogDescription>
            Register a new equipment item. Each item must have a unique serial number.
          </DialogDescription>
        </DialogHeader>
        <form id="create-item-form" onSubmit={handleSubmit}>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="serial-number">Serial Number*</Label>
              <Input
                id="serial-number"
                value={formData.serialNumber}
                onChange={(e) => handleChange('serialNumber', e.target.value.toUpperCase())}
                placeholder="e.g., W123456 or 12345678"
                className="rounded-none font-mono"
                required
                disabled={isSubmitting}
              />
              <p className="text-xs text-muted-foreground">
                This must match the physical serial number on the equipment
              </p>
            </div>

            <div className="grid gap-2">
              <Label htmlFor="item-name">Item Name*</Label>
              <Input
                id="item-name"
                value={formData.name}
                onChange={(e) => handleChange('name', e.target.value)}
                placeholder="e.g., M4A1 Carbine, PRC-152 Radio"
                className="rounded-none"
                required
                disabled={isSubmitting}
              />
            </div>

            <div className="grid gap-2">
              <Label htmlFor="category">Category*</Label>
              <Select
                value={formData.category}
                onValueChange={(value) => handleChange('category', value)}
                disabled={isSubmitting}
              >
                <SelectTrigger id="category" className="rounded-none">
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
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="grid gap-2">
                <Label htmlFor="nsn">NSN (Optional)</Label>
                <Input
                  id="nsn"
                  value={formData.nsn}
                  onChange={(e) => handleChange('nsn', e.target.value)}
                  placeholder="1234-56-789-0123"
                  className="rounded-none font-mono"
                  disabled={isSubmitting}
                />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="lin">LIN (Optional)</Label>
                <Input
                  id="lin"
                  value={formData.lin}
                  onChange={(e) => handleChange('lin', e.target.value.toUpperCase())}
                  placeholder="A12345"
                  className="rounded-none font-mono"
                  disabled={isSubmitting}
                />
              </div>
            </div>

            <div className="grid gap-2">
              <Label htmlFor="description">Description (Optional)</Label>
              <Textarea
                id="description"
                value={formData.description}
                onChange={(e) => handleChange('description', e.target.value)}
                placeholder="Additional details about the item..."
                className="rounded-none resize-none"
                rows={3}
                disabled={isSubmitting}
              />
            </div>

            <div className="flex items-center space-x-2">
              <input
                type="checkbox"
                id="assign-to-self"
                checked={formData.assignToSelf}
                onChange={(e) => handleChange('assignToSelf', e.target.checked)}
                className="rounded-none"
                disabled={isSubmitting}
              />
              <Label htmlFor="assign-to-self" className="text-sm font-normal cursor-pointer">
                Assign this item to myself
              </Label>
            </div>
          </div>

          <DialogFooter className="mt-4">
            <Button 
              type="button" 
              variant="outline" 
              className="rounded-none" 
              onClick={onClose}
              disabled={isSubmitting}
            >
              Cancel
            </Button>
            <Button 
              type="submit" 
              variant="blue" 
              className="rounded-none" 
              disabled={isSubmitting}
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Creating...
                </>
              ) : (
                <>
                  <Plus className="h-4 w-4 mr-2" />
                  Create Digital Twin
                </>
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
};

export default CreateItemDialog; 