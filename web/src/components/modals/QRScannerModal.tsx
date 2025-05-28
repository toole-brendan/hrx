import { useCallback, useEffect, useRef, useState } from "react";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { scanQRCode, stopScanner } from "@/lib/qrScanner";

interface QRScannerModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const QRScannerModal: React.FC<QRScannerModalProps> = ({
  isOpen, 
  onClose
}) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [status, setStatus] = useState<"waiting" | "scanning" | "success" | "error">("waiting");
  const [scannedData, setScannedData] = useState<string | null>(null);
  const [parsedData, setParsedData] = useState<any>(null);
  const { toast } = useToast();

  const handleScanSuccess = useCallback((result: string) => {
    setStatus("success");
    setScannedData(result);
    
    try {
      const data = JSON.parse(result);
      setParsedData(data);
    } catch (e) {
      console.error("Failed to parse QR code data:", e);
      setParsedData(null);
    }

    toast({
      title: "QR Code Scanned",
      description: "Equipment information retrieved successfully.",
    });
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

  const handleProcessEquipment = () => {
    if (parsedData) {
      toast({
        title: "Equipment Processed",
        description: `${parsedData.name} has been processed successfully.`,
      });
    }
    onClose();
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
            Position the QR code in the center of the camera view.
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
          ) : status === "success" ? (
            <div className="border rounded-md p-4 w-full bg-gray-50">
              <h3 className="font-medium mb-2">Equipment Information</h3>
              {parsedData ? (
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-gray-500">Type:</span>
                    <span className="font-medium">{parsedData.type || "Unknown"}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">Name:</span>
                    <span className="font-medium">{parsedData.name || "Unknown"}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">Serial Number:</span>
                    <span className="font-mono text-sm">{parsedData.serialNumber || "Unknown"}</span>
                  </div>
                  {parsedData.additionalInfo && (
                    <div className="flex justify-between">
                      <span className="text-gray-500">Notes:</span>
                      <span>{parsedData.additionalInfo}</span>
                    </div>
                  )}
                  <div className="flex justify-between">
                    <span className="text-gray-500">Timestamp:</span>
                    <span className="text-xs">{new Date(parsedData.timestamp).toLocaleString()}</span>
                  </div>
                </div>
              ) : (
                <p className="text-sm text-gray-500">
                  Unable to parse equipment data from QR code.
                </p>
              )}
            </div>
          ) : (
            <div className="text-center py-8">
              <i className="fas fa-exclamation-triangle text-yellow-500 text-4xl mb-4"></i>
              <p className="text-gray-700">Failed to scan QR code. Please try again.</p>
            </div>
          )}
          
          <div className="flex justify-center space-x-2 w-full">
            {status === "success" ? (
              <>
                <Button variant="outline" onClick={handleRescan} className="flex-1">
                  <i className="fas fa-redo-alt mr-2"></i> Scan Again
                </Button>
                <Button 
                  onClick={handleProcessEquipment}
                  className="bg-[#4B5320] hover:bg-[#3a4019] flex-1"
                >
                  <i className="fas fa-check mr-2"></i> Process
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