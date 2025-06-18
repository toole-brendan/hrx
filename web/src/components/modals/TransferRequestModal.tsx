import { useState } from "react";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";
import { useToast } from "@/hooks/use-toast";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { createTransfer } from "@/services/transferService";
import { Property } from "@/types";
import { Loader2, Link2 } from "lucide-react";

interface TransferRequestModalProps {
  isOpen: boolean;
  onClose: () => void;
  item: Property;
  onTransferSuccess?: () => void;
}

const TransferRequestModal: React.FC<TransferRequestModalProps> = ({
  isOpen,
  onClose,
  item,
  onTransferSuccess
}) => {
  const [transferType, setTransferType] = useState<"individual" | "unit">("individual");
  const [recipient, setRecipient] = useState("");
  const [includeComponents, setIncludeComponents] = useState(false);
  const [reason, setReason] = useState("");
  const [urgency, setUrgency] = useState("normal");
  const { toast } = useToast();
  const queryClient = useQueryClient();

  // TODO: These should come from API calls to get user connections and available units
  // Mock data for dropdown options - in production, these would come from an API
  const mockConnections: { id: string; name: string }[] = [];
  const unitOptions: { id: string; name: string }[] = [];

  // Create transfer mutation
  const createTransferMutation = useMutation({
    mutationFn: createTransfer,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transfers'] });
      queryClient.invalidateQueries({ queryKey: ['property'] });
      
      toast({
        title: "Transfer Request Submitted",
        description: `Request to transfer ${item.name} to ${recipient} has been submitted for approval.`
      });

      // Reset form
      setTransferType("individual");
      setRecipient("");
      setIncludeComponents(false);
      setReason("");
      setUrgency("normal");

      onTransferSuccess?.();
      onClose();
    },
    onError: (error: any) => {
      toast({
        title: "Transfer Request Failed",
        description: error.message || "Failed to submit transfer request. Please try again.",
        variant: "destructive"
      });
    }
  });

  const handleSubmit = () => {
    if (!recipient || !reason) {
      toast({
        title: "Missing Information",
        description: "Please select a recipient and provide a reason for the transfer.",
        variant: "destructive"
      });
      return;
    }

    // In production, you would look up the actual user ID from the selected recipient
    // For now, we'll use a placeholder
    const recipientUserId = 2; // This should be looked up based on the recipient name

    createTransferMutation.mutate({
      propertyId: parseInt(item.id),
      toUserId: recipientUserId,
      includeComponents: includeComponents,
      notes: `${reason}\n\nUrgency: ${urgency}\nTransfer Type: ${transferType}`,
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && !createTransferMutation.isPending && onClose()}>
      <DialogContent className="sm:max-w-md bg-card rounded-none">
        <DialogHeader>
          <DialogTitle>Transfer Request</DialogTitle>
          <DialogDescription>
            Request to transfer equipment to another individual or unit.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-4 py-4">
          <div className="grid grid-cols-4 items-center gap-4">
            <Label htmlFor="item-name" className="text-right">
              Item
            </Label>
            <Input
              id="item-name"
              value={item.name}
              readOnly
              className="col-span-3 rounded-none"
            />
          </div>
          
          <div className="grid grid-cols-4 items-center gap-4">
            <Label htmlFor="serial-number" className="text-right">
              Serial #
            </Label>
            <Input
              id="serial-number"
              value={item.serialNumber}
              readOnly
              className="col-span-3 font-mono rounded-none"
            />
          </div>

          <div className="space-y-2">
            <Label>Transfer to</Label>
            <RadioGroup 
              value={transferType} 
              onValueChange={(value) => setTransferType(value as "individual" | "unit")}
              className="flex space-x-4"
              disabled={createTransferMutation.isPending}
            >
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="individual" id="individual" />
                <Label htmlFor="individual" className="cursor-pointer">Individual</Label>
              </div>
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="unit" id="unit" />
                <Label htmlFor="unit" className="cursor-pointer">Unit</Label>
              </div>
            </RadioGroup>
          </div>

          {transferType === "individual" ? (
            <div className="grid gap-2">
              <Label htmlFor="recipient">Recipient</Label>
              <Select 
                onValueChange={setRecipient} 
                disabled={createTransferMutation.isPending}
              >
                <SelectTrigger className="rounded-none">
                  <SelectValue placeholder="Select recipient" />
                </SelectTrigger>
                <SelectContent>
                  {mockConnections.map((person) => (
                    <SelectItem key={person.id} value={person.name}>
                      {person.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          ) : (
            <div className="grid gap-2">
              <Label htmlFor="unit">Unit</Label>
              <Select 
                onValueChange={setRecipient}
                disabled={createTransferMutation.isPending}
              >
                <SelectTrigger className="rounded-none">
                  <SelectValue placeholder="Select unit" />
                </SelectTrigger>
                <SelectContent>
                  {unitOptions.map((unit) => (
                    <SelectItem key={unit.id} value={unit.name}>
                      {unit.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          )}

          {/* Include Components Option */}
          {item.components && item.components.length > 0 && (
            <div className="flex items-center space-x-2">
                             <Checkbox
                 id="include-components"
                 checked={includeComponents}
                 onCheckedChange={(checked) => setIncludeComponents(checked === true)}
                 disabled={createTransferMutation.isPending}
               />
              <Label htmlFor="include-components" className="flex items-center gap-2 cursor-pointer">
                <Link2 className="w-4 h-4" />
                Include attached components ({item.components.length})
              </Label>
            </div>
          )}

          <div className="grid gap-2">
            <Label htmlFor="reason">Reason for Transfer</Label>
            <Textarea
              id="reason"
              placeholder="Provide reason for transfer"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              className="resize-none rounded-none"
              rows={3}
              disabled={createTransferMutation.isPending}
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="urgency">Urgency</Label>
            <Select 
              value={urgency} 
              onValueChange={setUrgency}
              disabled={createTransferMutation.isPending}
            >
              <SelectTrigger className="rounded-none">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="low">Low - No rush</SelectItem>
                <SelectItem value="normal">Normal</SelectItem>
                <SelectItem value="high">High - Required soon</SelectItem>
                <SelectItem value="critical">Critical - Required immediately</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>

        <DialogFooter>
          <Button 
            variant="outline" 
            onClick={onClose}
            disabled={createTransferMutation.isPending}
            className="rounded-none"
          >
            Cancel
          </Button>
          <Button 
            onClick={handleSubmit} 
            className="bg-[#4B5320] hover:bg-[#3a4019] rounded-none"
            disabled={!recipient || !reason || createTransferMutation.isPending}
          >
            {createTransferMutation.isPending ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Submitting...
              </>
            ) : (
              'Submit Request'
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

export default TransferRequestModal;