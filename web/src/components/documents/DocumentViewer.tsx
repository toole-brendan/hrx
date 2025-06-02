import React from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { FileText, User, Calendar, Paperclip, Download, Forward, Printer } from 'lucide-react';
import { format } from 'date-fns';
import { Document } from '@/services/documentService';

interface DocumentViewerProps {
  document: Document;
  open: boolean;
  onClose: () => void;
}

export const DocumentViewer: React.FC<DocumentViewerProps> = ({
  document,
  open,
  onClose,
}) => {
  const formData = JSON.parse(document.formData);
  const attachments = document.attachments ? JSON.parse(document.attachments) : [];

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

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <FileText className="w-6 h-6" />
              <div>
                <DialogTitle className="text-xl font-semibold">
                  {document.subtype || document.type} - {formData.equipmentName}
                </DialogTitle>
                <p className="text-sm text-muted-foreground mt-1">
                  {document.title}
                </p>
              </div>
            </div>
            <Badge variant={document.status === 'unread' ? 'default' : 'secondary'} className="text-xs">
              {document.status.toUpperCase()}
            </Badge>
          </div>
        </DialogHeader>

        <div className="space-y-6">
          {/* Document Metadata */}
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-medium">Document Information</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div className="flex items-center gap-2">
                  <User className="w-4 h-4 text-muted-foreground" />
                  <span className="text-muted-foreground">From:</span>
                  <span className="font-medium">
                    {document.sender?.rank} {document.sender?.name}
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <Calendar className="w-4 h-4 text-muted-foreground" />
                  <span className="text-muted-foreground">Sent:</span>
                  <span className="font-medium">
                    {format(new Date(document.sentAt), 'MMM d, yyyy \'at\' h:mm a')}
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <FileText className="w-4 h-4 text-muted-foreground" />
                  <span className="text-muted-foreground">Form Type:</span>
                  <span className="font-medium">{document.subtype}</span>
                </div>
                {attachments.length > 0 && (
                  <div className="flex items-center gap-2">
                    <Paperclip className="w-4 h-4 text-muted-foreground" />
                    <span className="text-muted-foreground">Attachments:</span>
                    <span className="font-medium">{attachments.length} file(s)</span>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Equipment Information */}
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-medium">Equipment Information</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-muted-foreground block mb-1">Equipment Name</span>
                  <span className="font-medium">{formData.equipmentName}</span>
                </div>
                <div>
                  <span className="text-muted-foreground block mb-1">Serial Number</span>
                  <span className="font-mono font-medium">{formData.serialNumber}</span>
                </div>
                <div>
                  <span className="text-muted-foreground block mb-1">NSN</span>
                  <span className="font-mono">{formData.nsn || 'N/A'}</span>
                </div>
                <div>
                  <span className="text-muted-foreground block mb-1">Location</span>
                  <span>{formData.location || 'N/A'}</span>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Request Details */}
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-medium">Maintenance Request Details</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <span className="text-muted-foreground text-sm block mb-2">Description</span>
                <div className="bg-muted/50 p-3 rounded-md">
                  <p className="text-sm leading-relaxed">{formData.description}</p>
                </div>
              </div>
              
              {formData.faultDescription && (
                <div>
                  <span className="text-muted-foreground text-sm block mb-2">Fault Description</span>
                  <div className="bg-muted/50 p-3 rounded-md">
                    <p className="text-sm leading-relaxed">{formData.faultDescription}</p>
                  </div>
                </div>
              )}

              <div>
                <span className="text-muted-foreground text-sm block mb-2">Request Date</span>
                <span className="text-sm">
                  {format(new Date(formData.requestDate), 'EEEE, MMMM d, yyyy')}
                </span>
              </div>
            </CardContent>
          </Card>

          {/* Form-Specific Fields */}
          {formData.formFields && Object.keys(formData.formFields).length > 0 && (
            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-medium">
                  {document.subtype} Specific Information
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 gap-4 text-sm">
                  {Object.entries(formData.formFields).map(([key, value]) => (
                    <div key={key}>
                      <span className="text-muted-foreground block mb-1 capitalize">
                        {key.replace(/_/g, ' ')}
                      </span>
                      <span className="font-medium">{String(value)}</span>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          )}

          {/* Attachments */}
          {attachments.length > 0 && (
            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-medium">Attachments</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  {attachments.map((url: string, index: number) => (
                    <div key={index} className="relative group">
                      <img
                        src={url}
                        alt={`Attachment ${index + 1}`}
                        className="w-full h-32 object-cover rounded-md border cursor-pointer hover:opacity-75 transition-opacity"
                        onClick={() => window.open(url, '_blank')}
                      />
                      <div className="absolute bottom-2 left-2 bg-black/70 text-white text-xs px-2 py-1 rounded">
                        Photo {index + 1}
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          )}

          {/* Actions */}
          <div className="flex justify-between items-center pt-4 border-t">
            <div className="flex gap-2">
              <Button variant="outline" size="sm" onClick={handlePrint}>
                <Printer className="w-4 h-4 mr-2" />
                Print
              </Button>
              <Button variant="outline" size="sm" onClick={handleDownload}>
                <Download className="w-4 h-4 mr-2" />
                Download PDF
              </Button>
              <Button variant="outline" size="sm" onClick={handleForward}>
                <Forward className="w-4 h-4 mr-2" />
                Forward
              </Button>
            </div>
            <Button onClick={onClose}>Close</Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}; 