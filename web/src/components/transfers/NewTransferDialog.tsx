import React, { useState } from 'react';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Loader2, Send, Package, Hash, UserCheck, User, ArrowRight } from 'lucide-react';
import { cn } from '@/lib/utils';
import { CleanCard } from '@/components/ios';

interface NewTransferDialogProps {
  isOpen: boolean;
  currentUser: string;
  isPending: boolean;
  onClose: () => void;
  onSubmit: (data: { itemName: string; serialNumber: string; to: string }) => void;
}

// Enhanced form field component
const FormField: React.FC<{
  label: string;
  icon: React.ReactNode;
  children: React.ReactNode;
  required?: boolean;
}> = ({ label, icon, children, required }) => (
  <div className="space-y-2">
    <div className="flex items-center gap-2">
      <div className="p-1.5 bg-ios-accent/10 rounded-md">
        {icon}
      </div>
      <Label className="text-xs font-medium text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace]">
        {label}
        {required && <span className="text-ios-destructive ml-1">*</span>}
      </Label>
    </div>
    {children}
  </div>
);

const NewTransferDialog: React.FC<NewTransferDialogProps> = ({
  isOpen,
  currentUser,
  isPending,
  onClose,
  onSubmit,
}) => {
  const [formData, setFormData] = useState({
    itemName: '',
    serialNumber: '',
    to: ''
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit({
      itemName: formData.itemName || 'Unknown Item',
      serialNumber: formData.serialNumber || 'N/A',
      to: formData.to || 'Unknown Recipient',
    });
  };

  const handleClose = () => {
    setFormData({ itemName: '', serialNumber: '', to: '' });
    onClose();
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && handleClose()}>
      <DialogContent className="sm:max-w-lg bg-gradient-to-b from-white to-ios-tertiary-background/30 rounded-xl border-ios-border shadow-xl">
        <DialogHeader className="border-b border-ios-divider pb-4">
          <DialogTitle className="flex items-center gap-3">
            <div className="p-2.5 bg-gradient-to-br from-ios-accent to-ios-accent/80 rounded-lg shadow-sm">
              <Send className="h-5 w-5 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-semibold text-ios-primary-text">
                New Transfer Request
              </h2>
              <p className="text-xs text-ios-secondary-text mt-0.5">
                Initiate a transfer to reassign property to another user
              </p>
            </div>
          </DialogTitle>
        </DialogHeader>
        
        <form id="new-transfer-form" onSubmit={handleSubmit}>
          <div className="grid gap-6 py-6">
            {/* Item Information Section */}
            <div className="space-y-4">
              <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace] flex items-center gap-2">
                <div className="h-px flex-1 bg-ios-border" />
                <span>Item Details</span>
                <div className="h-px flex-1 bg-ios-border" />
              </h3>
              
              <FormField
                label="Item Name"
                icon={<Package className="h-4 w-4 text-ios-accent" />}
                required
              >
                <Input
                  id="item-name"
                  name="item-name"
                  value={formData.itemName}
                  onChange={(e) => setFormData({ ...formData, itemName: e.target.value })}
                  placeholder="e.g., M4A1 Carbine"
                  className="border-ios-border bg-ios-tertiary-background/50 rounded-lg h-12 text-base placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-ios-accent transition-all duration-200"
                  required
                />
              </FormField>
              
              <FormField
                label="Serial Number"
                icon={<Hash className="h-4 w-4 text-ios-accent" />}
                required
              >
                <Input
                  id="serial-number"
                  name="serial-number"
                  value={formData.serialNumber}
                  onChange={(e) => setFormData({ ...formData, serialNumber: e.target.value })}
                  placeholder="e.g., W123456"
                  className="border-ios-border bg-ios-tertiary-background/50 rounded-lg h-12 text-base placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-ios-accent transition-all duration-200 font-['Courier_New',_monospace]"
                  required
                />
              </FormField>
            </div>
            
            {/* Transfer Flow Section */}
            <div className="space-y-4">
              <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace] flex items-center gap-2">
                <div className="h-px flex-1 bg-ios-border" />
                <span>Transfer Details</span>
                <div className="h-px flex-1 bg-ios-border" />
              </h3>
              
              <CleanCard className="p-4 bg-gradient-to-r from-ios-tertiary-background/30 to-ios-tertiary-background/10">
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <FormField
                      label="From"
                      icon={<User className="h-4 w-4 text-ios-secondary-text" />}
                    >
                      <div className="text-sm font-semibold text-ios-primary-text mt-1">
                        {currentUser}
                      </div>
                    </FormField>
                  </div>
                  
                  <div className="px-6 py-4">
                    <ArrowRight className="h-5 w-5 text-ios-accent" />
                  </div>
                  
                  <div className="flex-1">
                    <FormField
                      label="To"
                      icon={<UserCheck className="h-4 w-4 text-ios-accent" />}
                      required
                    >
                      <Input
                        id="to"
                        name="to"
                        value={formData.to}
                        onChange={(e) => setFormData({ ...formData, to: e.target.value })}
                        placeholder="e.g., SFC Smith, Anna"
                        className="border-ios-border bg-white rounded-lg h-10 text-sm placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-ios-accent transition-all duration-200 mt-1"
                        required
                      />
                    </FormField>
                  </div>
                </div>
              </CleanCard>
            </div>
          </div>
          
          <DialogFooter className="gap-3 sm:gap-3">
            <Button
              type="button"
              variant="outline"
              className="border-ios-border hover:bg-ios-tertiary-background text-ios-secondary-text rounded-lg px-6 py-2.5 font-medium transition-all duration-200"
              onClick={handleClose}
              disabled={isPending}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              className="bg-ios-accent hover:bg-ios-accent/90 text-white rounded-lg px-6 py-2.5 font-medium shadow-sm transition-all duration-200 flex items-center gap-2"
              disabled={isPending}
            >
              {isPending ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  <span>Sending...</span>
                </>
              ) : (
                <>
                  <Send className="h-4 w-4" />
                  <span>Send Request</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
};

export default NewTransferDialog;