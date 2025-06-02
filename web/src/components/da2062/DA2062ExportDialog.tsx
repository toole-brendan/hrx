import React, { useState, useEffect, useCallback } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '../ui/dialog';
import { Button } from '../ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '../ui/card';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { Checkbox } from '../ui/checkbox';
import { Badge } from '../ui/badge';
import { Separator } from '../ui/separator';
import { Textarea } from '../ui/textarea';
// Note: Replace with your actual UI components
import { useToast } from '@/hooks/use-toast';
import {
  Mail,
  Download,
  FileText,
  Settings,
  Building2,
  CheckCircle,
  Circle,
  AlertTriangle,
  Filter,
  Loader2,
} from 'lucide-react';

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
}

interface GeneratePDFRequest {
  property_ids: string[];
  group_by_category: boolean;
  include_qr_codes: boolean;
  send_email: boolean;
  recipients: string[];
  from_user: UserInfo;
  to_user: UserInfo;
  unit_info: UnitInfo;
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
  const [properties, setProperties] = useState<Property[]>([]);
  const [selectedPropertyIds, setSelectedPropertyIds] = useState<Set<string>>(
    new Set(initialSelectedProperties.map(p => p.id))
  );
  const [isLoading, setIsLoading] = useState(false);
  const [isGenerating, setIsGenerating] = useState(false);
  const [exportMode, setExportMode] = useState<'download' | 'email'>('download');
  const [emailRecipients, setEmailRecipients] = useState('');
  
  // Export options
  const [groupByCategory, setGroupByCategory] = useState(true);
  const [includeQRCodes, setIncludeQRCodes] = useState(true);
  
  // Unit and user info
  const [unitInfo, setUnitInfo] = useState<UnitInfo>({
    unitName: localStorage.getItem('unit_name') || '',
    dodaac: localStorage.getItem('unit_dodaac') || '',
    stockNumber: localStorage.getItem('unit_stock_number') || '',
    location: localStorage.getItem('unit_location') || '',
  });
  
  const [userInfo, setUserInfo] = useState<UserInfo>({
    name: localStorage.getItem('user_name') || '',
    rank: localStorage.getItem('user_rank') || '',
    title: localStorage.getItem('user_title') || 'Property Book Officer',
    phone: localStorage.getItem('user_phone') || '',
  });

  const { toast } = useToast();

  // Load user properties
  useEffect(() => {
    if (isOpen) {
      loadProperties();
    }
  }, [isOpen]);

  const loadProperties = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('/api/property', {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to load properties');
      }

      const data = await response.json();
      setProperties(data);
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
    const userId = localStorage.getItem('user_id') || '1';
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

    if (exportMode === 'email' && !emailRecipients.trim()) {
      toast({
        title: 'No Recipients',
        description: 'Please enter email recipients.',
        variant: 'destructive',
      });
      return;
    }

    setIsGenerating(true);

    const request: GeneratePDFRequest = {
      property_ids: Array.from(selectedPropertyIds),
      group_by_category: groupByCategory,
      include_qr_codes: includeQRCodes,
      send_email: exportMode === 'email',
      recipients: exportMode === 'email' 
        ? emailRecipients.split(',').map(r => r.trim()).filter(r => r.length > 0)
        : [],
      from_user: userInfo,
      to_user: userInfo,
      unit_info: unitInfo,
    };

    try {
      const response = await fetch('/api/da2062/generate-pdf', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('token')}`,
        },
        body: JSON.stringify(request),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to generate PDF');
      }

      if (exportMode === 'email') {
        // Email sent successfully
        const result = await response.json();
        toast({
          title: 'Email Sent',
          description: `DA 2062 sent successfully to ${result.recipients?.length || 0} recipient(s)`,
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
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <FileText className="h-5 w-5" />
            Export DA 2062 Hand Receipt
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-6">
          {/* Unit Information */}
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="flex items-center gap-2 text-base">
                <Building2 className="h-4 w-4" />
                Unit Information
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label htmlFor="unitName" className="text-xs">Unit Name</Label>
                  <Input
                    id="unitName"
                    value={unitInfo.unitName}
                    onChange={(e) => setUnitInfo(prev => ({ ...prev, unitName: e.target.value }))}
                    className="h-8"
                  />
                </div>
                <div>
                  <Label htmlFor="dodaac" className="text-xs">DODAAC</Label>
                  <Input
                    id="dodaac"
                    value={unitInfo.dodaac}
                    onChange={(e) => setUnitInfo(prev => ({ ...prev, dodaac: e.target.value }))}
                    className="h-8"
                  />
                </div>
                <div>
                  <Label htmlFor="location" className="text-xs">Location</Label>
                  <Input
                    id="location"
                    value={unitInfo.location}
                    onChange={(e) => setUnitInfo(prev => ({ ...prev, location: e.target.value }))}
                    className="h-8"
                  />
                </div>
                <div>
                  <Label htmlFor="stockNumber" className="text-xs">Stock Number</Label>
                  <Input
                    id="stockNumber"
                    value={unitInfo.stockNumber}
                    onChange={(e) => setUnitInfo(prev => ({ ...prev, stockNumber: e.target.value }))}
                    className="h-8"
                  />
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Property Selection */}
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <CheckCircle className="h-4 w-4" />
                  Select Properties
                </div>
                <Badge variant="secondary">
                  {selectedCount} selected
                </Badge>
              </CardTitle>
            </CardHeader>
            <CardContent>
              {/* Quick Actions */}
              <div className="flex items-center gap-2 mb-4">
                <Button variant="outline" size="sm" onClick={selectAll}>
                  Select All
                </Button>
                <Button variant="outline" size="sm" onClick={clearSelection}>
                  Clear
                </Button>
                <Separator orientation="vertical" className="h-6" />
                <Button 
                  variant="outline" 
                  size="sm" 
                  onClick={() => selectByCategory('weapon')}
                >
                  Weapons Only
                </Button>
                <Button 
                  variant="outline" 
                  size="sm" 
                  onClick={() => selectByCategory('equipment')}
                >
                  Equipment Only
                </Button>
                <Button 
                  variant="outline" 
                  size="sm" 
                  onClick={selectSensitiveItems}
                >
                  <AlertTriangle className="h-3 w-3 mr-1" />
                  Sensitive Items
                </Button>
              </div>

              {/* Property List */}
                             {isLoading ? (
                 <div className="flex justify-center py-8">
                   <Loader2 className="h-6 w-6 animate-spin" />
                 </div>
               ) : (
                <div className="max-h-64 overflow-y-auto border rounded">
                  {properties.map((property) => (
                    <div
                      key={property.id}
                      className="flex items-center gap-3 p-3 border-b last:border-b-0 hover:bg-gray-50 cursor-pointer"
                      onClick={() => togglePropertySelection(property.id)}
                    >
                      <Checkbox
                        checked={selectedPropertyIds.has(property.id)}
                        onChange={() => togglePropertySelection(property.id)}
                      />
                      <div className="flex-1">
                        <div className="font-medium text-sm">{property.name}</div>
                        <div className="text-xs text-gray-500">
                          SN: {property.serialNumber}
                          {property.nsn && ` • NSN: ${property.nsn}`}
                        </div>
                      </div>
                      {property.isSensitive && (
                        <AlertTriangle className="h-4 w-4 text-orange-500" />
                      )}
                      <Badge 
                        variant={property.status === 'Operational' ? 'default' : 'secondary'}
                        className="text-xs"
                      >
                        {property.status}
                      </Badge>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>

          {/* Export Options */}
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="flex items-center gap-2 text-base">
                <Settings className="h-4 w-4" />
                Export Options
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="groupByCategory"
                  checked={groupByCategory}
                  onCheckedChange={(checked) => setGroupByCategory(checked === true)}
                />
                <Label htmlFor="groupByCategory" className="text-sm">
                  Group by Category
                </Label>
              </div>
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="includeQRCodes"
                  checked={includeQRCodes}
                  onCheckedChange={(checked) => setIncludeQRCodes(checked === true)}
                />
                <Label htmlFor="includeQRCodes" className="text-sm">
                  Include QR Codes
                </Label>
              </div>

              <Separator />

              {/* Export Mode */}
              <div className="space-y-3">
                <Label className="text-sm font-medium">Export Method</Label>
                <div className="grid grid-cols-2 gap-2">
                  <Button
                    variant={exportMode === 'download' ? 'default' : 'outline'}
                    onClick={() => setExportMode('download')}
                    className="justify-start"
                  >
                    <Download className="h-4 w-4 mr-2" />
                    Download PDF
                  </Button>
                  <Button
                    variant={exportMode === 'email' ? 'default' : 'outline'}
                    onClick={() => setExportMode('email')}
                    className="justify-start"
                  >
                    <Mail className="h-4 w-4 mr-2" />
                    Email PDF
                  </Button>
                </div>

                {exportMode === 'email' && (
                  <div>
                    <Label htmlFor="emailRecipients" className="text-xs">
                      Email Recipients (comma-separated)
                    </Label>
                    <Textarea
                      id="emailRecipients"
                      value={emailRecipients}
                      onChange={(e) => setEmailRecipients(e.target.value)}
                      placeholder="email1@example.com, email2@example.com"
                      className="h-20"
                    />
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={onClose} disabled={isGenerating}>
            Cancel
          </Button>
          <Button 
            onClick={handleGenerate} 
            disabled={selectedCount === 0 || isGenerating}
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
  );
}; 