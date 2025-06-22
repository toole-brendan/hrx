import React, { useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useToast } from '@/hooks/use-toast';
import { MessageSquare, Send, X, User, AlertCircle, Type, FileText, ArrowRight, Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';
import { CleanCard } from '@/components/ios';
import { createDocument } from '@/services/documentService';
import { useAuth } from '@/contexts/AuthContext';
import { useNotifications } from '@/contexts/NotificationContext';

interface MessageModalProps {
  isOpen: boolean;
  onClose: () => void;
  recipient: {
    id: number;
    name: string;
    rank?: string;
    unit?: string;
  };
}

// Enhanced form field component
const FormField: React.FC<{
  label: string;
  icon: React.ReactNode;
  children: React.ReactNode;
  required?: boolean;
  helperText?: string;
}> = ({ label, icon, children, required, helperText }) => (
  <div className="space-y-2">
    <div className="flex items-center gap-2">
      <div className="p-1.5 bg-ios-accent/10 rounded-md">
        {icon}
      </div>
      <Label className="text-xs font-medium text-ios-primary-text uppercase tracking-wider font-mono">
        {label}
        {required && <span className="text-ios-destructive ml-1">*</span>}
      </Label>
    </div>
    {children}
    {helperText && (
      <p className="text-xs text-ios-tertiary-text mt-1">{helperText}</p>
    )}
  </div>
);

export const MessageModal: React.FC<MessageModalProps> = ({ isOpen, onClose, recipient }) => {
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [isSending, setIsSending] = useState(false);
  const { toast } = useToast();
  const { user } = useAuth();
  const { addNotification } = useNotifications();

  const handleSend = async () => {
    if (!subject.trim() || !message.trim()) {
      toast({
        title: 'Missing Information',
        description: 'Please enter both a subject and message',
        variant: 'destructive'
      });
      return;
    }

    setIsSending(true);
    try {
      // Create a message document
      await createDocument({
        type: 'message',
        subtype: 'direct_message',
        title: subject,
        recipientUserId: recipient.id,
        formData: {
          message,
          fromUser: {
            id: user?.id,
            name: user?.name,
            rank: user?.rank,
            unit: user?.unit
          },
          sentAt: new Date().toISOString()
        },
        description: `Direct message from ${user?.name}`
      });

      // Add local notification
      addNotification({
        type: 'success',
        title: 'Message Sent',
        message: `Your message to ${recipient.name} has been sent successfully`
      });

      toast({
        title: 'Message sent successfully',
        description: `Your message to ${recipient.name} has been delivered`
      });

      // Reset form and close
      setSubject('');
      setMessage('');
      onClose();
    } catch (error) {
      console.error('Failed to send message:', error);
      toast({
        title: 'Failed to send message',
        description: 'Please try again later',
        variant: 'destructive'
      });
    } finally {
      setIsSending(false);
    }
  };

  const handleClose = () => {
    if ((subject.trim() || message.trim()) && !isSending) {
      const confirmed = window.confirm('Are you sure? Your message will be discarded.');
      if (!confirmed) return;
    }
    setSubject('');
    setMessage('');
    onClose();
  };

  return (
    <Dialog open={isOpen} onOpenChange={handleClose}>
      <DialogContent className="sm:max-w-lg bg-gradient-to-b from-white to-ios-tertiary-background/30 rounded-xl border-ios-border shadow-xl">
        <DialogHeader className="border-b border-ios-divider pb-4">
          <DialogTitle className="flex items-center gap-3">
            <div className="p-2.5 bg-blue-500 rounded-lg shadow-sm">
              <MessageSquare className="h-5 w-5 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-semibold text-ios-primary-text">
                Send Message
              </h2>
              <p className="text-xs text-ios-secondary-text mt-0.5">
                Send a secure message to another user
              </p>
            </div>
          </DialogTitle>
        </DialogHeader>
        
        <form id="message-form" onSubmit={(e) => { e.preventDefault(); handleSend(); }}>
          <div className="grid gap-6 py-6">
            {/* Message Details Section */}
            <div className="space-y-4">
              <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-mono flex items-center gap-2">
                <div className="h-px flex-1 bg-ios-border" />
                <span>Message Details</span>
                <div className="h-px flex-1 bg-ios-border" />
              </h3>
              
              <FormField
                label="Subject"
                icon={<Type className="h-4 w-4 text-ios-accent" />}
                required
                helperText={`${subject.length}/100 characters`}
              >
                <Input
                  id="subject"
                  name="subject"
                  value={subject}
                  onChange={(e) => setSubject(e.target.value)}
                  placeholder="e.g., Equipment Transfer Inquiry"
                  className="border-ios-border bg-ios-tertiary-background/50 rounded-lg h-12 text-base placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-ios-accent transition-all duration-200"
                  maxLength={100}
                  required
                />
              </FormField>
              
              <FormField
                label="Message"
                icon={<FileText className="h-4 w-4 text-ios-accent" />}
                required
                helperText={`${message.length}/1000 characters`}
              >
                <Textarea
                  id="message"
                  name="message"
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  placeholder="Type your message here..."
                  className="border-ios-border bg-ios-tertiary-background/50 rounded-lg min-h-[150px] text-base placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-ios-accent transition-all duration-200 resize-none"
                  maxLength={1000}
                  required
                />
              </FormField>
            </div>
            
            {/* Recipient Section */}
            <div className="space-y-4">
              <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-mono flex items-center gap-2">
                <div className="h-px flex-1 bg-ios-border" />
                <span>Recipient</span>
                <div className="h-px flex-1 bg-ios-border" />
              </h3>
              
              <CleanCard className="p-4 bg-gradient-to-r from-ios-tertiary-background/30 to-ios-tertiary-background/10">
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <FormField
                      label="From"
                      icon={<User className="h-4 w-4 text-ios-secondary-text" />}
                    >
                      <div className="text-sm font-semibold text-ios-primary-text mt-1">
                        {user?.name || 'Current User'}
                        {user?.rank && user?.unit && (
                          <div className="text-xs text-ios-secondary-text mt-0.5">
                            {user.rank} • {user.unit}
                          </div>
                        )}
                      </div>
                    </FormField>
                  </div>
                  
                  <div className="px-6 py-4">
                    <ArrowRight className="h-5 w-5 text-ios-accent" />
                  </div>
                  
                  <div className="flex-1">
                    <FormField
                      label="To"
                      icon={<User className="h-4 w-4 text-ios-accent" />}
                    >
                      <div className="text-sm font-semibold text-ios-primary-text mt-1">
                        {recipient.name}
                        {(recipient.rank || recipient.unit) && (
                          <div className="text-xs text-ios-secondary-text mt-0.5">
                            {[recipient.rank, recipient.unit].filter(Boolean).join(' • ')}
                          </div>
                        )}
                      </div>
                    </FormField>
                  </div>
                </div>
              </CleanCard>
              
              {/* Info Alert */}
              <CleanCard className="p-3 bg-blue-50/50 border border-blue-200/30">
                <div className="flex gap-2.5">
                  <AlertCircle className="h-4 w-4 text-blue-500 flex-shrink-0 mt-0.5" />
                  <div className="text-xs text-ios-secondary-text">
                    <p className="font-semibold text-blue-700 mb-0.5">Secure Delivery</p>
                    <p>Messages are delivered through the secure document system.</p>
                  </div>
                </div>
              </CleanCard>
            </div>
          </div>
          
          <DialogFooter className="gap-3 sm:gap-3">
            <Button
              type="button"
              variant="outline"
              className="border-ios-border hover:bg-ios-tertiary-background text-ios-secondary-text rounded-lg px-6 py-2.5 font-medium transition-all duration-200"
              onClick={handleClose}
              disabled={isSending}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              className="bg-blue-500 hover:bg-blue-600 text-white rounded-lg px-6 py-2.5 font-medium shadow-sm transition-all duration-200 flex items-center gap-2 border-0"
              disabled={isSending || !subject.trim() || !message.trim()}
            >
              {isSending ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  <span>Sending...</span>
                </>
              ) : (
                <>
                  <Send className="h-4 w-4" />
                  <span>Send Message</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
};