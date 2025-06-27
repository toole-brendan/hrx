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
import { exportDA2062 } from '@/services/da2062Service';

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
  signature_url?: string;
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
  property_ids: number[];
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
    signature_url: '',
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
      const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:8080';
      const response = await fetch(`${apiUrl}/api/property`, {
        credentials: 'include',
      });
      
      if (!response.ok) {
        throw new Error('Failed to load properties');
      }
      
      const data = await response.json();
      // Handle both array response and object with items/properties array
      const propertyList = Array.isArray(data) ? data : (data.items || data.properties || []);
      setProperties(propertyList);
      
      // If we have initial selected properties, make sure they're in the list
      if (initialSelectedProperties.length > 0) {
        setSelectedPropertyIds(new Set(initialSelectedProperties.map(p => p.id)));
      }
    } catch (error) {
      console.error('Failed to load properties:', error);
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
      property_ids: Array.from(selectedPropertyIds).map(id => parseInt(id, 10)),
      group_by_category: groupByCategory,
      include_qr_codes: false,  // QR codes disabled
      send_email: exportMode === 'email',
      recipients: exportMode === 'email' 
        ? emailRecipients.split(',').map(r => r.trim()).filter(r => r.length > 0)
        : [],
      from_user: {
        ...userInfo,
        signature_url: userSignature,
      },
      to_user: toUserInfo,
      unit_info: unitInfo,
      form_number: generateFormNumber(),
    };
    
    // Only include to_user_id if it's defined (when sending to a user)
    if (toUserId !== undefined) {
      request.to_user_id = toUserId;
    }

    try {
      const apiBaseUrl = import.meta.env.VITE_API_URL || 'http://localhost:8080';
      const endpoint = `${apiBaseUrl}/api/da2062/generate-pdf`;

      console.log('DA2062 Export Request:', {
        endpoint,
        request,
        exportMode,
        selectedPropertiesCount: request.property_ids.length,
        hasToUserId: !!request.to_user_id,
        to_user_id_value: request.to_user_id,
        send_email: request.send_email,
        recipients_length: request.recipients.length
      });
      
      // Log the exact JSON being sent
      console.log('Request JSON:', JSON.stringify(request, null, 2));

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
        a.download = `DA2062_${generateFormNumber()}.html`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);

        toast({
          title: 'DA 2062 Generated',
          description: 'Hand receipt downloaded successfully',
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
        <DialogContent className="max-w-3xl max-h-[90vh] overflow-hidden flex flex-col bg-gradient-to-b from-white to-gray-50/50 backdrop-blur-xl shadow-2xl border border-gray-200/50">
          <DialogHeader className="border-b border-gray-200/50 pb-4 bg-gradient-to-r from-white to-gray-50/30">
            <DialogTitle className="flex items-center gap-3">
              <div className="p-2.5 bg-blue-500 rounded-lg shadow-lg transform hover:scale-105 transition-all duration-300">
                <FileText className="h-5 w-5 text-white" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700">
                  Export DA 2062
                </h2>
                <p className="text-xs font-medium text-gray-600 mt-0.5">
                  Generate and send hand receipts
                </p>
              </div>
            </DialogTitle>
          </DialogHeader>

          <div className="flex-1 overflow-y-auto px-1">
            <div className="space-y-6 p-6">
              {/* Unit Information */}
              <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl shadow-lg border border-gray-200/50 hover:shadow-xl transition-all duration-300">
                <div className="p-6">
                  <div className="mb-4">
                    <h3 className="text-sm font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 mb-1 uppercase tracking-wider font-mono">UNIT INFORMATION</h3>
                    <p className="text-xs font-medium text-gray-600">Organization details for the form</p>
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <Label htmlFor="unitName" className="text-xs text-gray-500 font-semibold uppercase tracking-wider">Unit Name</Label>
                      <Input
                        id="unitName"
                        value={unitInfo.unitName}
                        onChange={(e) => setUnitInfo(prev => ({ ...prev, unitName: e.target.value }))}
                        className="mt-1 bg-gradient-to-r from-white to-gray-50 border-gray-200/50 focus:ring-2 focus:ring-ios-accent/20 transition-all duration-200"
                      />
                    </div>
                    <div>
                      <Label htmlFor="dodaac" className="text-xs text-gray-500 font-semibold uppercase tracking-wider">DODAAC</Label>
                      <Input
                        id="dodaac"
                        value={unitInfo.dodaac}
                        onChange={(e) => setUnitInfo(prev => ({ ...prev, dodaac: e.target.value }))}
                        className="mt-1 bg-gradient-to-r from-white to-gray-50 border-gray-200/50 focus:ring-2 focus:ring-ios-accent/20 transition-all duration-200"
                      />
                    </div>
                    <div>
                      <Label htmlFor="location" className="text-xs text-gray-500 font-semibold uppercase tracking-wider">Location</Label>
                      <Input
                        id="location"
                        value={unitInfo.location}
                        onChange={(e) => setUnitInfo(prev => ({ ...prev, location: e.target.value }))}
                        className="mt-1 bg-gradient-to-r from-white to-gray-50 border-gray-200/50 focus:ring-2 focus:ring-ios-accent/20 transition-all duration-200"
                      />
                    </div>
                    <div>
                      <Label htmlFor="stockNumber" className="text-xs text-gray-500 font-semibold uppercase tracking-wider">Stock Number</Label>
                      <Input
                        id="stockNumber"
                        value={unitInfo.stockNumber}
                        onChange={(e) => setUnitInfo(prev => ({ ...prev, stockNumber: e.target.value }))}
                        className="mt-1 bg-gradient-to-r from-white to-gray-50 border-gray-200/50 focus:ring-2 focus:ring-ios-accent/20 transition-all duration-200"
                      />
                    </div>
                  </div>
                </div>
              </div>

              {/* Form Details */}
              <div className="bg-gradient-to-r from-blue-50/50 to-purple-50/50 rounded-lg p-4 mb-6 shadow-md border border-gray-200/30 animate-in slide-in-from-bottom duration-300">
                <h4 className="text-xs font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 uppercase tracking-wider mb-3 font-mono">
                  FORM DETAILS
                </h4>
                <div className="space-y-2 text-xs text-gray-600 font-medium">
                  <div className="flex items-start gap-2">
                    <span className="text-gray-400">•</span>
                    <span>Form Number: <span className="font-mono font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700">{generateFormNumber()}</span></span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-gray-400">•</span>
                    <span>Generated according to DA Form 2062 standards</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="text-gray-400">•</span>
                    <span>Digital signature required for all exports</span>
                  </div>
                </div>
              </div>

              {/* Digital Signature */}
              <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl shadow-lg border border-gray-200/50 hover:shadow-xl transition-all duration-300">
                <div className="p-6">
                  <div className="mb-4">
                    <h3 className="text-sm font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 mb-1 uppercase tracking-wider font-mono">DIGITAL SIGNATURE</h3>
                    <p className="text-xs font-medium text-gray-600">Required for generating hand receipts</p>
                  </div>
                  <div className="space-y-4">
                    {userSignature ? (
                      <div className="space-y-3">
                        <div className="p-4 bg-gradient-to-r from-ios-accent/10 to-ios-accent/5 rounded-lg border border-ios-accent/20 shadow-md hover:shadow-lg transition-all duration-300">
                          <img 
                            src={userSignature} 
                            alt="Your signature" 
                            className="h-16 mx-auto"
                          />
                        </div>
                        <div className="flex items-center justify-between">
                          <span className="text-xs text-gray-600 font-medium flex items-center gap-2">
                            <CheckCircle className="h-4 w-4 text-green-500" />
                            Signature captured
                          </span>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => setShowSignatureCapture(true)}
                            className="text-xs text-gray-700 hover:text-gray-900 hover:bg-gray-100 transition-all duration-200"
                          >
                            Update
                          </Button>
                        </div>
                      </div>
                    ) : (
                      <div className="text-center py-8 border-2 border-dashed border-gray-300 rounded-lg bg-gradient-to-br from-gray-50 to-gray-100/50 hover:border-ios-accent/50 transition-all duration-300">
                        <Shield className="h-8 w-8 text-gray-400 mx-auto mb-3" />
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
                          className="text-gray-700 hover:text-ios-accent hover:bg-ios-accent/10 hover:border-ios-accent/30 transition-all duration-200"
                        >
                          <Pen className="h-4 w-4 mr-2" />
                          Add Signature
                        </Button>
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {/* Property Selection */}
              <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl shadow-lg border border-gray-200/50 hover:shadow-xl transition-all duration-300">
                <div className="p-6">
                  <div className="mb-4">
                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="text-sm font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 mb-1 uppercase tracking-wider font-mono">SELECT PROPERTIES</h3>
                        <p className="text-xs font-medium text-gray-600">Choose items to include in the export</p>
                      </div>
                      <span className="text-xs font-bold text-transparent bg-clip-text bg-gradient-to-r from-ios-accent to-ios-accent/80 uppercase tracking-wider font-mono">
                        {selectedCount} SELECTED
                      </span>
                    </div>
                  </div>

                  {/* Quick Actions */}
                  <div className="flex items-center gap-2 mb-4 flex-wrap animate-in slide-in-from-top duration-300">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={selectAll}
                      className="text-xs text-gray-700 hover:text-gray-900 hover:bg-gray-100 hover:scale-105 transition-all duration-200"
                    >
                      Select All
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={clearSelection}
                      className="text-xs text-gray-700 hover:text-gray-900 hover:bg-gray-100 hover:scale-105 transition-all duration-200"
                    >
                      Clear All
                    </Button>
                    <div className="h-4 w-px bg-ios-divider" />
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={selectSensitiveItems}
                      className="text-xs flex items-center gap-1 text-gray-700 hover:text-gray-900 hover:bg-gray-100 hover:scale-105 transition-all duration-200"
                    >
                      <AlertTriangle className="h-3 w-3" />
                      Sensitive Only
                    </Button>
                  </div>

                  {/* Property List */}
                  {isLoading ? (
                    <div className="py-8 space-y-3">
                      {[1, 2, 3].map((i) => (
                        <div key={i} className="flex items-center gap-3 p-3 border-b border-gray-200/50 animate-pulse">
                          <div className="w-5 h-5 bg-gradient-to-r from-gray-200 to-gray-100 rounded" />
                          <div className="flex-1 space-y-2">
                            <div className="h-4 bg-gradient-to-r from-gray-200 to-gray-100 rounded w-3/4" />
                            <div className="h-3 bg-gradient-to-r from-gray-200 to-gray-100 rounded w-1/2" />
                          </div>
                          <div className="h-6 w-20 bg-gradient-to-r from-gray-200 to-gray-100 rounded-full" />
                        </div>
                      ))}
                    </div>
                  ) : properties.length === 0 ? (
                    <div className="py-8 text-center">
                      <Package className="h-8 w-8 text-gray-400 mx-auto mb-3" />
                      <p className="text-sm font-medium text-gray-700">No properties found</p>
                      <p className="text-xs text-gray-500 mt-1">Add properties to your inventory first</p>
                    </div>
                  ) : (
                    <div className="max-h-64 overflow-y-auto border border-gray-200/50 rounded-lg shadow-inner">
                      <table className="w-full">
                        <thead className="sticky top-0 bg-gray-50 border-b border-gray-200">
                          <tr>
                            <th className="w-10 p-3">
                              <Checkbox
                                checked={properties.length > 0 && selectedPropertyIds.size === properties.length}
                                onCheckedChange={() => {
                                  if (selectedPropertyIds.size === properties.length) {
                                    clearSelection();
                                  } else {
                                    selectAll();
                                  }
                                }}
                                className="rounded-sm data-[state=checked]:bg-ios-accent data-[state=checked]:border-ios-accent"
                              />
                            </th>
                            <th className="text-left p-3 text-xs font-semibold text-gray-700 uppercase tracking-wider font-mono">
                              Property Name
                            </th>
                            <th className="text-left p-3 text-xs font-semibold text-gray-700 uppercase tracking-wider font-mono">
                              Serial Number
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          {properties.map((property, index) => (
                            <tr
                              key={property.id}
                              className={`
                                cursor-pointer transition-all duration-200 hover:shadow-sm
                                ${index % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}
                                ${selectedPropertyIds.has(property.id) ? 'bg-blue-50/30 hover:bg-blue-50/50' : 'hover:bg-gray-100/50'}
                              `}
                              onClick={() => togglePropertySelection(property.id)}
                            >
                              <td className="p-3">
                                <Checkbox
                                  checked={selectedPropertyIds.has(property.id)}
                                  onChange={() => togglePropertySelection(property.id)}
                                  onClick={(e) => e.stopPropagation()}
                                  className="rounded-sm data-[state=checked]:bg-ios-accent data-[state=checked]:border-ios-accent"
                                />
                              </td>
                              <td className="p-3">
                                <div className="font-mono text-sm text-gray-900 font-medium">
                                  {property.name}
                                </div>
                              </td>
                              <td className="p-3">
                                <div className="font-mono text-sm text-gray-700">
                                  {property.serialNumber}
                                </div>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              </div>

              {/* Export Options */}
              <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl shadow-lg border border-gray-200/50 hover:shadow-xl transition-all duration-300">
                <div className="p-6">
                  <div className="mb-4">
                    <h3 className="text-sm font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 mb-1 uppercase tracking-wider font-mono">EXPORT OPTIONS</h3>
                    <p className="text-xs font-medium text-gray-600">Configure output format and delivery method</p>
                  </div>
              <div className="space-y-4">
                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="groupByCategory"
                    checked={groupByCategory}
                    onCheckedChange={(checked) => setGroupByCategory(checked === true)}
                    className="rounded-sm data-[state=checked]:bg-ios-accent data-[state=checked]:border-ios-accent transition-all duration-200"
                  />
                  <Label 
                    htmlFor="groupByCategory" 
                    className="text-sm cursor-pointer font-medium text-gray-700 hover:text-gray-900 transition-colors duration-200"
                  >
                    Group by Category
                  </Label>
                </div>
                
                    <div className="h-px bg-gradient-to-r from-transparent via-gray-300 to-transparent my-4" />
                    
                    {/* Export Mode */}
                    <div className="space-y-3">
                      <Label className="text-xs text-gray-500 font-bold uppercase tracking-wider font-mono">
                        DELIVERY METHOD
                      </Label>
                      <div className="grid grid-cols-3 gap-2 p-2 bg-gradient-to-r from-gray-50 to-gray-100/50 rounded-lg">
                        <Button
                          variant="ghost"
                          onClick={() => setExportMode('download')}
                          className={`text-sm transition-all duration-300 border-0 ${
                            exportMode === 'download' 
                              ? 'bg-blue-500 text-white shadow-lg scale-105' 
                              : 'bg-white text-gray-700 hover:text-gray-900 hover:bg-gradient-to-r hover:from-gray-100 hover:to-gray-50 hover:scale-[1.02]'
                          }`}
                        >
                          <Download className="h-4 w-4 mr-2" />
                          Download
                        </Button>
                        <Button
                          variant="ghost"
                          onClick={() => setExportMode('email')}
                          className={`text-sm transition-all duration-300 border-0 ${
                            exportMode === 'email' 
                              ? 'bg-blue-500 text-white shadow-lg scale-105' 
                              : 'bg-white text-gray-700 hover:text-gray-900 hover:bg-gradient-to-r hover:from-gray-100 hover:to-gray-50 hover:scale-[1.02]'
                          }`}
                    >
                      <Mail className="h-4 w-4 mr-2" />
                      Email
                    </Button>
                        <Button
                          variant="ghost"
                          onClick={() => setExportMode('user')}
                          className={`text-sm transition-all duration-300 border-0 ${
                            exportMode === 'user' 
                              ? 'bg-blue-500 text-white shadow-lg scale-105' 
                              : 'bg-white text-gray-700 hover:text-gray-900 hover:bg-gradient-to-r hover:from-gray-100 hover:to-gray-50 hover:scale-[1.02]'
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
                        className="text-xs text-gray-500 font-semibold uppercase tracking-wider"
                      >
                        Email Recipients (comma-separated)
                      </Label>
                      <Textarea
                        id="emailRecipients"
                        value={emailRecipients}
                        onChange={(e) => setEmailRecipients(e.target.value)}
                        placeholder="email1@example.com, email2@example.com"
                        className="mt-1 resize-none bg-gradient-to-r from-white to-gray-50 border-gray-200/50 focus:ring-2 focus:ring-ios-accent/20 transition-all duration-200"
                        rows={3}
                      />
                    </div>
                  )}
                  
                  {exportMode === 'user' && (
                    <div className="mt-4 space-y-3">
                      <Label className="text-xs text-gray-500 font-semibold uppercase tracking-wider">
                        Select Recipient
                      </Label>
                      {acceptedConnections.length === 0 ? (
                        <div className="text-center py-8 border-2 border-dashed border-gray-300 rounded-lg bg-gradient-to-br from-gray-50 to-gray-100/50 hover:border-ios-accent/50 transition-all duration-300">
                          <UserPlus className="h-8 w-8 text-gray-400 mx-auto mb-3" />
                          <p className="text-sm text-ios-primary-text font-medium mb-1">
                            No connections available
                          </p>
                          <p className="text-xs font-medium text-gray-600">
                            Add connections from the Network page
                          </p>
                        </div>
                      ) : (
                        <div className="space-y-2 max-h-48 overflow-y-auto bg-gradient-to-b from-white to-gray-50/30 rounded-lg p-2">
                          {acceptedConnections.map((connection) => (
                            <div
                              key={connection.id}
                              className={`p-3 border rounded-lg cursor-pointer transition-all duration-300 group ${
                                selectedRecipientId === connection.connectedUser?.id
                                  ? 'border-ios-accent bg-gradient-to-r from-ios-accent/10 to-ios-accent/5 shadow-md scale-[1.02]'
                                  : 'border-gray-200/50 hover:border-ios-accent/50 hover:bg-gradient-to-r hover:from-gray-50 hover:to-gray-100/50 hover:shadow-sm'
                              }`}
                              onClick={() => setSelectedRecipientId(connection.connectedUser?.id || null)}
                            >
                              <div className="flex items-center justify-between">
                                <div className="flex items-center space-x-3">
                                  <div className="w-10 h-10 rounded-full bg-gradient-to-br from-gray-100 to-gray-200 flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                                    <User className="h-5 w-5 text-secondary-text" />
                                  </div>
                                  <div>
                                    <p className="font-semibold text-sm text-gray-900">
                                      {connection.connectedUser?.name}
                                    </p>
                                    <p className="text-xs text-gray-600 font-mono font-medium">
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
            </div>
          </div>
        </div>

        <DialogFooter className="border-t border-gray-200/50 pt-4 bg-gradient-to-r from-gray-50/50 to-gray-100/30">
          <Button
            variant="ghost"
            onClick={onClose}
            disabled={isGenerating}
            className="text-blue-500 border border-blue-500 hover:bg-blue-500 hover:border-blue-500 hover:text-white font-semibold transition-all duration-200 hover:scale-105"
          >
            Cancel
          </Button>
          <Button
            onClick={handleGenerate}
            disabled={selectedCount === 0 || isGenerating}
            className="bg-blue-500 hover:bg-blue-600 text-white font-semibold shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-105 border-0"
          >
            {isGenerating ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin animate-pulse" />
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
                Download DA 2062
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