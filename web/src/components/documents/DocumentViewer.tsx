import React from 'react';
import * as DialogPrimitive from "@radix-ui/react-dialog";
import { Dialog, DialogHeader, DialogTitle, DialogPortal, DialogOverlay } from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { FileText, User, Calendar, Paperclip, Download, Forward, Printer, Upload, X } from 'lucide-react';
import { format } from 'date-fns';
import { Document } from '@/services/documentService';
import { ProgressiveImage } from '@/components/ui/ProgressiveImage';
import { cn } from '@/lib/utils';

interface DocumentViewerProps {
  document: Document;
  open: boolean;
  onClose: () => void;
}

// Custom DialogContent without the close button
const DialogContentNoClose = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Content>
>(({ className, children, ...props }, ref) => (
  <DialogPortal>
    <DialogOverlay />
    <DialogPrimitive.Content
      ref={ref}
      className={cn(
        "fixed left-[50%] top-[50%] z-50 grid w-full max-w-lg translate-x-[-50%] translate-y-[-50%] gap-4 border bg-background p-6 shadow-lg duration-200 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[state=closed]:slide-out-to-left-1/2 data-[state=closed]:slide-out-to-top-[48%] data-[state=open]:slide-in-from-left-1/2 data-[state=open]:slide-in-from-top-[48%] sm:rounded-lg",
        className
      )}
      {...props}
    >
      {children}
    </DialogPrimitive.Content>
  </DialogPortal>
));
DialogContentNoClose.displayName = "DialogContentNoClose";

export const DocumentViewer: React.FC<DocumentViewerProps> = ({ document, open, onClose }) => {
  let formData: any = {};
  let attachments: string[] = [];
  
  // Safely parse formData
  try {
    if (document.formData && document.formData.trim() !== '') {
      formData = JSON.parse(document.formData);
    }
  } catch (e) {
    console.error('Failed to parse formData:', e);
    formData = {};
  }
  
  // Safely parse attachments
  try {
    if (document.attachments && document.attachments.trim() !== '') {
      attachments = JSON.parse(document.attachments);
    }
  } catch (e) {
    console.error('Failed to parse attachments:', e);
    attachments = [];
  }

  const handlePrint = () => {
    window.print();
  };

  const handleDownload = () => {
    // Generate and download the form as PDF
    alert('PDF download functionality would be implemented here');
  };

  const handleForward = () => {
    // Forward to another connection
    alert('Forward functionality would be implemented here');
  };

  // Helper function to format date as DDMMMYYYY
  const formatMilitaryDate = (date: string | Date) => {
    const d = new Date(date);
    const day = d.getDate().toString().padStart(2, '0');
    const month = d.toLocaleDateString('en-US', { month: 'short' }).toUpperCase();
    const year = d.getFullYear();
    return `${day}${month}${year}`;
  };

  // Helper function to format DA2062 to DA 2062
  const formatFormType = (type: string | undefined) => {
    if (!type) return '';
    return type.replace(/DA(\d+)/i, 'DA $1');
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContentNoClose className="max-w-4xl max-h-[90vh] overflow-y-auto bg-gradient-to-br from-white to-gray-50">
        <DialogHeader>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-3 bg-gradient-to-br from-ios-accent/10 to-ios-accent/5 rounded-lg border border-ios-accent/20 shadow-md">
                <FileText className="w-6 h-6 text-ios-accent" />
              </div>
              <div>
                <DialogTitle className="text-xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 font-mono">
                  {formatFormType(document.subtype || document.type)} {formData.equipmentName}
                </DialogTitle>
                <p className="text-sm text-gray-600 font-medium mt-1">
                  {document.title}
                </p>
              </div>
            </div>
            <Badge
              variant={document.status === 'unread' ? 'default' : 'secondary'}
              className="text-xs font-semibold uppercase tracking-wider font-mono"
            >
              {document.status.toUpperCase()}
            </Badge>
          </div>
        </DialogHeader>

        <div className="space-y-6">
          {/* Document Metadata */}
          <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl shadow-lg border border-gray-200/50 hover:shadow-xl transition-all duration-300">
            <div className="p-6">
              <h3 className="text-sm font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 mb-4 uppercase tracking-wider font-mono">
                DOCUMENT INFORMATION
              </h3>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-semibold uppercase tracking-wider flex items-center gap-2">
                    <User className="w-3 h-3" />
                    FROM
                  </label>
                  <p className="text-sm font-medium text-gray-900">
                    {document.sender?.rank} {document.sender?.name}
                  </p>
                </div>
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-semibold uppercase tracking-wider flex items-center gap-2">
                    <Calendar className="w-3 h-3" />
                    DATE SENT
                  </label>
                  <p className="text-sm font-mono font-bold text-gray-900">
                    {formatMilitaryDate(document.sentAt)}
                  </p>
                </div>
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-semibold uppercase tracking-wider flex items-center gap-2">
                    <FileText className="w-3 h-3" />
                    FORM TYPE
                  </label>
                  <p className="text-sm font-mono font-medium text-gray-900">
                    {formatFormType(document.subtype)}
                  </p>
                </div>
                {attachments.length > 0 && (
                  <div className="space-y-1">
                    <label className="text-xs text-gray-500 font-semibold uppercase tracking-wider flex items-center gap-2">
                      <Paperclip className="w-3 h-3" />
                      ATTACHMENTS
                    </label>
                    <p className="text-sm font-medium text-gray-900">
                      {attachments.length} file(s)
                    </p>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Property Information */}
          <div className="bg-gradient-to-r from-blue-50/50 to-purple-50/50 rounded-xl shadow-md border border-gray-200/30 hover:shadow-lg transition-all duration-300">
            <div className="p-6">
              <h3 className="text-sm font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 mb-4 uppercase tracking-wider font-mono">
                PROPERTY INFORMATION
              </h3>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-semibold uppercase tracking-wider">
                    PROPERTY NAME
                  </label>
                  <p className="text-sm font-medium text-gray-900">
                    {formData.equipmentName}
                  </p>
                </div>
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-semibold uppercase tracking-wider">
                    SERIAL NUMBER
                  </label>
                  <p className="text-sm font-mono font-bold text-gray-900">
                    {formData.serialNumber}
                  </p>
                </div>
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-semibold uppercase tracking-wider">
                    NSN
                  </label>
                  <p className="text-sm font-mono text-gray-900">
                    {formData.nsn || 'N/A'}
                  </p>
                </div>
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-semibold uppercase tracking-wider">
                    LOCATION
                  </label>
                  <p className="text-sm font-medium text-gray-900">
                    {formData.location || 'N/A'}
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Document Details */}
          <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl shadow-lg border border-gray-200/50 hover:shadow-xl transition-all duration-300">
            <div className="p-6">
              <h3 className="text-sm font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 mb-4 uppercase tracking-wider font-mono">
                DOCUMENT DETAILS
              </h3>
              <div className="space-y-4">
                {formData.description && (
                  <div>
                    <label className="text-xs text-gray-500 font-semibold uppercase tracking-wider block mb-2">
                      DESCRIPTION
                    </label>
                    <div className="bg-gradient-to-r from-gray-50 to-gray-100/50 p-4 rounded-lg border border-gray-200/50">
                      <p className="text-sm leading-relaxed text-gray-700">
                        {formData.description}
                      </p>
                    </div>
                  </div>
                )}
                {formData.requestDate && (
                  <div>
                    <label className="text-xs text-gray-500 font-semibold uppercase tracking-wider block mb-2">
                      REQUEST DATE
                    </label>
                    <p className="text-sm font-mono font-bold text-gray-900">
                      {formatMilitaryDate(formData.requestDate)}
                    </p>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Form-Specific Fields */}
          {formData.formFields && Object.keys(formData.formFields).length > 0 && (
            <div className="bg-gradient-to-r from-purple-50/50 to-blue-50/50 rounded-xl shadow-md border border-gray-200/30 hover:shadow-lg transition-all duration-300">
              <div className="p-6">
                <h3 className="text-sm font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 mb-4 uppercase tracking-wider font-mono">
                  {formatFormType(document.subtype)} SPECIFIC INFORMATION
                </h3>
                <div className="grid grid-cols-2 gap-4">
                  {Object.entries(formData.formFields).map(([key, value]) => (
                    <div key={key} className="space-y-1">
                      <label className="text-xs text-gray-500 font-semibold uppercase tracking-wider">
                        {key.replace(/_/g, ' ')}
                      </label>
                      <p className="text-sm font-medium text-gray-900">
                        {String(value)}
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Attachments */}
          {attachments.length > 0 && (
            <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl shadow-lg border border-gray-200/50 hover:shadow-xl transition-all duration-300">
              <div className="p-6">
                <h3 className="text-sm font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 mb-4 uppercase tracking-wider font-mono">
                  ATTACHMENTS
                </h3>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  {attachments.map((url: string, index: number) => (
                    <div key={index} className="relative group">
                      <div className="overflow-hidden rounded-lg shadow-md hover:shadow-xl transition-all duration-300">
                        <ProgressiveImage
                          src={url}
                          alt={`Attachment ${index + 1}`}
                          className="w-full h-32 object-cover cursor-pointer hover:scale-105 transition-transform duration-300"
                          containerClassName="w-full h-32"
                          onClick={() => window.open(url, '_blank')}
                          placeholderSrc="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='400' height='300'%3E%3Crect width='400' height='300' fill='%23f3f4f6'/%3E%3C/svg%3E"
                        />
                        <div className="absolute bottom-2 left-2 bg-gradient-to-r from-black/80 to-black/60 text-white text-xs px-2 py-1 rounded font-mono font-semibold">
                          PHOTO {index + 1}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Actions */}
          <div className="flex justify-between items-center pt-4 border-t">
            <div className="flex gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={handlePrint}
                className="border-ios-border hover:bg-blue-500 hover:text-white hover:border-blue-500 text-ios-primary-text font-medium transition-all duration-200 hover:shadow-md"
              >
                <Printer className="h-4 w-4 mr-2" />
                Print
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={handleDownload}
                className="border-ios-border hover:bg-blue-500 hover:text-white hover:border-blue-500 text-ios-primary-text font-medium transition-all duration-200 hover:shadow-md"
              >
                <Download className="h-4 w-4 mr-2" />
                Download PDF
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={handleForward}
                className="border-ios-border hover:bg-blue-500 hover:text-white hover:border-blue-500 text-ios-primary-text font-medium transition-all duration-200 hover:shadow-md"
              >
                <Forward className="h-4 w-4 mr-2" />
                Forward
              </Button>
            </div>
            <Button
              variant="ghost"
              onClick={onClose}
              className="text-blue-500 border border-blue-500 hover:bg-blue-500 hover:border-blue-500 hover:text-white font-semibold transition-all duration-200 hover:scale-105"
            >
              Close
            </Button>
          </div>
        </div>
      </DialogContentNoClose>
    </Dialog>
  );
}; 