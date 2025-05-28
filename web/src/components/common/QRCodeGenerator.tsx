import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useToast } from "@/hooks/use-toast";
import { QrCode, Printer, AlertTriangle } from "lucide-react";

interface QRCodeGeneratorProps {
  itemName: string;
  serialNumber: string;
  onGenerate?: (qrValue: string) => void;
}

/**
 * Component for generating QR codes for equipment items
 */
const QRCodeGenerator: React.FC<QRCodeGeneratorProps> = ({ 
  itemName, 
  serialNumber,
  onGenerate 
}) => {
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [qrImage, setQrImage] = useState<string | null>(null);
  const [additionalInfo, setAdditionalInfo] = useState("");
  const { toast } = useToast();

  // This would normally use a real QR code generation library
  const generateQRCode = () => {
    // Mock QR code generation - in a real app, we would use a library like qrcode.react
    const qrValue = JSON.stringify({
      type: "military_equipment",
      name: itemName,
      serialNumber: serialNumber,
      additionalInfo: additionalInfo || undefined,
      timestamp: new Date().toISOString()
    });
    
    // Mock SVG for QR code visualization
    const mockQrSvg = `
      <svg width="200" height="200" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <rect width="200" height="200" fill="white" />
        <g fill="#1C2541">
          ${Array.from({ length: 8 }).map((_, i) => 
            Array.from({ length: 8 }).map((_, j) => 
              Math.random() > 0.5 ? 
              `<rect x="${i*20}" y="${j*20}" width="20" height="20" />` : ''
            ).join('')
          ).join('')}
        </g>
        <rect x="60" y="60" width="80" height="80" fill="white" />
        <text x="100" y="100" text-anchor="middle" dominant-baseline="middle" font-size="12" fill="#6941C6">${serialNumber}</text>
      </svg>
    `;

    setQrImage(`data:image/svg+xml;base64,${btoa(mockQrSvg)}`);
    
    if (onGenerate) {
      onGenerate(qrValue);
    }
    
    toast({
      title: "QR Code Generated",
      description: `QR code for ${itemName} has been generated successfully.`
    });
  };

  const handlePrint = () => {
    toast({
      title: "Printing QR Code",
      description: "The QR code has been sent to the printer."
    });
    // In a real app, we would handle printing logic here
  };

  const handleReport = () => {
    toast({
      title: "QR Code Issue Reported",
      description: "Your report has been submitted. A new QR code will be issued."
    });
    setIsDialogOpen(false);
  };

  return (
    <>
      <Button 
        size="icon"
        variant="ghost"
        className="h-8 w-8 text-gray-400 hover:text-purple-600 hover:bg-purple-50 dark:hover:bg-purple-900/20 dark:text-gray-500 dark:hover:text-purple-400"
        onClick={() => setIsDialogOpen(true)}
        title="Generate QR Code"
      >
        <QrCode className="h-4 w-4" />
      </Button>
      
      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
        <DialogContent className="sm:max-w-md bg-white dark:bg-black border-gray-200 dark:border-white/10 rounded-none">
          <DialogHeader className="border-b border-gray-200 dark:border-white/10 pb-4">
            <div className="text-xs uppercase tracking-wider font-medium mb-1 text-muted-foreground">
              QR CODE GENERATOR
            </div>
            <DialogTitle className="font-normal text-xl tracking-tight">Generate Equipment QR Code</DialogTitle>
            <DialogDescription className="text-sm tracking-wide text-muted-foreground mt-1">
              Create a QR code for tracking and transferring this equipment item.
            </DialogDescription>
          </DialogHeader>
          
          <div className="py-4 space-y-4">
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="name" className="text-xs uppercase tracking-wider text-muted-foreground text-right">Item</Label>
              <Input 
                id="name" 
                value={itemName} 
                readOnly 
                className="col-span-3 rounded-none bg-white dark:bg-black border-gray-200 dark:border-white/10" 
              />
            </div>
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="serial" className="text-xs uppercase tracking-wider text-muted-foreground text-right">Serial #</Label>
              <Input 
                id="serial" 
                value={serialNumber} 
                readOnly 
                className="col-span-3 font-mono rounded-none bg-white dark:bg-black border-gray-200 dark:border-white/10" 
              />
            </div>
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="notes" className="text-xs uppercase tracking-wider text-muted-foreground text-right">Notes</Label>
              <Input 
                id="notes" 
                placeholder="Additional information" 
                value={additionalInfo}
                onChange={(e) => setAdditionalInfo(e.target.value)}
                className="col-span-3 rounded-none bg-white dark:bg-black border-gray-200 dark:border-white/10" 
              />
            </div>
          </div>
          
          {!qrImage ? (
            <div className="flex justify-center py-4">
              <Button 
                onClick={generateQRCode}
                className="bg-primary hover:bg-primary-600 text-white rounded-none h-9 px-4 text-xs uppercase tracking-wider"
              >
                Generate QR Code
              </Button>
            </div>
          ) : (
            <Card className="rounded-none border border-gray-100 dark:border-white/5 bg-white dark:bg-black">
              <CardContent className="p-4 flex flex-col items-center">
                <img src={qrImage} alt="QR Code for equipment" className="mb-4 max-w-[200px]" />
                <div className="text-xs text-center mb-4">
                  <p className="font-medium uppercase tracking-wider">{itemName}</p>
                  <p className="font-mono text-muted-foreground">{serialNumber}</p>
                </div>
                <div className="flex space-x-4">
                  <Button 
                    size="sm"
                    variant="outline"
                    onClick={handlePrint}
                    className="rounded-none text-xs uppercase tracking-wider flex items-center gap-2 border-gray-200 dark:border-white/10"
                  >
                    <Printer className="h-3.5 w-3.5" />
                    Print
                  </Button>
                  <Button 
                    size="sm"
                    variant="outline"
                    onClick={handleReport}
                    className="rounded-none text-xs uppercase tracking-wider flex items-center gap-2 text-red-500 dark:text-red-400 border-red-200 dark:border-red-900/30"
                  >
                    <AlertTriangle className="h-3.5 w-3.5" />
                    Report
                  </Button>
                </div>
              </CardContent>
            </Card>
          )}
          
          <DialogFooter className="border-t border-gray-200 dark:border-white/10 pt-4">
            <Button 
              size="sm"
              variant="outline"
              onClick={() => setIsDialogOpen(false)}
              className="rounded-none text-xs uppercase tracking-wider border-gray-200 dark:border-white/10"
            >
              Close
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
};

export default QRCodeGenerator;