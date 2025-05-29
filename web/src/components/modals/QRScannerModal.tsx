import { useCallback, useEffect, useRef, useState } from "react";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { scanQRCode, stopScanner } from "@/lib/qrScanner";
import { parseQRCodeData, initiateTransferByQR, QRCodeData } from "@/services/qrCodeService";
import { useQueryClient } from "@tanstack/react-query";
import { Loader2 } from "lucide-react";

interface QRScannerModalProps {
  isOpen: boolean;
  onClose: () => void;
  onTransferInitiated?: (transferId: string) => void;
}

const QRScannerModal: React.FC<QRScannerModalProps> = ({
  isOpen, 
  onClose,
  onTransferInitiated
}) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [status, setStatus] = useState<"waiting" | "scanning" | "success" | "error">("waiting");
  const [scannedData, setScannedData] = useState<string | null>(null);
  const [parsedData, setParsedData] = useState<QRCodeData | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const handleScanSuccess = useCallback(async (result: string) => {
    setStatus("success");
    setScannedData(result);
    
    try {
      const data = await parseQRCodeData(result);
      if (data) {
        setParsedData(data);
        toast({
          title: "QR Code Scanned",
          description: "Equipment information retrieved successfully.",
        });
      } else {
        toast({
          title: "Invalid QR Code",
          description: "This QR code is not a valid HandReceipt property code.",
          variant: "destructive"
        });
        setStatus("error");
      }
    } catch (e) {
      console.error("Failed to parse QR code data:", e);
      setParsedData(null);
      setStatus("error");
    }
  }, [toast]);

  const handleScanError = useCallback((error: Error) => {
    console.error("QR scanning error:", error);
    setStatus("error");
    toast({
      title: "Scanning Error",
      description: error.message,
      variant: "destructive"
    });
  }, [toast]);

  useEffect(() => {
    if (isOpen && videoRef.current) {
      setStatus("scanning");
      scanQRCode(
        videoRef.current,
        handleScanSuccess,
        handleScanError
      );
    }

    return () => {
      stopScanner();
    };
  }, [isOpen, handleScanSuccess, handleScanError]);

  const handleInitiateTransfer = async () => {
    if (!parsedData) return;
    
    setIsProcessing(true);
    try {
      const result = await initiateTransferByQR(parsedData);
      
      // Invalidate queries to refresh data
      queryClient.invalidateQueries({ queryKey: ['transfers'] });
      queryClient.invalidateQueries({ queryKey: ['inventory'] });
      
      toast({
        title: "Transfer Initiated",
        description: `Transfer request for ${parsedData.itemName} has been sent to the current holder.`,
      });
      
      if (onTransferInitiated) {
        onTransferInitiated(result.transferId);
      }
      
      onClose();
    } catch (error: any) {
      toast({
        title: "Transfer Failed",
        description: error.message || "Failed to initiate transfer. Please try again.",
        variant: "destructive"
      });
    } finally {
      setIsProcessing(false);
    }
  };

  const handleReportIssue = () => {
    toast({
      title: "Issue Reported",
      description: "Your issue has been reported to the property administrator.",
    });
    onClose();
  };

  const handleRescan = () => {
    setStatus("waiting");
    setScannedData(null);
    setParsedData(null);
    
    if (videoRef.current) {
      setStatus("scanning");
      scanQRCode(
        videoRef.current,
        handleScanSuccess,
        handleScanError
      );
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Scan Equipment QR Code</DialogTitle>
          <DialogDescription>
            Position the QR code in the center of the camera view to initiate a transfer request.
          </DialogDescription>
        </DialogHeader>
        
        <div className="flex flex-col items-center space-y-4">
          {status === "scanning" || status === "waiting" ? (
            <>
              <div className="relative border border-gray-300 rounded-md overflow-hidden aspect-video w-full">
                <video 
                  ref={videoRef} 
                  className="w-full h-full object-cover" 
                  autoPlay 
                  playsInline
                  muted
                />
                <div className="absolute inset-0 border-2 border-[#4B5320] opacity-50 m-8 pointer-events-none"></div>
                <div className="absolute top-0 left-0 right-0 bg-[#1C2541] text-white text-center text-xs py-1">
                  Camera active
                </div>
              </div>
              <p className="text-sm text-center text-gray-500">
                {status === "waiting" ? "Initializing camera..." : "Scanning for QR code..."}
              </p>
            </>
          ) : status === "success" && parsedData ? (
            <div className="border rounded-md p-4 w-full bg-gray-50">
              <h3 className="font-medium mb-2">Equipment Information</h3>
              <div className="space-y-2">
                <div className="flex justify-between">
                  <span className="text-gray-500">Item:</span>
                  <span className="font-medium">{parsedData.itemName}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-500">Serial Number:</span>
                  <span className="font-mono text-sm">{parsedData.serialNumber}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-500">Category:</span>
                  <span className="capitalize">{parsedData.category.replace(/-/g, ' ')}</span>
                </div>
                {parsedData.currentHolderId && (
                  <div className="flex justify-between">
                    <span className="text-gray-500">Current Holder:</span>
                    <span className="text-xs">User #{parsedData.currentHolderId}</span>
                  </div>
                )}
                <div className="flex justify-between">
                  <span className="text-gray-500">QR Generated:</span>
                  <span className="text-xs">{new Date(parsedData.timestamp).toLocaleString()}</span>
                </div>
              </div>
              
              <div className="mt-4 p-3 bg-blue-50 border border-blue-200 rounded">
                <p className="text-sm text-blue-800">
                  <strong>Transfer Request:</strong> Scanning this code will send a transfer request to the current property holder.
                </p>
              </div>
            </div>
          ) : (
            <div className="text-center py-8">
              <i className="fas fa-exclamation-triangle text-yellow-500 text-4xl mb-4"></i>
              <p className="text-gray-700">
                {status === "error" ? "Failed to scan valid QR code. Please try again." : "Invalid or corrupted QR code."}
              </p>
            </div>
          )}
          
          <div className="flex justify-center space-x-2 w-full">
            {status === "success" && parsedData ? (
              <>
                <Button variant="outline" onClick={handleRescan} className="flex-1">
                  <i className="fas fa-redo-alt mr-2"></i> Scan Another
                </Button>
                <Button 
                  onClick={handleInitiateTransfer}
                  disabled={isProcessing}
                  className="bg-[#4B5320] hover:bg-[#3a4019] flex-1"
                >
                  {isProcessing ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin mr-2" />
                      Processing...
                    </>
                  ) : (
                    <>
                      <i className="fas fa-exchange-alt mr-2"></i> Request Transfer
                    </>
                  )}
                </Button>
              </>
            ) : status === "error" ? (
              <>
                <Button variant="outline" onClick={handleRescan} className="flex-1">
                  <i className="fas fa-redo-alt mr-2"></i> Try Again
                </Button>
                <Button 
                  variant="outline" 
                  onClick={handleReportIssue}
                  className="text-red-500 flex-1"
                >
                  <i className="fas fa-exclamation-circle mr-2"></i> Report Issue
                </Button>
              </>
            ) : (
              <Button variant="outline" onClick={onClose} className="flex-1">
                Cancel
              </Button>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default QRScannerModal;