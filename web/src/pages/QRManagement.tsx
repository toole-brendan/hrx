import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { useToast } from "@/hooks/use-toast";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { PageWrapper } from "@/components/ui/page-wrapper";
import { PageHeader } from "@/components/ui/page-header";
import { Separator } from "@/components/ui/separator";
import { Printer, QrCode, RefreshCw, AlertTriangle, Plus, Tag, ArrowUpDown, Filter, Search, X, Calendar, Clock } from "lucide-react";
import QRCodeGenerator from "@/components/common/QRCodeGenerator";
import { inventory } from "@/lib/mockData";
import { InventoryItem } from "@/types";
import { subDays, addDays, format } from "date-fns";

// Interface for QR code item
interface QRCodeItem extends InventoryItem {
  qrCodeStatus: "active" | "damaged" | "missing" | "replaced";
  lastPrinted?: string;
  lastUpdated?: string;
}

// Generate realistic military equipment mock data
const generateMilitaryMockData = (): QRCodeItem[] => {
  const today = new Date();
  const oneYearAgo = subDays(today, 365);
  
  const equipmentTypes = [
    // Weapons
    {category: "weapon", items: [
      {name: "M4A1 Carbine", serialPrefix: "W"},
      {name: "M17 Pistol", serialPrefix: "P"},
      {name: "M249 SAW", serialPrefix: "S"}
    ]},
    // Optics
    {category: "optics", items: [
      {name: "ACOG RCO", serialPrefix: "RCO"},
      {name: "Aimpoint CCO", serialPrefix: "CCO"},
      {name: "AN/PEQ-15", serialPrefix: "PEQ"},
      {name: "AN/PVS-14 NVG", serialPrefix: "NVG"}
    ]},
    // Comms
    {category: "communication", items: [
      {name: "PRC-152 Radio", serialPrefix: "R"},
      {name: "PRC-148 Radio", serialPrefix: "HR"},
      {name: "SINCGARS Radio", serialPrefix: "SR"}
    ]},
    // Support
    {category: "other", items: [
      {name: "Tool Kit", serialPrefix: "TK"},
      {name: "MEP-803A Generator", serialPrefix: "G"},
      {name: "IOTV Vest", serialPrefix: "V"},
      {name: "ACH Helmet", serialPrefix: "H"}
    ]}
  ];
  
  const generateRandomDate = (start: Date, end: Date) => {
    return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime())).toISOString().split('T')[0];
  };
  
  const generateSerialNumber = (prefix: string) => {
    return `${prefix}${Math.floor(100000 + Math.random() * 900000)}`;
  };
  
  const items: QRCodeItem[] = [];
  
  // Generate 25-30 items
  const itemCount = 25 + Math.floor(Math.random() * 5);
  
  for (let i = 0; i < itemCount; i++) {
    const typeGroup = equipmentTypes[Math.floor(Math.random() * equipmentTypes.length)];
    const equipmentType = typeGroup.items[Math.floor(Math.random() * typeGroup.items.length)];
    const serialNumber = generateSerialNumber(equipmentType.serialPrefix);
    const assignedDate = generateRandomDate(oneYearAgo, today);
    
    // Determine QR code status with realistic distribution
    let qrCodeStatus: "active" | "damaged" | "missing" | "replaced" = "active";
    const statusRoll = Math.random();
    if (statusRoll > 0.90) qrCodeStatus = "damaged";
    else if (statusRoll > 0.85) qrCodeStatus = "missing";
    else if (statusRoll > 0.75) qrCodeStatus = "replaced";
    
    const lastUpdated = generateRandomDate(new Date(assignedDate), today);
    
    // For replaced codes, ensure lastPrinted is after lastUpdated
    let lastPrinted = qrCodeStatus === "replaced" 
        ? generateRandomDate(new Date(lastUpdated), today) 
        : Math.random() > 0.3 ? assignedDate : undefined;
    
    items.push({
      id: `qr-${equipmentType.name.toLowerCase().replace(/\s+/g, '-')}-${serialNumber}`,
      name: equipmentType.name,
      serialNumber,
      assignedDate,
      status: "Operational",
      description: `Standard issue ${equipmentType.name}`,
      category: typeGroup.category,
      location: "A Co, 2-1 INF",
      qrCodeStatus,
      lastUpdated,
      lastPrinted
    });
  }
  
  return items;
};

// Mock data for QR code items using the generator
const mockQRItems: QRCodeItem[] = generateMilitaryMockData();

interface QRManagementProps {
  code?: string;
}

const QRManagement: React.FC<QRManagementProps> = ({ code }) => {
  const [qrItems, setQrItems] = useState<QRCodeItem[]>(mockQRItems);
  const [filteredItems, setFilteredItems] = useState<QRCodeItem[]>(mockQRItems);
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [isReportDialogOpen, setIsReportDialogOpen] = useState(false);
  const [isPrintDialogOpen, setIsPrintDialogOpen] = useState(false);
  const [isGenerateDialogOpen, setIsGenerateDialogOpen] = useState(false);
  const [selectedItem, setSelectedItem] = useState<QRCodeItem | null>(null);
  const [newItemInfo, setNewItemInfo] = useState({ name: "", serialNumber: "" });
  const [reportReason, setReportReason] = useState("");
  const { toast } = useToast();
  const [qrValue, setQrValue] = useState("");
  const [qrDetailsOpen, setQrDetailsOpen] = useState(false);

  // Apply filters
  useEffect(() => {
    let result = qrItems;
    
    // Apply search filter
    if (searchTerm) {
      result = result.filter(
        (item) => 
          item.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
          item.serialNumber.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }
    
    // Apply status filter
    if (statusFilter !== "all") {
      result = result.filter((item) => item.qrCodeStatus === statusFilter);
    }
    
    setFilteredItems(result);
  }, [qrItems, searchTerm, statusFilter]);

  // If a code is provided, find and show the specific QR code
  useEffect(() => {
    if (code) {
      // Show the provided QR code
      setQrValue(code);
      setQrDetailsOpen(true);
    }
  }, [code]);

  // Handle opening the report dialog
  const handleOpenReportDialog = (item: QRCodeItem) => {
    setSelectedItem(item);
    setIsReportDialogOpen(true);
  };

  // Handle opening the print dialog
  const handleOpenPrintDialog = (item: QRCodeItem) => {
    setSelectedItem(item);
    setIsPrintDialogOpen(true);
  };

  // Handle opening the generate dialog
  const handleOpenGenerateDialog = () => {
    setNewItemInfo({ name: "", serialNumber: "" });
    setIsGenerateDialogOpen(true);
  };

  // Handle reporting a damaged QR code
  const handleReportDamaged = () => {
    if (selectedItem && reportReason) {
      // Update the QR code status in the list
      const updatedItems = qrItems.map(item => 
        item.id === selectedItem.id ? { ...item, qrCodeStatus: "damaged" as const } : item
      );
      
      setQrItems(updatedItems);
      
      toast({
        title: "QR Code Reported",
        description: `The QR code for ${selectedItem.name} has been reported as damaged.`,
      });
      
      setIsReportDialogOpen(false);
      setReportReason("");
    }
  };

  // Handle printing a QR code
  const handlePrintQRCode = () => {
    if (selectedItem) {
      // Simulate opening a print preview in a new window
      const printWindow = window.open('', '_blank');
      if (printWindow) {
        printWindow.document.write(`
          <html>
            <head>
              <title>Print QR Code - ${selectedItem.name}</title>
              <style>
                body { font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto; }
                .print-container { display: flex; flex-direction: column; align-items: center; }
                .qr-container { border: 1px solid #ccc; padding: 30px; margin: 20px 0; }
                .item-details { margin-bottom: 30px; text-align: center; }
                .serial { font-family: monospace; margin-top: 5px; }
                .instructions { color: #555; font-size: 12px; margin-top: 30px; }
                @media print {
                  .no-print { display: none; }
                  button { display: none; }
                }
              </style>
            </head>
            <body>
              <div class="print-container">
                <div class="item-details">
                  <h2>${selectedItem.name}</h2>
                  <div class="serial">SN: ${selectedItem.serialNumber}</div>
                </div>
                <div class="qr-container">
                  <img src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${selectedItem.name}|${selectedItem.serialNumber}" alt="QR Code" />
                </div>
                <div class="instructions">
                  <p>1. Print this page</p>
                  <p>2. Cut along the dotted line</p>
                  <p>3. Attach securely to the equipment</p>
                </div>
                <button class="no-print" onclick="window.print()" style="margin-top: 20px; padding: 10px 15px; background: #3B5BDB; color: white; border: none; cursor: pointer;">
                  Print QR Code
                </button>
              </div>
            </body>
          </html>
        `);
        printWindow.document.close();
      }
      
      // In a real application, this would trigger a print process
      // Update the last printed date
      const updatedItems = qrItems.map(item => 
        item.id === selectedItem.id 
          ? { 
              ...item, 
              lastPrinted: new Date().toISOString().split('T')[0],
              qrCodeStatus: (item.qrCodeStatus === "damaged" || item.qrCodeStatus === "missing") ? 
                "replaced" as const : 
                "active" as const
            } 
          : item
      );
      
      setQrItems(updatedItems);
      
      toast({
        title: "QR Code Print Preview Generated",
        description: `The QR code for ${selectedItem.name} has been prepared for printing.`,
      });
      
      setIsPrintDialogOpen(false);
    }
  };

  // Handle generating a new QR code
  const handleGenerateNewQRCode = () => {
    if (newItemInfo.name && newItemInfo.serialNumber) {
      // In a real application, this would create a new item with a QR code
      const newItem: QRCodeItem = {
        id: `qr-${Date.now()}`,
        name: newItemInfo.name,
        serialNumber: newItemInfo.serialNumber,
        assignedDate: new Date().toISOString().split('T')[0],
        status: "Operational",
        description: "Newly generated item",
        category: "other",
        location: "Inventory",
        qrCodeStatus: "active",
        lastUpdated: new Date().toISOString().split('T')[0],
        lastPrinted: new Date().toISOString().split('T')[0]
      };
      
      setQrItems([newItem, ...qrItems]);
      
      toast({
        title: "QR Code Generated",
        description: `A new QR code for ${newItemInfo.name} has been created.`,
      });
      
      setIsGenerateDialogOpen(false);
      setNewItemInfo({ name: "", serialNumber: "" });
    }
  };

  // Function to batch replace damaged QR codes
  const handleBatchReplaceDamaged = async () => {
    const damagedItems = qrItems.filter(item => item.qrCodeStatus === "damaged");
    
    if (damagedItems.length === 0) {
      toast({
        title: "No Damaged QR Codes",
        description: "There are no damaged QR codes to replace.",
      });
      return;
    }
    
    // Initial toast to show starting the process
    toast({
      title: "Batch Replace Started",
      description: `Processing ${damagedItems.length} damaged QR codes...`,
    });
    
    // Simulate processing time
    await new Promise(resolve => setTimeout(resolve, 1200));
    
    // Update all damaged QR codes to replaced
    const updatedItems = qrItems.map(item => 
      item.qrCodeStatus === "damaged" 
        ? { 
            ...item, 
            qrCodeStatus: "replaced" as const,
            lastPrinted: new Date().toISOString().split('T')[0]
          } 
        : item
    );
    
    setQrItems(updatedItems);
    
    // Success toast with detailed information
    toast({
      title: "Batch Replace Complete",
      description: `${damagedItems.length} QR codes have been replaced and queued for printing.`,
    });
    
    // If we're currently in the damaged tab, switch to show all
    if (statusFilter === "damaged") {
      setStatusFilter("replaced");
      
      // Show toast indicating we switched views
      setTimeout(() => {
        toast({
          title: "View Updated",
          description: "Showing newly replaced QR codes.",
        });
      }, 500);
    }
  };

  // Function to clear all filters
  const clearFilters = () => {
    setSearchTerm("");
    setStatusFilter("all");
  };

  // Format date in DDMMMYYYY format with month in all caps
  const formatMilitaryDate = (date: Date | string | undefined): string => {
    if (!date) return 'N/A';
    
    try {
      // Ensure we have a Date object
      const dateObj = typeof date === 'string' ? new Date(date) : date;
      
      // Check if date is valid
      if (isNaN(dateObj.getTime())) return 'INVALID';
      
      // Format as ddMMMyyyy
      const formatted = format(dateObj, 'ddMMMyyyy');
      // Extract the month part (characters 2-5) and convert to uppercase
      const day = formatted.substring(0, 2);
      const month = formatted.substring(2, 5).toUpperCase();
      const year = formatted.substring(5);
      return `${day}${month}${year}`;
    } catch (error) {
      console.error('Error formatting date:', error);
      return 'ERROR';
    }
  };

  // Render QR code status badge
  const renderStatusBadge = (status: QRCodeItem["qrCodeStatus"]) => {
    switch (status) {
      case "active":
        return <Badge className="bg-green-500 hover:bg-green-600">Active</Badge>;
      case "damaged":
        return <Badge className="bg-red-500 hover:bg-red-600">Damaged</Badge>;
      case "missing":
        return <Badge className="bg-yellow-500 hover:bg-yellow-600">Missing</Badge>;
      case "replaced":
        return <Badge className="bg-blue-500 hover:bg-blue-600">Replaced</Badge>;
      default:
        return null;
    }
  };

  return (
    <PageWrapper withPadding={true}>
      {/* Header */}
      <div className="pt-16 pb-10">
        <div className="text-xs uppercase tracking-wider font-medium mb-1 text-muted-foreground">
          QR MANAGEMENT
        </div>
        
        <div className="flex flex-col sm:flex-row sm:items-center justify-between space-y-4 sm:space-y-0">
          <div>
            <h1 className="text-3xl font-light tracking-tight mb-1">QR Code Administration</h1>
            <p className="text-sm text-muted-foreground">Generate, print, replace, and manage QR codes for equipment</p>
          </div>
          <Button 
            onClick={handleOpenGenerateDialog} 
            variant="blue"
            size="sm"
            className="h-9 px-3 flex items-center gap-1.5"
          >
            <Plus className="h-4 w-4" />
            <span className="text-xs uppercase tracking-wider">Generate New QR Code</span>
          </Button>
        </div>
      </div>
      
      <Tabs defaultValue="all">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
            <div className="overflow-x-auto pb-1">
              <TabsList className="grid grid-cols-3 w-full h-10 rounded-none border border-border">
                <TabsTrigger 
                  value="all" 
                  className="text-xs uppercase tracking-wider rounded-none"
                >
                  All QR Codes
                </TabsTrigger>
                <TabsTrigger 
                  value="damaged" 
                  className="text-xs uppercase tracking-wider rounded-none"
                >
                  Damaged
                </TabsTrigger>
                <TabsTrigger 
                  value="reports" 
                  className="text-xs uppercase tracking-wider rounded-none"
                >
                  Reports
                </TabsTrigger>
              </TabsList>
            </div>
            
            <Button 
              variant="outline" 
              onClick={handleBatchReplaceDamaged}
              size="sm"
              className="h-9 px-3 flex items-center gap-1.5"
            >
              <RefreshCw className="h-4 w-4 mr-2" />
              <span className="text-xs uppercase tracking-wider">Replace Damaged</span>
            </Button>
          </div>
          
          <Card className="mb-6 border-border shadow-none bg-card">
            <CardContent className="p-4 flex flex-col md:flex-row md:items-center gap-4">
              <div className="relative flex-1 min-w-0">
                <Search className="absolute left-2.5 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search by name or serial number"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="pl-8 w-full rounded-none"
                />
                {searchTerm && (
                  <Button 
                    variant="ghost" 
                    className="absolute right-0 top-0 h-full px-3" 
                    onClick={() => setSearchTerm("")}
                  >
                    <X className="h-4 w-4" />
                  </Button>
                )}
              </div>
              
              <div className="flex flex-wrap gap-2">
                <Select value={statusFilter} onValueChange={setStatusFilter}>
                  <SelectTrigger className="w-[140px] sm:w-[180px] rounded-none">
                    <div className="flex items-center truncate">
                      <Filter className="mr-2 flex-shrink-0 h-4 w-4" />
                      <span className="truncate">Status: {statusFilter === "all" ? "All" : statusFilter}</span>
                    </div>
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Statuses</SelectItem>
                    <SelectItem value="active">Active</SelectItem>
                    <SelectItem value="damaged">Damaged</SelectItem>
                    <SelectItem value="missing">Missing</SelectItem>
                    <SelectItem value="replaced">Replaced</SelectItem>
                  </SelectContent>
                </Select>
                
                {(searchTerm || statusFilter !== "all") && (
                  <Button 
                    variant="ghost" 
                    onClick={clearFilters}
                    size="sm"
                    className="h-9 px-3 flex items-center gap-1.5"
                  >
                    <span className="text-xs uppercase tracking-wider">Clear Filters</span>
                  </Button>
                )}
              </div>
            </CardContent>
          </Card>

          <TabsContent value="all" className="space-y-4">
            {filteredItems.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {filteredItems.map((item) => (
                  <Card key={item.id} className="overflow-hidden border-border shadow-none bg-card rounded-none">
                    <CardContent className="p-0">
                      <div className="p-4">
                        <div className="uppercase text-xs tracking-wider font-medium mb-1 text-muted-foreground">
                          QR CODE #{item.id.substring(0, 8)}
                        </div>
                        <div className="flex justify-between items-start mb-3">
                          <div>
                            <h3 className="text-lg font-normal">{item.name}</h3>
                            <div className="text-sm font-mono text-muted-foreground">SN: {item.serialNumber}</div>
                          </div>
                          <Badge className="uppercase text-[10px] tracking-wider font-medium rounded-none py-0.5 px-2.5"
                            variant="outline"
                            {...(() => {
                              switch (item.qrCodeStatus) {
                                case "active":
                                  return {
                                    className: "bg-green-50 text-green-800 dark:bg-green-900/20 dark:text-green-400 border-green-200 dark:border-green-900/30"
                                  };
                                case "damaged":
                                  return {
                                    className: "bg-red-50 text-red-800 dark:bg-red-900/20 dark:text-red-400 border-red-200 dark:border-red-900/30"
                                  };
                                case "missing":
                                  return {
                                    className: "bg-amber-50 text-amber-800 dark:bg-amber-900/20 dark:text-amber-400 border-amber-200 dark:border-amber-900/30"
                                  };
                                case "replaced":
                                  return {
                                    className: "bg-blue-50 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400 border-blue-200 dark:border-blue-900/30"
                                  };
                                default:
                                  return {};
                              }
                            })()}
                          >
                            {item.qrCodeStatus.toUpperCase()}
                          </Badge>
                        </div>
                      </div>
                      
                      <div className={`flex justify-center py-4 px-4 bg-muted/30 relative border-t-2 ${
                        item.qrCodeStatus === "active" ? "border-t-green-500/50" : 
                        item.qrCodeStatus === "damaged" ? "border-t-red-500/50" : 
                        item.qrCodeStatus === "missing" ? "border-t-amber-500/50" :
                        "border-t-blue-500/50"
                      }`}>
                        <QRCodeGenerator 
                          itemName={item.name} 
                          serialNumber={item.serialNumber} 
                        />
                        {item.qrCodeStatus !== "active" && (
                          <div className="absolute top-2 right-2 p-1 rounded-full bg-card shadow-sm">
                            {item.qrCodeStatus === "damaged" && <AlertTriangle className="h-4 w-4 text-red-500" />}
                            {item.qrCodeStatus === "missing" && <Search className="h-4 w-4 text-amber-500" />}
                            {item.qrCodeStatus === "replaced" && <RefreshCw className="h-4 w-4 text-blue-500" />}
                          </div>
                        )}
                      </div>
                      
                      <div className="px-4 py-3 border-t border-border">
                        <div className="grid grid-cols-2 gap-y-2 gap-x-4 text-sm">
                          <div className="flex items-center">
                            <Calendar className="h-3.5 w-3.5 text-muted-foreground mr-1.5" />
                            <span className="text-xs text-muted-foreground">Assigned:</span>
                            <span className="ml-1 text-xs font-medium">{formatMilitaryDate(item.assignedDate)}</span>
                          </div>
                          <div className="flex items-center">
                            <Clock className="h-3.5 w-3.5 text-muted-foreground mr-1.5" />
                            <span className="text-xs text-muted-foreground">Status:</span>
                            <span className="ml-1 text-xs font-medium">{item.status}</span>
                          </div>
                          {item.lastPrinted && (
                            <div className="flex items-center">
                              <Printer className="h-3.5 w-3.5 text-muted-foreground mr-1.5" />
                              <span className="text-xs text-muted-foreground">Printed:</span>
                              <span className="ml-1 text-xs font-medium">{formatMilitaryDate(item.lastPrinted)}</span>
                            </div>
                          )}
                          {item.lastUpdated && (
                            <div className="flex items-center">
                              <RefreshCw className="h-3.5 w-3.5 text-muted-foreground mr-1.5" />
                              <span className="text-xs text-muted-foreground">Updated:</span>
                              <span className="ml-1 text-xs font-medium">{formatMilitaryDate(item.lastUpdated)}</span>
                            </div>
                          )}
                        </div>
                      </div>
                      
                      <div className="px-4 py-3 border-t border-border flex justify-between">
                        <Button 
                          variant="outline" 
                          size="sm"
                          onClick={() => handleOpenPrintDialog(item)}
                          className="h-9 px-3 flex items-center gap-1.5"
                        >
                          <Printer className="h-4 w-4 mr-2" />
                          <span className="text-xs uppercase tracking-wider">Print</span>
                        </Button>
                        {item.qrCodeStatus !== "damaged" ? (
                          <Button 
                            variant="outline" 
                            size="sm"
                            className="h-9 px-3 flex items-center gap-1.5 text-red-600 border-red-200 hover:bg-red-50 dark:text-red-400 dark:border-red-900/30 dark:hover:bg-red-900/20"
                            onClick={() => handleOpenReportDialog(item)}
                          >
                            <AlertTriangle className="h-4 w-4 mr-2" />
                            <span className="text-xs uppercase tracking-wider">Report Issue</span>
                          </Button>
                        ) : (
                          <Button 
                            variant="outline" 
                            size="sm"
                            className="h-9 px-3 flex items-center gap-1.5 text-blue-600 border-blue-200 hover:bg-blue-50 dark:text-blue-400 dark:border-blue-900/30 dark:hover:bg-blue-900/20"
                            onClick={() => handleOpenPrintDialog(item)}
                          >
                            <RefreshCw className="h-4 w-4 mr-2" />
                            <span className="text-xs uppercase tracking-wider">Replace</span>
                          </Button>
                        )}
                      </div>
                    </CardContent>
                  </Card>
                ))}
              </div>
            ) : (
              <Card className="border-border shadow-none bg-card rounded-none">
                <CardContent className="p-8 flex flex-col items-center justify-center text-center">
                  <QrCode className="h-12 w-12 text-muted-foreground mb-4" />
                  <h3 className="text-lg font-normal mb-2">No QR Codes Found</h3>
                  <p className="text-sm text-muted-foreground mb-4">
                    {searchTerm || statusFilter !== "all"
                      ? "No QR codes match your filter criteria. Try adjusting your filters."
                      : "There are no QR codes in the system yet. Generate a new QR code to get started."}
                  </p>
                  <Button 
                    onClick={handleOpenGenerateDialog} 
                    variant="blue"
                    size="sm"
                    className="h-9 px-3 flex items-center gap-1.5"
                  >
                    <Plus className="h-4 w-4 mr-2" />
                    <span className="text-xs uppercase tracking-wider">Generate QR Code</span>
                  </Button>
                </CardContent>
              </Card>
            )}
          </TabsContent>
          
          <TabsContent value="damaged">
            {qrItems.filter(item => item.qrCodeStatus === "damaged").length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {qrItems
                  .filter(item => item.qrCodeStatus === "damaged")
                  .map((item) => (
                    <Card key={item.id} className="overflow-hidden border-border shadow-none bg-card rounded-none">
                      <CardContent className="p-0">
                        <div className="p-4">
                          <div className="uppercase text-xs tracking-wider font-medium mb-1 text-red-600 dark:text-red-400">
                            DAMAGED QR CODE
                          </div>
                          <div className="flex justify-between items-start mb-3">
                            <div>
                              <h3 className="text-lg font-normal">{item.name}</h3>
                              <div className="text-sm font-mono text-muted-foreground">SN: {item.serialNumber}</div>
                            </div>
                            <Badge 
                              variant="outline"
                              className="uppercase text-[10px] tracking-wider font-medium rounded-none py-0.5 px-2.5 bg-red-50 text-red-800 dark:bg-red-900/20 dark:text-red-400 border-red-200 dark:border-red-900/30"
                            >
                              DAMAGED
                            </Badge>
                          </div>
                        </div>
                        
                        <div className={`flex justify-center py-4 px-4 bg-muted/30 relative border-t-2 border-t-red-500/50`}>
                          <QRCodeGenerator 
                            itemName={item.name} 
                            serialNumber={item.serialNumber} 
                          />
                          <div className="absolute top-2 right-2 p-1 rounded-full bg-card shadow-sm">
                            <AlertTriangle className="h-4 w-4 text-red-500" />
                          </div>
                          <div className="absolute inset-0 bg-red-500/10 flex items-center justify-center">
                            <AlertTriangle className="h-12 w-12 text-red-500 opacity-30" />
                          </div>
                        </div>
                        
                        <div className="px-4 py-3 border-t border-border">
                          <div className="grid grid-cols-2 gap-y-2 gap-x-4 text-sm">
                            <div className="flex items-center">
                              <Calendar className="h-3.5 w-3.5 text-muted-foreground mr-1.5" />
                              <span className="text-xs text-muted-foreground">Assigned:</span>
                              <span className="ml-1 text-xs font-medium">{formatMilitaryDate(item.assignedDate)}</span>
                            </div>
                            <div className="flex items-center">
                              <Clock className="h-3.5 w-3.5 text-muted-foreground mr-1.5" />
                              <span className="text-xs text-muted-foreground">Status:</span>
                              <span className="ml-1 text-xs font-medium">{item.status}</span>
                            </div>
                            {item.lastUpdated && (
                              <div className="flex items-center">
                                <AlertTriangle className="h-3.5 w-3.5 text-red-500 mr-1.5" />
                                <span className="text-xs text-muted-foreground">Reported:</span>
                                <span className="ml-1 text-xs font-medium">{formatMilitaryDate(item.lastUpdated)}</span>
                              </div>
                            )}
                          </div>
                        </div>
                        
                        <div className="px-4 py-3 border-t border-border flex justify-center">
                          <Button 
                            variant="blue"
                            size="sm"
                            className="h-9 px-3 flex items-center gap-1.5"
                            onClick={() => handleOpenPrintDialog(item)}
                          >
                            <RefreshCw className="h-4 w-4 mr-2" />
                            <span className="text-xs uppercase tracking-wider">Replace QR Code</span>
                          </Button>
                        </div>
                      </CardContent>
                    </Card>
                  ))}
              </div>
            ) : (
              <Card className="border-border shadow-none bg-card rounded-none">
                <CardContent className="p-8 flex flex-col items-center justify-center text-center">
                  <QrCode className="h-12 w-12 text-muted-foreground mb-4" />
                  <h3 className="text-lg font-normal mb-2">No Damaged QR Codes</h3>
                  <p className="text-sm text-muted-foreground">
                    There are currently no reported damaged QR codes in the system.
                  </p>
                </CardContent>
              </Card>
            )}
          </TabsContent>
          
          <TabsContent value="reports">
            <Card className="border-border shadow-none bg-card rounded-none">
              <CardContent className="p-0">
                <div className="p-4">
                  <div className="uppercase text-xs tracking-wider font-medium mb-1 text-muted-foreground">
                    QR CODE REPORTS
                  </div>
                  <h3 className="text-lg font-normal mb-3">Activity Summary</h3>
                </div>
                
                <div className="px-4">
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                    <div className="p-4 border border-border bg-card">
                      <h4 className="text-[10px] uppercase tracking-wider font-medium text-muted-foreground mb-1">TOTAL QR CODES</h4>
                      <div className="text-2xl font-light tracking-tight">{qrItems.length}</div>
                      <p className="text-xs tracking-wide text-muted-foreground mt-0.5">Active inventory items</p>
                    </div>
                    <div className="p-4 border border-border bg-card">
                      <h4 className="text-[10px] uppercase tracking-wider font-medium text-muted-foreground mb-1">DAMAGED CODES</h4>
                      <div className="text-2xl font-light tracking-tight">{qrItems.filter(item => item.qrCodeStatus === "damaged").length}</div>
                      <p className="text-xs tracking-wide text-muted-foreground mt-0.5">Pending replacement</p>
                    </div>
                    <div className="p-4 border border-border bg-card">
                      <h4 className="text-[10px] uppercase tracking-wider font-medium text-muted-foreground mb-1">REPLACED CODES</h4>
                      <div className="text-2xl font-light tracking-tight">{qrItems.filter(item => item.qrCodeStatus === "replaced").length}</div>
                      <p className="text-xs tracking-wide text-muted-foreground mt-0.5">Last 30 days</p>
                    </div>
                  </div>
                </div>
                
                <div className="p-4 border-t border-border">
                  <div className="uppercase text-xs tracking-wider font-medium mb-4 text-muted-foreground">
                    RECENT ACTIVITY LOG
                  </div>
                  
                  {/* Add status distribution chart */}
                  <div className="mb-6 p-4 border border-border">
                    <h4 className="text-sm font-medium mb-3">QR Code Status Distribution</h4>
                    <div className="h-8 w-full flex rounded-md overflow-hidden">
                      {/* Simple bar chart representation */}
                      <div 
                        className="bg-green-500 h-full" 
                        style={{width: `${(qrItems.filter(i => i.qrCodeStatus === "active").length / qrItems.length) * 100}%`}}
                        title="Active"
                      />
                      <div 
                        className="bg-red-500 h-full" 
                        style={{width: `${(qrItems.filter(i => i.qrCodeStatus === "damaged").length / qrItems.length) * 100}%`}}
                        title="Damaged"
                      />
                      <div 
                        className="bg-amber-500 h-full" 
                        style={{width: `${(qrItems.filter(i => i.qrCodeStatus === "missing").length / qrItems.length) * 100}%`}}
                        title="Missing"
                      />
                      <div 
                        className="bg-blue-500 h-full" 
                        style={{width: `${(qrItems.filter(i => i.qrCodeStatus === "replaced").length / qrItems.length) * 100}%`}}
                        title="Replaced"
                      />
                    </div>
                    <div className="flex justify-between mt-2 text-xs">
                      <span className="flex items-center"><span className="w-3 h-3 bg-green-500 mr-1 inline-block"></span> Active ({qrItems.filter(i => i.qrCodeStatus === "active").length})</span>
                      <span className="flex items-center"><span className="w-3 h-3 bg-red-500 mr-1 inline-block"></span> Damaged ({qrItems.filter(i => i.qrCodeStatus === "damaged").length})</span>
                      <span className="flex items-center"><span className="w-3 h-3 bg-amber-500 mr-1 inline-block"></span> Missing ({qrItems.filter(i => i.qrCodeStatus === "missing").length})</span>
                      <span className="flex items-center"><span className="w-3 h-3 bg-blue-500 mr-1 inline-block"></span> Replaced ({qrItems.filter(i => i.qrCodeStatus === "replaced").length})</span>
                    </div>
                  </div>
                  
                  <div className="overflow-hidden border border-border">
                    <table className="w-full caption-bottom text-sm">
                      <thead>
                        <tr className="border-b border-border bg-muted/50">
                          <th className="h-9 px-4 text-left align-middle text-[10px] uppercase tracking-wider font-medium text-muted-foreground">Date</th>
                          <th className="h-9 px-4 text-left align-middle text-[10px] uppercase tracking-wider font-medium text-muted-foreground">Item</th>
                          <th className="h-9 px-4 text-left align-middle text-[10px] uppercase tracking-wider font-medium text-muted-foreground">Serial Number</th>
                          <th className="h-9 px-4 text-left align-middle text-[10px] uppercase tracking-wider font-medium text-muted-foreground">Action</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr className="border-b border-border hover:bg-muted/50">
                          <td className="p-4 align-middle">{formatMilitaryDate(new Date())}</td>
                          <td className="p-4 align-middle">M4 Carbine</td>
                          <td className="p-4 align-middle font-mono text-xs">SN12345678</td>
                          <td className="p-4 align-middle">
                            <div className="flex items-center">
                              <RefreshCw className="h-3.5 w-3.5 text-blue-500 mr-2" />
                              <span>QR Code Replaced</span>
                            </div>
                          </td>
                        </tr>
                        <tr className="border-b border-border hover:bg-muted/50">
                          <td className="p-4 align-middle">{formatMilitaryDate(new Date(Date.now() - 86400000))}</td>
                          <td className="p-4 align-middle">Night Vision Goggles</td>
                          <td className="p-4 align-middle font-mono text-xs">NVG87654321</td>
                          <td className="p-4 align-middle">
                            <div className="flex items-center">
                              <Plus className="h-3.5 w-3.5 text-green-500 mr-2" />
                              <span>QR Code Generated</span>
                            </div>
                          </td>
                        </tr>
                        <tr className="border-b border-border hover:bg-muted/50">
                          <td className="p-4 align-middle">{formatMilitaryDate(new Date(Date.now() - 172800000))}</td>
                          <td className="p-4 align-middle">Radio Set</td>
                          <td className="p-4 align-middle font-mono text-xs">RS98765432</td>
                          <td className="p-4 align-middle">
                            <div className="flex items-center">
                              <AlertTriangle className="h-3.5 w-3.5 text-red-500 mr-2" />
                              <span>Damaged QR Code Reported</span>
                            </div>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>

      {/* Report Damaged QR Code Dialog */}
      <Dialog open={isReportDialogOpen} onOpenChange={setIsReportDialogOpen}>
        <DialogContent className="sm:max-w-[425px] rounded-none border-border shadow-none bg-card">
          <DialogHeader className="pb-2">
            <div className="uppercase text-xs tracking-wider font-medium mb-1 text-red-600 dark:text-red-400">
              REPORT ISSUE
            </div>
            <DialogTitle className="text-lg font-normal">Damaged QR Code</DialogTitle>
            <DialogDescription className="text-sm text-muted-foreground mt-1">
              Report a damaged or unreadable QR code for replacement.
            </DialogDescription>
          </DialogHeader>
          <Separator />
          <div className="py-4">
            {selectedItem && (
              <>
                <div className="space-y-4">
                  <div className="space-y-2">
                    <div className="uppercase text-[10px] tracking-wider font-medium text-muted-foreground">
                      ITEM DETAILS
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm">
                      <div>
                        <span className="text-muted-foreground">Name:</span>
                        <span className="ml-1 font-medium">{selectedItem.name}</span>
                      </div>
                      <div>
                        <span className="text-muted-foreground">Serial Number:</span>
                        <span className="ml-1 font-medium font-mono">{selectedItem.serialNumber}</span>
                      </div>
                    </div>
                  </div>
                  
                  <div className="space-y-2">
                    <div className="uppercase text-[10px] tracking-wider font-medium text-muted-foreground">
                      REASON FOR REPORT
                    </div>
                    <Input
                      id="reason"
                      placeholder="Enter reason for damaged QR code"
                      className="w-full rounded-none"
                      value={reportReason}
                      onChange={(e) => setReportReason(e.target.value)}
                    />
                    <p className="text-xs text-muted-foreground italic">
                      Please provide a brief description of the issue with this QR code.
                    </p>
                  </div>
                </div>
              </>
            )}
          </div>
          <Separator />
          <DialogFooter className="pt-4">
            <Button 
              variant="outline" 
              onClick={() => setIsReportDialogOpen(false)}
              className="rounded-none"
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={handleReportDamaged}
              disabled={!reportReason}
              className="rounded-none"
            >
              <AlertTriangle className="h-4 w-4 mr-2" />
              Report Damaged
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Print QR Code Dialog */}
      <Dialog open={isPrintDialogOpen} onOpenChange={setIsPrintDialogOpen}>
        <DialogContent className="sm:max-w-[550px] rounded-none border-border shadow-none bg-card">
          <DialogHeader className="pb-2">
            <div className="uppercase text-xs tracking-wider font-medium mb-1 text-blue-600 dark:text-blue-400">
              PRINT QR CODE
            </div>
            <DialogTitle className="text-lg font-normal">Generate Printable QR Code</DialogTitle>
            <DialogDescription className="text-sm text-muted-foreground mt-1">
              Preview and print the QR code for this equipment item.
            </DialogDescription>
          </DialogHeader>
          <Separator />
          <div className="py-4">
            {selectedItem && (
              <div className="flex flex-col items-center">
                <div className="space-y-2 mb-4 text-center">
                  <div className="uppercase text-[10px] tracking-wider font-medium text-muted-foreground">
                    ITEM INFORMATION
                  </div>
                  <h3 className="text-lg font-normal">{selectedItem.name}</h3>
                  <p className="text-sm font-mono text-muted-foreground">SN: {selectedItem.serialNumber}</p>
                </div>
                
                <div className="p-6 border border-border bg-muted/30 mb-4">
                  <QRCodeGenerator 
                    itemName={selectedItem.name} 
                    serialNumber={selectedItem.serialNumber} 
                  />
                </div>
                
                <div className="text-sm text-center space-y-2 mb-4 w-full border border-border p-3">
                  <div className="uppercase text-[10px] tracking-wider font-medium text-muted-foreground">
                    IMPORTANT NOTE
                  </div>
                  {selectedItem.qrCodeStatus === "damaged" ? (
                    <p className="text-sm">This action will mark the QR code as <span className="font-medium text-blue-600 dark:text-blue-400">replaced</span> in the system.</p>
                  ) : (
                    <p className="text-sm">Print this QR code and attach it securely to the equipment for easy tracking.</p>
                  )}
                </div>
              </div>
            )}
          </div>
          <Separator />
          <DialogFooter className="pt-4">
            <Button 
              variant="outline" 
              onClick={() => setIsPrintDialogOpen(false)}
              className="rounded-none"
            >
              Cancel
            </Button>
            <Button 
              variant="blue"
              onClick={handlePrintQRCode}
              className="rounded-none"
            >
              <Printer className="h-4 w-4 mr-2" />
              {selectedItem?.qrCodeStatus === "damaged" ? "Print Replacement" : "Print QR Code"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Generate New QR Code Dialog */}
      <Dialog open={isGenerateDialogOpen} onOpenChange={setIsGenerateDialogOpen}>
        <DialogContent className="sm:max-w-[550px] rounded-none border-border shadow-none bg-card">
          <DialogHeader className="pb-2">
            <div className="uppercase text-xs tracking-wider font-medium mb-1 text-green-600 dark:text-green-400">
              CREATE NEW
            </div>
            <DialogTitle className="text-lg font-normal">Generate New QR Code</DialogTitle>
            <DialogDescription className="text-sm text-muted-foreground mt-1">
              Create a new QR code for equipment inventory tracking.
            </DialogDescription>
          </DialogHeader>
          <Separator />
          <div className="py-4">
            <div className="space-y-6">
              <div className="space-y-3">
                <div className="uppercase text-[10px] tracking-wider font-medium text-muted-foreground">
                  EQUIPMENT DETAILS
                </div>
                <div className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="new-item-name" className="text-xs uppercase tracking-wider">Item Name</Label>
                    <Input
                      id="new-item-name"
                      placeholder="Enter item name"
                      className="w-full rounded-none"
                      value={newItemInfo.name}
                      onChange={(e) => setNewItemInfo({...newItemInfo, name: e.target.value})}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="new-serial-number" className="text-xs uppercase tracking-wider">Serial Number</Label>
                    <Input
                      id="new-serial-number"
                      placeholder="Enter serial number"
                      className="w-full rounded-none font-mono"
                      value={newItemInfo.serialNumber}
                      onChange={(e) => setNewItemInfo({...newItemInfo, serialNumber: e.target.value})}
                    />
                  </div>
                </div>
              </div>
              
              {newItemInfo.name && newItemInfo.serialNumber && (
                <div className="space-y-3">
                  <div className="uppercase text-[10px] tracking-wider font-medium text-muted-foreground">
                    PREVIEW QR CODE
                  </div>
                  <div className="flex justify-center">
                    <div className="p-6 border border-border bg-muted/30">
                      <QRCodeGenerator 
                        itemName={newItemInfo.name} 
                        serialNumber={newItemInfo.serialNumber} 
                      />
                    </div>
                  </div>
                  <p className="text-xs text-center text-muted-foreground">
                    This QR code will be automatically associated with this equipment item.
                  </p>
                </div>
              )}
            </div>
          </div>
          <Separator />
          <DialogFooter className="pt-4">
            <Button 
              variant="outline" 
              onClick={() => setIsGenerateDialogOpen(false)}
              className="rounded-none"
            >
              Cancel
            </Button>
            <Button
              variant="blue"
              onClick={handleGenerateNewQRCode}
              disabled={!newItemInfo.name || !newItemInfo.serialNumber}
              className="rounded-none"
            >
              <Plus className="h-4 w-4 mr-2" />
              Generate QR Code
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PageWrapper>
  );
};

export default QRManagement;