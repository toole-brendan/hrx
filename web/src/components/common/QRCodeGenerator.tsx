import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useToast } from "@/hooks/use-toast";
import { QrCode, Printer, AlertTriangle, Loader2 } from "lucide-react";
import { generateQRCodeData } from "@/services/qrCodeService";
import QRCode from 'qrcode';

interface QRCodeGeneratorProps {
  itemId: string;
  itemName: string;
  serialNumber: string;
  category: string;
  assignedUserId?: string;
  onGenerate?: (qrValue: string) => void;
}

/**
 * Component for generating QR codes for equipment items
 */
const QRCodeGenerator: React.FC<QRCodeGeneratorProps> = ({ 
  itemId,
  itemName, 
  serialNumber,
  category,
  assignedUserId,
  onGenerate 
}) => {
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [qrImage, setQrImage] = useState<string | null>(null);
  const [additionalInfo, setAdditionalInfo] = useState("");
  const [isGenerating, setIsGenerating] = useState(false);
  const { toast } = useToast();

  const generateQRCode = async () => {
    setIsGenerating(true);
    try {
      // Generate QR code data with hash
      const qrData = await generateQRCodeData({
        id: itemId,
        serialNumber,
        name: itemName,
        category,
        assignedUserId,
      });
      
      // Add any additional info
      const qrDataWithInfo = {
        ...qrData,
        additionalInfo: additionalInfo || undefined,
      };
      
      const qrValue = JSON.stringify(qrDataWithInfo);
      
      // Generate QR code image using qrcode library
      const qrImageUrl = await QRCode.toDataURL(qrValue, {
        width: 300,
        margin: 2,
        color: {
          dark: '#1C2541',
          light: '#FFFFFF',
        },
      });
      
      setQrImage(qrImageUrl);
      
      if (onGenerate) {
        onGenerate(qrValue);
      }
      
      toast({
        title: "QR Code Generated",
        description: `QR code for ${itemName} has been generated successfully.`
      });
    } catch (error) {
      console.error('Failed to generate QR code:', error);
      toast({
        title: "Generation Failed",
        description: "Failed to generate QR code. Please try again.",
        variant: "destructive"
      });
    } finally {
      setIsGenerating(false);
    }
  };

  const handlePrint = () => {
    if (!qrImage) return;
    
    // Create a new window for printing
    const printWindow = window.open('', '_blank');
    if (!printWindow) {
      toast({
        title: "Print Failed",
        description: "Unable to open print window. Please check your popup settings.",
        variant: "destructive"
      });
      return;
    }
    
    // Create print content
    printWindow.document.write(`
      <html>
        <head>
          <title>Print QR Code - ${itemName}</title>
          <style>
            body { 
              font-family: Arial, sans-serif; 
              text-align: center; 
              padding: 20px;
            }
            .qr-container {
              border: 2px solid #000;
              padding: 20px;
              display: inline-block;
              margin: 20px auto;
            }
            .item-name { 
              font-size: 18px; 
              font-weight: bold; 
              margin-bottom: 10px;
            }
            .serial-number { 
              font-family: monospace; 
              font-size: 14px; 
              margin-bottom: 20px;
            }
            .qr-code img { 
              max-width: 300px; 
              height: auto; 
            }
            .instructions {
              margin-top: 20px;
              font-size: 12px;
              color: #666;
            }
            @media print {
              body { margin: 0; }
            }
          </style>
        </head>
        <body>
          <div class="qr-container">
            <div class="item-name">${itemName}</div>
            <div class="serial-number">SN: ${serialNumber}</div>
            <div class="qr-code">
              <img src="${qrImage}" alt="QR Code" />
            </div>
            <div class="instructions">
              Affix this QR code to the equipment item.<br>
              Only the current property holder can generate new codes.
            </div>
          </div>
          <script>
            window.onload = function() { 
              window.print(); 
              window.onafterprint = function() { window.close(); }
            }
          </script>
        </body>
      </html>
    `);
    
    printWindow.document.close();
    
    toast({
      title: "Printing QR Code",
      description: "The QR code has been sent to the printer."
    });
  };

  const handleReport = () => {
    toast({
      title: "QR Code Issue Reported",
      description: "Your report has been submitted. A new QR code will be issued."
    });
    setIsDialogOpen(false);
  };

  // Reset state when dialog opens
  useEffect(() => {
    if (isDialogOpen) {
      setQrImage(null);
      setAdditionalInfo("");
    }
  }, [isDialogOpen]);

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
                placeholder="Additional information (optional)" 
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
                disabled={isGenerating}
                className="bg-primary hover:bg-primary-600 text-white rounded-none h-9 px-4 text-xs uppercase tracking-wider"
              >
                {isGenerating ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin mr-2" />
                    Generating...
                  </>
                ) : (
                  'Generate QR Code'
                )}
              </Button>
            </div>
          ) : (
            <Card className="rounded-none border border-gray-100 dark:border-white/5 bg-white dark:bg-black">
              <CardContent className="p-4 flex flex-col items-center">
                <img src={qrImage} alt="QR Code for equipment" className="mb-4 max-w-[300px]" />
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