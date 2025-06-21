import React, { useState, useEffect, useCallback } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '../ui/dialog';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { Checkbox } from '../ui/checkbox';
import { Textarea } from '../ui/textarea';
import { useToast } from '@/hooks/use-toast';
import { useAuth } from '@/contexts/AuthContext';
import { useQuery } from '@tanstack/react-query';
import { 
  Mail, 
  Download, 
  FileText, 
  Building2, 
  CheckCircle, 
  AlertTriangle, 
  Loader2,
  Pen,
  User,
  Send,
  UserPlus,
  Shield,
  Package
} from 'lucide-react';

// iOS Components
import { CleanCard, ElegantSectionHeader, StatusBadge, MinimalLoadingView } from '@/components/ios';

// Signature components
import { SignatureCapture } from '../signature/SignatureCapture';

// Services
import { 
  uploadSignature, 
  getSignature, 
  saveSignatureLocally, 
  getLocalSignature,
  clearLocalSignature 
} from '@/services/signatureService';
import { getConnections } from '@/services/connectionService';

interface Property {
  id: string;
  name: string;
  serialNumber: string;
  nsn?: string;
  category: string;
  status: string;
  isSensitive?: boolean;
}

interface UnitInfo {
  unitName: string;
  dodaac: string;
  stockNumber: string;
  location: string;
}

interface UserInfo {
  name: string;
  rank: string;
  title: string;
  phone: string;
  signature?: string;
}

interface Connection {
  id: number;
  connectedUserId: number;
  connectedUser?: {
    id: number;
    name: string;
    rank: string;
    unit: string;
    phone?: string;
  };
}

interface GeneratePDFRequest {
  property_ids: string[];
  group_by_category: boolean;
  include_qr_codes: boolean;
  send_email: boolean;
  recipients: string[];
  from_user: UserInfo;
  to_user: UserInfo;
  to_user_id?: number;
  unit_info: UnitInfo;
  form_number: string;
}

interface DA2062ExportDialogProps {
  isOpen: boolean;
  onClose: () => void;
  selectedProperties?: Property[];
}

export const DA2062ExportDialog: React.FC<DA2062ExportDialogProps> = ({
  isOpen,
  onClose,
  selectedProperties: initialSelectedProperties = [],
}) => {
  const { user } = useAuth();
  const { toast } = useToast();
  
  // State
  const [properties, setProperties] = useState<Property[]>([]);
  const [selectedPropertyIds, setSelectedPropertyIds] = useState<Set<string>>(
    new Set(initialSelectedProperties.map(p => p.id))
  );
  const [isLoading, setIsLoading] = useState(false);
  const [isGenerating, setIsGenerating] = useState(false);
  const [exportMode, setExportMode] = useState<'download' | 'email' | 'user'>('download');
  const [emailRecipients, setEmailRecipients] = useState('');
  const [selectedRecipientId, setSelectedRecipientId] = useState<number | null>(null);
  const [showSignatureCapture, setShowSignatureCapture] = useState(false);
  const [userSignature, setUserSignature] = useState<string>('');
  
  // Export options
  const [groupByCategory, setGroupByCategory] = useState(true);
  const [includeQRCodes, setIncludeQRCodes] = useState(true);
  
  // Unit and user info - updated to use user profile
  const [unitInfo, setUnitInfo] = useState<UnitInfo>({
    unitName: localStorage.getItem('unit_name') || user?.unit || '',
    dodaac: localStorage.getItem('unit_dodaac') || '',
    stockNumber: localStorage.getItem('unit_stock_number') || '',
    location: localStorage.getItem('unit_location') || '',
  });
  
  const [userInfo, setUserInfo] = useState<UserInfo>({
    name: user?.name || user?.firstName && user?.lastName 
      ? `${user.firstName} ${user.lastName}` 
      : localStorage.getItem('user_name') || '',
    rank: user?.rank || localStorage.getItem('user_rank') || '',
    title: localStorage.getItem('user_title') || 'Property Book Officer',
    phone: user?.phone || localStorage.getItem('user_phone') || '',
    signature: '',
  });

  // Fetch connections
  const { data: connections = [] } = useQuery({
    queryKey: ['connections'],
    queryFn: getConnections,
    enabled: isOpen,
  });

  // Filter to accepted connections only
  const acceptedConnections = connections.filter(
    (c: Connection) => c.connectedUser && c.connectedUser.id
  );

  // Load user properties
  useEffect(() => {
    if (isOpen) {
      loadProperties();
      loadSignature();
    }
  }, [isOpen]);

  // Save unit info to localStorage when changed
  useEffect(() => {
    localStorage.setItem('unit_name', unitInfo.unitName);
    localStorage.setItem('unit_dodaac', unitInfo.dodaac);
    localStorage.setItem('unit_stock_number', unitInfo.stockNumber);
    localStorage.setItem('unit_location', unitInfo.location);
  }, [unitInfo]);

  const loadProperties = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('/api/properties', {
        credentials: 'include',
      });
      
      if (!response.ok) {
        throw new Error('Failed to load properties');
      }
      
      const data = await response.json();
      setProperties(data);
      
      // If we have initial selected properties, make sure they're in the list
      if (initialSelectedProperties.length > 0) {
        setSelectedPropertyIds(new Set(initialSelectedProperties.map(p => p.id)));
      }
    } catch (error) {
      toast({
        title: 'Error',
        description: 'Failed to load properties',
        variant: 'destructive',
      });
    } finally {
      setIsLoading(false);
    }
  };

  const loadSignature = async () => {
    try {
      // Try to get from server first
      const serverSignature = await getSignature();
      if (serverSignature) {
        setUserSignature(serverSignature);
        saveSignatureLocally(serverSignature);
      } else {
        // Fall back to local storage
        const localSig = getLocalSignature();
        if (localSig) {
          setUserSignature(localSig.signature);
        }
      }
    } catch (error) {
      // Use local signature if available
      const localSig = getLocalSignature();
      if (localSig) {
        setUserSignature(localSig.signature);
      }
    }
  };

  const handleSignatureCapture = async (signature: string) => {
    setUserSignature(signature);
    saveSignatureLocally(signature);
    setShowSignatureCapture(false);
    
    // Upload to server
    try {
      await uploadSignature(signature);
      toast({
        title: 'Signature saved',
        description: 'Your signature has been saved successfully',
      });
    } catch (error) {
      toast({
        title: 'Signature saved locally',
        description: 'Your signature will be uploaded when connection is restored',
      });
    }
  };

  const togglePropertySelection = useCallback((propertyId: string) => {
    setSelectedPropertyIds(prev => {
      const newSet = new Set(prev);
      if (newSet.has(propertyId)) {
        newSet.delete(propertyId);
      } else {
        newSet.add(propertyId);
      }
      return newSet;
    });
  }, []);

  const selectAll = () => {
    setSelectedPropertyIds(new Set(properties.map(p => p.id)));
  };

  const clearSelection = () => {
    setSelectedPropertyIds(new Set());
  };

  const selectByCategory = (category: string) => {
    const filtered = properties.filter(p => 
      p.category?.toLowerCase().includes(category.toLowerCase())
    );
    setSelectedPropertyIds(new Set(filtered.map(p => p.id)));
  };

  const selectSensitiveItems = () => {
    const sensitiveItems = properties.filter(p => p.isSensitive);
    setSelectedPropertyIds(new Set(sensitiveItems.map(p => p.id)));
  };

  const generateFormNumber = () => {
    const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const userId = user?.id || '1';
    return `HR-${date}-${userId}`;
  };

  const handleGenerate = async () => {
    if (selectedPropertyIds.size === 0) {
      toast({
        title: 'No Properties Selected',
        description: 'Please select at least one property to export.',
        variant: 'destructive',
      });
      return;
    }

    if (!userSignature) {
      toast({
        title: 'Signature Required',
        description: 'Please add your signature before exporting.',
        variant: 'destructive',
      });
      setShowSignatureCapture(true);
      return;
    }

    if (exportMode === 'email' && !emailRecipients.trim()) {
      toast({
        title: 'No Recipients',
        description: 'Please enter email recipients.',
        variant: 'destructive',
      });
      return;
    }

    if (exportMode === 'user' && !selectedRecipientId) {
      toast({
        title: 'No Recipient Selected',
        description: 'Please select a recipient from your connections.',
        variant: 'destructive',
      });
      return;
    }

    setIsGenerating(true);

    // Prepare recipient info
    let toUserInfo = { ...userInfo };
    let toUserId: number | undefined;
    
    if (exportMode === 'user' && selectedRecipientId) {
      const recipient = acceptedConnections.find(
        c => c.connectedUser?.id === selectedRecipientId
      );
      if (recipient?.connectedUser) {
        toUserInfo = {
          name: recipient.connectedUser.name,
          rank: recipient.connectedUser.rank || '',
          title: '',
          phone: recipient.connectedUser.phone || '',
        };
        toUserId = recipient.connectedUser.id;
      }
    }

    const request: GeneratePDFRequest = {
      property_ids: Array.from(selectedPropertyIds),
      group_by_category: groupByCategory,
      include_qr_codes: includeQRCodes,
      send_email: exportMode === 'email',
      recipients: exportMode === 'email' 
        ? emailRecipients.split(',').map(r => r.trim()).filter(r => r.length > 0)
        : [],
      from_user: {
        ...userInfo,
        signature: userSignature,
      },
      to_user: toUserInfo,
      to_user_id: toUserId,
      unit_info: unitInfo,
      form_number: generateFormNumber(),
    };

    try {
      const endpoint = '/api/da2062/generate-pdf';

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify(request),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to generate PDF');
      }

      if (exportMode === 'email') {
        const result = await response.json();
        toast({
          title: 'Email Sent',
          description: `DA 2062 sent successfully to ${result.recipients?.length || 0} recipient(s)`,
        });
        onClose();
      } else if (exportMode === 'user') {
        const result = await response.json();
        toast({
          title: 'Hand Receipt Sent',
          description: `DA 2062 sent successfully to ${toUserInfo.name}`,
        });
        onClose();
      } else {
        // Download PDF
        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `DA2062_${generateFormNumber()}.pdf`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);

        toast({
          title: 'PDF Generated',
          description: 'DA 2062 downloaded successfully',
        });
        onClose();
      }
    } catch (error) {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to generate PDF',
        variant: 'destructive',
      });
    } finally {
      setIsGenerating(false);
    }
  };

  const selectedCount = selectedPropertyIds.size;

  return (
    <>
      <Dialog open={isOpen} onOpenChange={onClose}>
        <DialogContent className="max-w-3xl max-h-[90vh] overflow-hidden flex flex-col bg-gradient-to-b from-white to-ios-tertiary-background/30">
          <DialogHeader className="border-b border-ios-divider pb-4">
            <DialogTitle className="flex items-center gap-3">
              <div className="p-2.5 bg-gradient-to-br from-ios-accent to-ios-accent/80 rounded-lg shadow-sm">
                <FileText className="h-5 w-5 text-white" />
              </div>
              <div>
                <h2 className="text-xl font-semibold text-ios-primary-text">
                  Export DA 2062
                </h2>
                <p className="text-xs text-ios-secondary-text mt-0.5">
                  Generate and send hand receipts
                </p>
              </div>
            </DialogTitle>
          </DialogHeader>

          <div className="flex-1 overflow-y-auto px-1">
            <div className="space-y-6 p-6">
              {/* Unit Information */}
              <CleanCard className="shadow-sm border border-ios-border">
                <div className="p-6">
                  <div className="mb-4">
                    <h3 className="text-sm font-semibold text-ios-primary-text mb-1 uppercase tracking-wider font-['Courier_New',_monospace]">UNIT INFORMATION</h3>
                    <p className="text-xs text-ios-secondary-text">Organization details for the form</p>
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <Label htmlFor="unitName" className="text-xs text-secondary-text">Unit Name</Label>
                      <Input
                        id="unitName"
                        value={unitInfo.unitName}
                        onChange={(e) => setUnitInfo(prev => ({ ...prev, unitName: e.target.value }))}
                        className="mt-1"
                      />
                    </div>
                    <div>
                      <Label htmlFor="dodaac" className="text-xs text-secondary-text">DODAAC</Label>
                      <Input
                        id="dodaac"
                        value={unitInfo.dodaac}
                        onChange={(e) => setUnitInfo(prev => ({ ...prev, dodaac: e.target.value }))}
                        className="mt-1"
                      />
                    </div>
                    <div>
                      <Label htmlFor="location" className="text-xs text-secondary-text">Location</Label>
                      <Input
                        id="location"
                        value={unitInfo.location}
                        onChange={(e) => setUnitInfo(prev => ({ ...prev, location: e.target.value }))}
                        className="mt-1"
                      />
                    </div>
                    <div>
                      <Label htmlFor="stockNumber" className="text-xs text-secondary-text">Stock Number</Label>
                      <Input
                        id="stockNumber"
                        value={unitInfo.stockNumber}
                        onChange={(e) => setUnitInfo(prev => ({ ...prev, stockNumber: e.target.value }))}
                        className="mt-1"
                      />
                    </div>
                  </div>
                </div>
              </CleanCard>

              {/* Form Details */}
              <div className="bg-ios-tertiary-background/30 rounded-lg p-4 mb-6">
                <h4 className="text-xs font-semibold text-ios-primary-text uppercase tracking-wider mb-3 font-['Courier_New',_monospace]">
                  FORM DETAILS
                </h4>
                <div className="space-y-2 text-xs text-ios-secondary-text">
                  <div className="flex items-start gap-2">
                    <span className="text-ios-tertiary-text">•</span>
                    <span>Form Number: <span className="font-['Courier_New',_monospace] text-ios-primary-text">{generateFormNumber()}</span></span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-ios-tertiary-text">•</span>
                    <span>Generated according to DA Form 2062 standards</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-ios-tertiary-text">•</span>
                    <span>Digital signature required for all exports</span>
                  </div>
                </div>
              </div>

              {/* Digital Signature */}
              <CleanCard className="shadow-sm border border-ios-border">
                <div className="p-6">
                  <div className="mb-4">
                    <h3 className="text-sm font-semibold text-ios-primary-text mb-1 uppercase tracking-wider font-['Courier_New',_monospace]">DIGITAL SIGNATURE</h3>
                    <p className="text-xs text-ios-secondary-text">Required for generating hand receipts</p>
                  </div>
                  <div className="space-y-4">
                    {userSignature ? (
                      <div className="space-y-3">
                        <div className="p-4 bg-gradient-to-r from-ios-accent/10 to-ios-accent/5 rounded-lg border border-ios-accent/20">
                          <img 
                            src={userSignature} 
                            alt="Your signature" 
                            className="h-16 mx-auto"
                          />
                        </div>
                        <div className="flex items-center justify-between">
                          <span className="text-xs text-ios-secondary-text flex items-center gap-2">
                            <CheckCircle className="h-4 w-4 text-green-500" />
                            Signature captured
                          </span>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => setShowSignatureCapture(true)}
                            className="text-xs"
                          >
                            Update
                          </Button>
                        </div>
                      </div>
                    ) : (
                      <div className="text-center py-8 border-2 border-dashed border-ios-border rounded-lg bg-ios-tertiary-background/10">
                        <Shield className="h-8 w-8 text-ios-tertiary-text mx-auto mb-3" />
                        <p className="text-sm text-ios-primary-text font-medium mb-1">
                          No Signature
                        </p>
                        <p className="text-xs text-ios-secondary-text mb-4">
                          Add your signature to continue
                        </p>
                        <Button
                          onClick={() => setShowSignatureCapture(true)}
                          variant="outline"
                          size="sm"
                        >
                          <Pen className="h-4 w-4 mr-2" />
                          Add Signature
                        </Button>
                      </div>
                    )}
                  </div>
                </div>
              </CleanCard>

              {/* Property Selection */}
              <CleanCard className="shadow-sm border border-ios-border">
                <div className="p-6">
                  <div className="mb-4">
                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="text-sm font-semibold text-ios-primary-text mb-1 uppercase tracking-wider font-['Courier_New',_monospace]">SELECT PROPERTIES</h3>
                        <p className="text-xs text-ios-secondary-text">Choose items to include in the export</p>
                      </div>
                      <span className="text-xs font-semibold text-ios-accent uppercase tracking-wider font-['Courier_New',_monospace]">
                        {selectedCount} SELECTED
                      </span>
                    </div>
                  </div>

                  {/* Quick Actions */}
                  <div className="flex items-center gap-2 mb-4 flex-wrap">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={selectAll}
                      className="text-xs"
                    >
                      Select All
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={clearSelection}
                      className="text-xs"
                    >
                      Clear All
                    </Button>
                    <div className="h-4 w-px bg-ios-divider" />
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={selectSensitiveItems}
                      className="text-xs flex items-center gap-1"
                    >
                      <AlertTriangle className="h-3 w-3" />
                      Sensitive Only
                    </Button>
                  </div>

                  {/* Property List */}
                  {isLoading ? (
                    <MinimalLoadingView text="Loading properties..." size="md" className="py-8" />
                  ) : (
                    <div className="max-h-64 overflow-y-auto border border-ios-divider rounded-lg">
                      {properties.map((property) => (
                        <div
                          key={property.id}
                          className="flex items-center gap-3 p-3 border-b border-ios-divider last:border-b-0 hover:bg-ios-tertiary-background/30 cursor-pointer transition-colors"
                          onClick={() => togglePropertySelection(property.id)}
                        >
                          <Checkbox
                            checked={selectedPropertyIds.has(property.id)}
                            onChange={() => togglePropertySelection(property.id)}
                            className="rounded-sm"
                          />
                          <div className="flex-1 min-w-0">
                            <div className="text-sm font-medium text-ios-primary-text">{property.name}</div>
                            <div className="text-xs text-ios-secondary-text font-['Courier_New',_monospace]">
                              SN: {property.serialNumber}
                              {property.nsn && ` • NSN: ${property.nsn}`}
                            </div>
                          </div>
                          {property.isSensitive && (
                            <AlertTriangle className="h-4 w-4 text-ios-warning" />
                          )}
                          <StatusBadge 
                            status={property.status === 'Operational' ? 'operational' : 'maintenance'} 
                            size="sm"
                          />
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </CleanCard>

              {/* Export Options */}
              <CleanCard className="shadow-sm border border-ios-border">
                <div className="p-6">
                  <div className="mb-4">
                    <h3 className="text-sm font-semibold text-ios-primary-text mb-1 uppercase tracking-wider font-['Courier_New',_monospace]">EXPORT OPTIONS</h3>
                    <p className="text-xs text-ios-secondary-text">Configure output format and delivery method</p>
                  </div>
              <div className="space-y-4">
                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="groupByCategory"
                    checked={groupByCategory}
                    onCheckedChange={(checked) => setGroupByCategory(checked === true)}
                    className="rounded-sm"
                  />
                  <Label 
                    htmlFor="groupByCategory" 
                    className="text-sm cursor-pointer"
                  >
                    Group by Category
                  </Label>
                </div>
                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="includeQRCodes"
                    checked={includeQRCodes}
                    onCheckedChange={(checked) => setIncludeQRCodes(checked === true)}
                    className="rounded-sm"
                  />
                  <Label 
                    htmlFor="includeQRCodes" 
                    className="text-sm cursor-pointer"
                  >
                    Include QR Codes
                  </Label>
                </div>
                
                    <div className="h-px bg-ios-divider my-4" />
                    
                    {/* Export Mode */}
                    <div className="space-y-3">
                      <Label className="text-xs text-secondary-text font-semibold uppercase tracking-wider font-['Courier_New',_monospace]">
                        DELIVERY METHOD
                      </Label>
                      <div className="grid grid-cols-3 gap-2">
                        <Button
                          variant={exportMode === 'download' ? 'default' : 'outline'}
                          onClick={() => setExportMode('download')}
                          className={`text-sm ${
                            exportMode === 'download' 
                              ? 'bg-ios-accent hover:bg-ios-accent/90 text-white' 
                              : 'border-ios-border hover:bg-ios-tertiary-background'
                          }`}
                        >
                          <Download className="h-4 w-4 mr-2" />
                          Download
                        </Button>
                        <Button
                          variant={exportMode === 'email' ? 'default' : 'outline'}
                          onClick={() => setExportMode('email')}
                          className={`text-sm ${
                            exportMode === 'email' 
                              ? 'bg-ios-accent hover:bg-ios-accent/90 text-white' 
                              : 'border-ios-border hover:bg-ios-tertiary-background'
                          }`}
                    >
                      <Mail className="h-4 w-4 mr-2" />
                      Email
                    </Button>
                        <Button
                          variant={exportMode === 'user' ? 'default' : 'outline'}
                          onClick={() => setExportMode('user')}
                          className={`text-sm ${
                            exportMode === 'user' 
                              ? 'bg-ios-accent hover:bg-ios-accent/90 text-white' 
                              : 'border-ios-border hover:bg-ios-tertiary-background'
                          }`}
                        >
                          <Send className="h-4 w-4 mr-2" />
                          Send to User
                        </Button>
                      </div>
                  
                  {exportMode === 'email' && (
                    <div className="mt-4">
                      <Label 
                        htmlFor="emailRecipients" 
                        className="text-xs text-secondary-text"
                      >
                        Email Recipients (comma-separated)
                      </Label>
                      <Textarea
                        id="emailRecipients"
                        value={emailRecipients}
                        onChange={(e) => setEmailRecipients(e.target.value)}
                        placeholder="email1@example.com, email2@example.com"
                        className="mt-1 resize-none"
                        rows={3}
                      />
                    </div>
                  )}
                  
                  {exportMode === 'user' && (
                    <div className="mt-4 space-y-3">
                      <Label className="text-xs text-secondary-text">
                        Select Recipient
                      </Label>
                      {acceptedConnections.length === 0 ? (
                        <div className="text-center py-8 border-2 border-dashed border-ios-border rounded-lg bg-ios-tertiary-background/10">
                          <UserPlus className="h-8 w-8 text-ios-tertiary-text mx-auto mb-3" />
                          <p className="text-sm text-ios-primary-text font-medium mb-1">
                            No connections available
                          </p>
                          <p className="text-xs text-ios-secondary-text">
                            Add connections from the Network page
                          </p>
                        </div>
                      ) : (
                        <div className="space-y-2 max-h-48 overflow-y-auto">
                          {acceptedConnections.map((connection) => (
                            <div
                              key={connection.id}
                              className={`p-3 border rounded-lg cursor-pointer transition-colors ${
                                selectedRecipientId === connection.connectedUser?.id
                                  ? 'border-ios-accent bg-ios-accent/5'
                                  : 'border-ios-border hover:border-ios-accent/50'
                              }`}
                              onClick={() => setSelectedRecipientId(connection.connectedUser?.id || null)}
                            >
                              <div className="flex items-center justify-between">
                                <div className="flex items-center space-x-3">
                                  <div className="w-10 h-10 rounded-full bg-ios-secondary-background flex items-center justify-center">
                                    <User className="h-5 w-5 text-secondary-text" />
                                  </div>
                                  <div>
                                    <p className="font-medium text-sm text-primary-text">
                                      {connection.connectedUser?.name}
                                    </p>
                                    <p className="text-xs text-secondary-text font-['Courier_New',_monospace]">
                                      {connection.connectedUser?.rank} • {connection.connectedUser?.unit}
                                    </p>
                                  </div>
                                </div>
                                {selectedRecipientId === connection.connectedUser?.id && (
                                  <CheckCircle className="h-5 w-5 text-ios-accent" />
                                )}
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </CleanCard>
          </div>
        </div>

        <DialogFooter className="border-t border-ios-divider pt-4">
          <Button
            variant="outline"
            onClick={onClose}
            disabled={isGenerating}
            className="border-ios-border hover:bg-ios-tertiary-background font-medium"
          >
            Cancel
          </Button>
          <Button
            onClick={handleGenerate}
            disabled={selectedCount === 0 || isGenerating}
            className="bg-ios-accent hover:bg-ios-accent/90 text-white font-medium shadow-sm transition-all duration-200"
          >
            {isGenerating ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Generating...
              </>
            ) : exportMode === 'email' ? (
              <>
                <Mail className="mr-2 h-4 w-4" />
                Send Email
              </>
            ) : exportMode === 'user' ? (
              <>
                <Send className="mr-2 h-4 w-4" />
                Send to User
              </>
            ) : (
              <>
                <Download className="mr-2 h-4 w-4" />
                Download PDF
              </>
            )}
          </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Signature Capture Dialog */}
      <SignatureCapture
        isOpen={showSignatureCapture}
        onCapture={handleSignatureCapture}
        onCancel={() => setShowSignatureCapture(false)}
      />
    </>
  );
};