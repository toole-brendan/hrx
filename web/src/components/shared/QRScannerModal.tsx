import React, { useRef, useEffect, useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { scanQRCode, stopScanner } from '@/lib/qrScanner';
import { useToast } from '@/hooks/use-toast';

interface QRScannerModalProps {
  isOpen: boolean;
  onClose: () => void;
  onScan?: (code: string) => void;
}

const QRScannerModal: React.FC<QRScannerModalProps> = ({ 
  isOpen, 
  onClose,
  onScan 
}) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [error, setError] = useState<string | null>(null);
  const [scanning, setScanning] = useState(false);
  const { toast } = useToast();

  // Start scanning when the modal opens
  useEffect(() => {
    let scannerTimeout: NodeJS.Timeout;
    
    if (isOpen && videoRef.current) {
      setScanning(true);
      setError(null);
      
      // Add a slight delay to ensure the video element is fully mounted
      scannerTimeout = setTimeout(() => {
        startScanning();
      }, 500);
    }
    
    return () => {
      clearTimeout(scannerTimeout);
      stopScanner();
      setScanning(false);
    };
  }, [isOpen]);

  const startScanning = async () => {
    if (!videoRef.current) return;
    
    try {
      await scanQRCode(
        videoRef.current,
        (result) => {
          setScanning(false);
          toast({
            title: "QR Code Scanned",
            description: `Successfully scanned: ${result}`,
          });
          if (onScan) {
            onScan(result);
          }
          onClose();
        },
        (error) => {
          console.error('Scanner error:', error);
          setError(error.message);
          setScanning(false);
        }
      );
    } catch (err) {
      console.error('Failed to start scanner:', err);
      setError(err instanceof Error ? err.message : 'Failed to access camera');
      setScanning(false);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Scan QR Code</DialogTitle>
        </DialogHeader>

        <div className="relative w-full aspect-square bg-gray-100 dark:bg-gray-800 rounded-md overflow-hidden">
          {error ? (
            <Alert variant="destructive" className="absolute inset-0 m-auto flex items-center justify-center h-auto">
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          ) : (
            <>
              <video 
                ref={videoRef} 
                className="h-full w-full object-cover"
              />
              
              {scanning && (
                <div className="absolute inset-0 flex items-center justify-center">
                  <div className="w-48 h-48 border-2 border-dashed border-primary rounded-md animate-pulse"></div>
                </div>
              )}
            </>
          )}
        </div>
        
        <p className="text-center text-sm text-muted-foreground">
          Position the QR code within the scanning area
        </p>

        <DialogFooter className="flex space-x-2 justify-end">
          {error ? (
            <Button onClick={startScanning}>
              Try Again
            </Button>
          ) : (
            <Button variant="outline" onClick={onClose}>
              Cancel
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

export default QRScannerModal;