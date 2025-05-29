import React, { useState, useRef } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog';
import { useToast } from '@/hooks/use-toast';
import { Camera, Upload, QrCode, AlertTriangle, Loader2 } from 'lucide-react';
import { initiateTransferByQR } from '@/services/transferService';
import { parseQRCodeData } from '@/services/qrCodeService';

interface QRScannerProps {
  onScanComplete?: (transferId: string) => void;
  onClose?: () => void;
}

export const QRScanner: React.FC<QRScannerProps> = ({ onScanComplete, onClose }) => {
  const [isProcessing, setIsProcessing] = useState(false);
  const [scannedData, setScannedData] = useState<any>(null);
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { toast } = useToast();

  // Handle file upload for QR code image
  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    setIsProcessing(true);
    try {
      // Create a FileReader to read the image
      const reader = new FileReader();
      reader.onload = async (e) => {
        const imageData = e.target?.result as string;
        
        // In a real implementation, you'd use a QR code reader library like:
        // - @zxing/browser
        // - qr-scanner
        // - jsqr
        
        // For now, we'll simulate parsing the QR code
        // In production, you would decode the actual image data
        try {
          // Simulated QR data parsing - replace with actual QR decoder
          const mockQRString = JSON.stringify({
            type: "handreceipt_property",
            itemId: "123",
            serialNumber: "M4-12345",
            itemName: "M4 Carbine",
            category: "weapons",
            currentHolderId: "456",
            timestamp: new Date().toISOString(),
            qrHash: "abc123..."
          });

          // Parse and validate the QR data
          const parsedData = await parseQRCodeData(mockQRString);
          
          if (!parsedData) {
            throw new Error('Invalid QR code format or verification failed');
          }

          setScannedData(parsedData);
          setShowConfirmDialog(true);
        } catch (parseError) {
          toast({
            title: 'Invalid QR Code',
            description: 'Could not read or verify QR code data',
            variant: 'destructive',
          });
        }
      };
      
      reader.readAsDataURL(file);
    } catch (error) {
      toast({
        title: 'Scan Failed',
        description: 'Could not read QR code from image',
        variant: 'destructive',
      });
    } finally {
      setIsProcessing(false);
    }
  };

  // Handle QR code data after scanning
  const handleConfirmTransfer = async () => {
    if (!scannedData) return;

    setIsProcessing(true);
    try {
      const result = await initiateTransferByQR({
        qrData: scannedData,
        scannedAt: new Date().toISOString(),
      });

      toast({
        title: 'Transfer Initiated',
        description: `Transfer request created for ${scannedData.itemName}`,
      });

      setShowConfirmDialog(false);
      if (onScanComplete) {
        onScanComplete(result.transferId);
      }
      if (onClose) {
        onClose();
      }
    } catch (error: any) {
      toast({
        title: 'Transfer Failed',
        description: error?.message || 'Failed to initiate transfer',
        variant: 'destructive',
      });
    } finally {
      setIsProcessing(false);
    }
  };

  // Camera-based scanning placeholder
  const startCameraScanning = () => {
    toast({
      title: 'Camera Scanning',
      description: 'Camera-based QR scanning requires additional setup with WebRTC and QR decoder library',
    });
    // In production, you'd integrate with a camera-based QR scanner
    // Libraries like @zxing/browser or react-qr-reader could be used
    // This would involve:
    // 1. Requesting camera permissions
    // 2. Setting up video stream
    // 3. Continuously scanning frames for QR codes
    // 4. Parsing and validating found codes
  };

  const handleCancel = () => {
    setShowConfirmDialog(false);
    setScannedData(null);
    if (onClose) {
      onClose();
    }
  };

  return (
    <>
      <Card className="border-border shadow-none bg-card rounded-none">
        <CardHeader>
          <CardTitle className="text-lg font-normal">Scan QR Code</CardTitle>
          <CardDescription>
            Scan a property QR code to initiate a transfer request
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Upload QR Image Option */}
            <div className="space-y-2">
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={handleFileUpload}
                disabled={isProcessing}
              />
              <Button
                variant="outline"
                className="w-full h-24 flex flex-col items-center justify-center gap-2"
                onClick={() => fileInputRef.current?.click()}
                disabled={isProcessing}
              >
                {isProcessing ? (
                  <Loader2 className="h-8 w-8 animate-spin" />
                ) : (
                  <Upload className="h-8 w-8" />
                )}
                <span className="text-sm">
                  {isProcessing ? 'Processing...' : 'Upload QR Code Image'}
                </span>
              </Button>
              <p className="text-xs text-muted-foreground text-center">
                Take a photo of the QR code and upload it
              </p>
            </div>

            {/* Camera Scan Option */}
            <div className="space-y-2">
              <Button
                variant="outline"
                className="w-full h-24 flex flex-col items-center justify-center gap-2"
                onClick={startCameraScanning}
                disabled={isProcessing}
              >
                <Camera className="h-8 w-8" />
                <span className="text-sm">Scan with Camera</span>
              </Button>
              <p className="text-xs text-muted-foreground text-center">
                Use your device camera to scan directly
              </p>
            </div>
          </div>

          {/* Instructions */}
          <div className="mt-6 p-4 bg-muted/50 rounded-lg">
            <h4 className="text-sm font-medium mb-2 flex items-center gap-2">
              <QrCode className="h-4 w-4" />
              How to Scan
            </h4>
            <ol className="text-sm text-muted-foreground space-y-1 list-decimal list-inside">
              <li>Locate the QR code on the property item</li>
              <li>Either take a photo and upload, or use camera scan</li>
              <li>Confirm the transfer details</li>
              <li>The current holder will be notified to approve</li>
            </ol>
          </div>

          {/* Cancel Button */}
          {onClose && (
            <div className="flex justify-end pt-4">
              <Button variant="outline" onClick={onClose}>
                Cancel
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Confirmation Dialog */}
      <Dialog open={showConfirmDialog} onOpenChange={setShowConfirmDialog}>
        <DialogContent className="sm:max-w-[425px] rounded-none border-border shadow-none bg-card">
          <DialogHeader>
            <DialogTitle>Confirm Transfer Request</DialogTitle>
            <DialogDescription>
              Review the scanned property details before initiating transfer
            </DialogDescription>
          </DialogHeader>
          
          {scannedData && (
            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Item:</span>
                  <span className="font-medium">{scannedData.itemName}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Serial Number:</span>
                  <span className="font-mono">{scannedData.serialNumber}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Category:</span>
                  <span className="capitalize">{scannedData.category}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Current Holder:</span>
                  <span>User #{scannedData.currentHolderId}</span>
                </div>
              </div>

              <div className="p-3 bg-amber-50 dark:bg-amber-900/20 rounded-lg flex items-start gap-2">
                <AlertTriangle className="h-4 w-4 text-amber-600 dark:text-amber-400 mt-0.5" />
                <p className="text-sm text-amber-800 dark:text-amber-200">
                  A transfer request will be sent to the current property holder for approval.
                </p>
              </div>
            </div>
          )}

          <DialogFooter>
            <Button
              variant="outline"
              onClick={handleCancel}
              disabled={isProcessing}
            >
              Cancel
            </Button>
            <Button
              variant="blue"
              onClick={handleConfirmTransfer}
              disabled={isProcessing}
            >
              {isProcessing ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Processing...
                </>
              ) : (
                'Initiate Transfer'
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}; 