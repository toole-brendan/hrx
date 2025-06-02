import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import { Camera, Send, FileText, User, CheckCircle } from 'lucide-react';
import { getConnections } from '@/services/connectionService';
import { sendMaintenanceForm, CreateMaintenanceFormRequest } from '@/services/documentService';

interface Property {
  id: number;
  name: string;
  serialNumber: string;
  nsn?: string;
  location?: string;
}

interface SendMaintenanceFormProps {
  property: Property;
  open: boolean;
  onClose: () => void;
}

export const SendMaintenanceForm: React.FC<SendMaintenanceFormProps> = ({
  property,
  open,
  onClose,
}) => {
  const [formType, setFormType] = useState<'DA2404' | 'DA5988E'>('DA2404');
  const [recipientId, setRecipientId] = useState<number | null>(null);
  const [description, setDescription] = useState('');
  const [faultDescription, setFaultDescription] = useState('');
  const [attachments, setAttachments] = useState<string[]>([]);
  
  const queryClient = useQueryClient();

  const { data: connections } = useQuery({
    queryKey: ['connections'],
    queryFn: getConnections,
  });

  const sendFormMutation = useMutation({
    mutationFn: sendMaintenanceForm,
    onSuccess: (data) => {
      // Invalidate documents queries to refresh any document lists
      queryClient.invalidateQueries({ queryKey: ['documents'] });
      
      // Show success message (you might want to use a toast library)
      alert(data.message);
      
      // Reset form and close
      setFormType('DA2404');
      setRecipientId(null);
      setDescription('');
      setFaultDescription('');
      setAttachments([]);
      onClose();
    },
    onError: (error) => {
      alert(`Failed to send maintenance form: ${error.message}`);
    },
  });

  const handleSend = () => {
    if (!recipientId || !description.trim()) return;

    const formData: CreateMaintenanceFormRequest = {
      propertyId: property.id,
      recipientUserId: recipientId,
      formType,
      description: description.trim(),
      faultDescription: faultDescription.trim() || undefined,
      attachments: attachments.length > 0 ? attachments : undefined,
    };

    sendFormMutation.mutate(formData);
  };

  const connectedUsers = connections?.filter(c => c.connectionStatus === 'accepted') || [];

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Send Maintenance Form</DialogTitle>
        </DialogHeader>
        
        <div className="space-y-6">
          {/* Property Info */}
          <div className="bg-muted p-4 rounded-lg">
            <h3 className="font-medium mb-2">Equipment Information</h3>
            <div className="text-sm space-y-1">
              <p><strong>Item:</strong> {property.name}</p>
              <p><strong>Serial Number:</strong> {property.serialNumber}</p>
              {property.nsn && <p><strong>NSN:</strong> {property.nsn}</p>}
              {property.location && <p><strong>Location:</strong> {property.location}</p>}
            </div>
          </div>
          
          {/* Form Type Selection */}
          <div>
            <label className="text-sm font-medium mb-3 block">Form Type</label>
            <div className="grid grid-cols-1 gap-3">
              <Button
                type="button"
                variant={formType === 'DA2404' ? 'default' : 'outline'}
                onClick={() => setFormType('DA2404')}
                className="h-auto py-4 justify-start"
              >
                <div className="flex items-center gap-3">
                  {formType === 'DA2404' && <CheckCircle className="w-5 h-5" />}
                  <FileText className="w-5 h-5" />
                  <div className="text-left">
                    <div className="font-medium">DA Form 2404</div>
                    <div className="text-xs opacity-70">Equipment Inspection and Maintenance Worksheet</div>
                  </div>
                </div>
              </Button>
              <Button
                type="button"
                variant={formType === 'DA5988E' ? 'default' : 'outline'}
                onClick={() => setFormType('DA5988E')}
                className="h-auto py-4 justify-start"
              >
                <div className="flex items-center gap-3">
                  {formType === 'DA5988E' && <CheckCircle className="w-5 h-5" />}
                  <FileText className="w-5 h-5" />
                  <div className="text-left">
                    <div className="font-medium">DA Form 5988-E</div>
                    <div className="text-xs opacity-70">Equipment Maintenance Request</div>
                  </div>
                </div>
              </Button>
            </div>
          </div>
          
          {/* Recipient Selection */}
          <div>
            <label className="text-sm font-medium mb-2 block">Send To</label>
            {connectedUsers.length === 0 ? (
              <p className="text-sm text-muted-foreground">No connections available. Add connections to send forms.</p>
            ) : (
              <select
                className="w-full p-3 border rounded-md bg-background"
                value={recipientId || ''}
                onChange={(e) => setRecipientId(parseInt(e.target.value) || null)}
              >
                <option value="">Select recipient...</option>
                {connectedUsers.map(conn => (
                  <option key={conn.id} value={conn.connectedUser?.id}>
                    {conn.connectedUser?.rank} {conn.connectedUser?.name} - {conn.connectedUser?.unit}
                  </option>
                ))}
              </select>
            )}
          </div>
          
          {/* Description */}
          <div>
            <label className="text-sm font-medium mb-2 block">
              Description <span className="text-destructive">*</span>
            </label>
            <Textarea
              placeholder="Describe the maintenance needed..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={3}
              className="resize-none"
            />
          </div>
          
          {/* Fault Description */}
          <div>
            <label className="text-sm font-medium mb-2 block">
              Fault/Issue Description (Optional)
            </label>
            <Textarea
              placeholder="Describe any specific faults or issues..."
              value={faultDescription}
              onChange={(e) => setFaultDescription(e.target.value)}
              rows={2}
              className="resize-none"
            />
          </div>
          
          {/* Photo Attachment */}
          <div>
            <label className="text-sm font-medium mb-2 block">Photos (Optional)</label>
            <Button
              type="button"
              variant="outline"
              className="w-full h-20 border-dashed"
              onClick={() => {
                // TODO: Implement photo upload
                alert('Photo upload functionality will be implemented');
              }}
            >
              <div className="text-center">
                <Camera className="w-6 h-6 mx-auto mb-2 text-muted-foreground" />
                <div className="text-sm text-muted-foreground">Click to add photos</div>
                {attachments.length > 0 && (
                  <Badge variant="secondary" className="mt-2">
                    {attachments.length} photo(s) attached
                  </Badge>
                )}
              </div>
            </Button>
          </div>
          
          {/* Actions */}
          <div className="flex justify-end gap-3 pt-4 border-t">
            <Button variant="outline" onClick={onClose} disabled={sendFormMutation.isPending}>
              Cancel
            </Button>
            <Button 
              onClick={handleSend}
              disabled={!recipientId || !description.trim() || sendFormMutation.isPending}
              className="min-w-24"
            >
              {sendFormMutation.isPending ? (
                'Sending...'
              ) : (
                <>
                  <Send className="w-4 h-4 mr-2" />
                  Send Form
                </>
              )}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}; 