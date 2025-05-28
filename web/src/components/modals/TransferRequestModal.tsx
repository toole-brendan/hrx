import { useState } from "react";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";

interface TransferRequestModalProps {
  isOpen: boolean;
  onClose: () => void;
  itemName: string;
  serialNumber: string;
}

const TransferRequestModal: React.FC<TransferRequestModalProps> = ({
  isOpen,
  onClose,
  itemName,
  serialNumber
}) => {
  const [transferType, setTransferType] = useState<"individual" | "unit">("individual");
  const [recipient, setRecipient] = useState("");
  const [reason, setReason] = useState("");
  const [urgency, setUrgency] = useState("normal");
  const { toast } = useToast();

  // Mock data for dropdown options
  const recentTransferRecipients = [
    { id: "1", name: "SGT James Wilson" },
    { id: "2", name: "CPT Sarah Johnson" },
    { id: "3", name: "SPC Michael Rodriguez" },
    { id: "4", name: "2LT Thomas Brown" }
  ];

  const unitOptions = [
    { id: "1", name: "Alpha Company, 2-506 IN" },
    { id: "2", name: "Bravo Company, 2-506 IN" },
    { id: "3", name: "Charlie Company, 2-506 IN" },
    { id: "4", name: "HHC, 2-506 IN" }
  ];

  const handleSubmit = () => {
    // In a real app, this would make an API call to submit the transfer request
    toast({
      title: "Transfer Request Submitted",
      description: `Request to transfer ${itemName} to ${recipient} has been submitted for approval.`
    });
    onClose();

    // Reset form
    setTransferType("individual");
    setRecipient("");
    setReason("");
    setUrgency("normal");
  };

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md">
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
              value={itemName}
              readOnly
              className="col-span-3"
            />
          </div>
          
          <div className="grid grid-cols-4 items-center gap-4">
            <Label htmlFor="serial-number" className="text-right">
              Serial #
            </Label>
            <Input
              id="serial-number"
              value={serialNumber}
              readOnly
              className="col-span-3 font-mono"
            />
          </div>

          <div className="space-y-2">
            <Label>Transfer to</Label>
            <RadioGroup 
              value={transferType} 
              onValueChange={(value) => setTransferType(value as "individual" | "unit")}
              className="flex space-x-4"
            >
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="individual" id="individual" />
                <Label htmlFor="individual">Individual</Label>
              </div>
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="unit" id="unit" />
                <Label htmlFor="unit">Unit</Label>
              </div>
            </RadioGroup>
          </div>

          {transferType === "individual" ? (
            <div className="grid gap-2">
              <Label htmlFor="recipient">Recipient</Label>
              <Select onValueChange={setRecipient}>
                <SelectTrigger>
                  <SelectValue placeholder="Select recipient" />
                </SelectTrigger>
                <SelectContent>
                  {recentTransferRecipients.map((person) => (
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
              <Select onValueChange={setRecipient}>
                <SelectTrigger>
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

          <div className="grid gap-2">
            <Label htmlFor="reason">Reason for Transfer</Label>
            <Textarea
              id="reason"
              placeholder="Provide reason for transfer"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              className="resize-none"
              rows={3}
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="urgency">Urgency</Label>
            <Select value={urgency} onValueChange={setUrgency}>
              <SelectTrigger>
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
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button 
            onClick={handleSubmit} 
            className="bg-[#4B5320] hover:bg-[#3a4019]"
            disabled={!recipient || !reason}
          >
            Submit Request
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

export default TransferRequestModal;