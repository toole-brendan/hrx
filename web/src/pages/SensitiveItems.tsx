import { useState, useEffect, useMemo } from "react";
import { format } from "date-fns";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
  CardFooter,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { useToast } from "@/hooks/use-toast";
import { Progress } from "@/components/ui/progress";
import { PageHeader } from "@/components/ui/page-header";
import { PageWrapper } from "@/components/ui/page-wrapper";
import { Separator } from "@/components/ui/separator";
import QRCodeGenerator from "@/components/common/QRCodeGenerator";
import QRDisplay from "@/components/common/QRDisplay";
import TransferRequestModal from "@/components/modals/TransferRequestModal";
import { useIsMobile } from "@/hooks/use-mobile";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { useAuth } from "@/contexts/AuthContext";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import BlockchainLedger from "@/components/blockchain/BlockchainLedger";
import { recordToBlockchain } from "@/lib/blockchain";

import {
  Search,
  Filter,
  Clock,
  ShieldAlert,
  AlertTriangle,
  ClipboardCheck,
  CheckCircle,
  XCircle,
  Radio,
  Eye,
  Key,
  Calendar,
  Clock12,
  ArrowUpRight,
  ArrowRight,
  Printer,
  History,
  BarChart3,
  Plus,
  FileText,
  CalendarClock,
  ScanLine,
  Info,
  Sword,
  ListFilter,
  RotateCcw,
  ArrowRightLeft,
  Headphones,
  Package,
  QrCode,
  ShieldCheck,
} from "lucide-react";

import {
  sensitiveItems,
  sensitiveItemCategories,
  verificationLogs,
  verificationSchedule,
  sensitiveItemsStats,
  SensitiveItem,
  VerificationLog
} from "@/lib/sensitiveItemsData";
import { cn } from "@/lib/utils";

interface SensitiveItemsProps {
  id?: string;
}

const StatusBadgeComponent = ({ status }: { status: string | undefined }) => {
  const statusKey = status || 'not-verified';
  
  // Style mapping for each status type
  const statusStyles: Record<string, { textColor: string; borderColor: string; bgColor: string; label: string }> = {
    verified: { 
      textColor: "text-green-700 dark:text-green-400",
      borderColor: "border-green-600 dark:border-green-500",
      bgColor: "bg-green-100/70 dark:bg-transparent",
      label: "VERIFIED"
    },
    pending: { 
      textColor: "text-yellow-700 dark:text-yellow-400",
      borderColor: "border-yellow-600 dark:border-yellow-500",
      bgColor: "bg-yellow-100/70 dark:bg-transparent",
      label: "PENDING"
    },
    overdue: { 
      textColor: "text-red-700 dark:text-red-400",
      borderColor: "border-red-600 dark:border-red-500",
      bgColor: "bg-red-100/70 dark:bg-transparent",
      label: "OVERDUE" 
    },
    'not-verified': { 
      textColor: "text-blue-700 dark:text-blue-400", 
      borderColor: "border-blue-600 dark:border-blue-500",
      bgColor: "bg-blue-100/70 dark:bg-transparent",
      label: "NOT VERIFIED"
    },
    active: { 
      textColor: "text-blue-700 dark:text-blue-400",
      borderColor: "border-blue-600 dark:border-blue-500",
      bgColor: "bg-blue-100/70 dark:bg-transparent",
      label: "ACTIVE"
    },
    maintenance: { 
      textColor: "text-orange-700 dark:text-orange-400",
      borderColor: "border-orange-600 dark:border-orange-500",
      bgColor: "bg-orange-100/70 dark:bg-transparent",
      label: "MAINTENANCE"
    },
    transferred: { 
      textColor: "text-purple-700 dark:text-purple-400",
      borderColor: "border-purple-600 dark:border-purple-500",
      bgColor: "bg-purple-100/70 dark:bg-transparent",
      label: "TRANSFERRED"
    }
  };

  // Default to not-verified if status doesn't exist in our mapping
  const style = statusStyles[statusKey] || statusStyles['not-verified'];
  
  return (
    <Badge className={`uppercase ${style.bgColor} ${style.textColor} border ${style.borderColor} text-[10px] tracking-[0.3em] font-medium px-2 py-0.5 rounded-none`}>
      {style.label}
    </Badge>
  );
};

// Helper for Category Cell (Item 3)
const CategoryCell = ({ category }: { category: SensitiveItem['category'] }) => {
  const categoryMap: Record<SensitiveItem['category'], { icon: React.ReactNode; colorClasses: string; name: string }> = {
    weapon: { icon: <Sword className="h-4 w-4" />, colorClasses: "text-red-600 dark:text-red-500", name: "Weapon" },
    communication: { icon: <Headphones className="h-4 w-4" />, colorClasses: "text-blue-600 dark:text-blue-400", name: "Communication" },
    optics: { icon: <Eye className="h-4 w-4" />, colorClasses: "text-green-600 dark:text-green-500", name: "Optics" },
    crypto: { icon: <Key className="h-4 w-4" />, colorClasses: "text-purple-600 dark:text-purple-400", name: "Crypto" },
    other: { icon: <Package className="h-4 w-4" />, colorClasses: "text-gray-600 dark:text-gray-400", name: "Other" },
  };

  const { icon, colorClasses, name } = categoryMap[category] || categoryMap['other']; // Default to other

  return (
    <div className="flex items-center gap-2">
      <span className={cn(colorClasses)}>{icon}</span>
      <span className="capitalize">{name}</span> {/* Display capitalized name */} 
    </div>
  );
};

const SensitiveItems: React.FC<SensitiveItemsProps> = ({ id }) => {
  const [searchTerm, setSearchTerm] = useState("");
  const [filterCategory, setFilterCategory] = useState("all");
  const [filterStatus, setFilterStatus] = useState("all");
  const [selectedItem, setSelectedItem] = useState<SensitiveItem | null>(null);
  const [detailsModalOpen, setDetailsModalOpen] = useState(false);
  const [verificationModalOpen, setVerificationModalOpen] = useState(false);
  const [showQRDialog, setShowQRDialog] = useState(false);
  const [showVerifyDialog, setShowVerifyDialog] = useState(false);
  const [assignmentTab, setAssignmentTab] = useState<'me' | 'others' | 'unassigned'>('me');
  const isMobile = useIsMobile();
  const { toast } = useToast();
  const { user } = useAuth();
  const currentUserName = user?.name ?? "";
  const currentUserFormattedName = "CPT Rodriguez, Michael"; // Define the desired display format

  useEffect(() => {
    if (id) {
      const item = sensitiveItems.find(item => item.id === id);
      if (item) {
        setSelectedItem(item);
        setDetailsModalOpen(true);
      }
    }
  }, [id]);
  
  const filteredItems = useMemo(() => {
    return sensitiveItems.filter(item => {
      const matchesSearch = 
        item.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        item.serialNumber.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesCategory = filterCategory === "all" || item.category === filterCategory;
      const matchesStatus = filterStatus === "all" || item.status === filterStatus;
      
      let matchesAssignment = false;
      const assignedTo = item.assignedTo;
      const isAssigned = !!(assignedTo && assignedTo.trim() !== "");

      if (assignmentTab === 'me') {
        matchesAssignment = isAssigned && assignedTo === currentUserName;
      } else if (assignmentTab === 'others') {
        matchesAssignment = isAssigned && assignedTo !== currentUserName;
      } else if (assignmentTab === 'unassigned') {
        matchesAssignment = !isAssigned;
      }

      return matchesSearch && matchesCategory && matchesStatus && matchesAssignment;
    });
  }, [searchTerm, filterCategory, filterStatus, assignmentTab, currentUserName]);

  const getItemVerificationLogs = (itemId: string): VerificationLog[] => {
    return verificationLogs.filter(log => log.itemId === itemId);
  };

  const handleStartVerification = () => {
    setVerificationModalOpen(true);
    toast({
      title: "Verification Mode",
      description: "Ready to scan QR codes for verification.",
    });
  };

  const handleVerifyItem = (item: SensitiveItem) => {
    // Record the verification to the simulated blockchain
    const user = currentUserFormattedName;
    
    // Record verification to blockchain (if item is blockchain-enabled)
    recordToBlockchain(
      item,
      'verification',
      { status: 'verified', location: item.location },
      user
    );
    
    toast({
      title: "Item Verified",
      description: `${item.name} (SN: ${item.serialNumber}) has been verified and recorded to the secure ledger.`,
      variant: "default",
    });
  };

  const handleViewDetails = (item: SensitiveItem) => {
    setSelectedItem(item);
    setDetailsModalOpen(true);
  };

  const clearFilters = () => {
    setSearchTerm("");
    setFilterCategory("all");
    setFilterStatus("all");
    toast({
      title: "Filters Cleared",
      description: "Showing all sensitive items.",
    });
  };

  // Renamed helper function for date part
  const formatMilitaryDateOnly = (date: Date | string | undefined): string => {
    if (!date) return 'N/A';
    // If the input is already in ddMMMyyyy format, try to parse it back, otherwise assume it's a Date object or standard string
    // Basic check - this might need refinement if date strings vary wildly
    let dateObj: Date;
    if (typeof date === 'string' && /^[0-9]{2}[A-Z]{3}[0-9]{4}$/.test(date)) {
       // Attempt to parse ddMMMyyyy - requires careful handling
       // For simplicity with mock data, we might assume it's passed correctly or rely on logs
       // Let's assume for now it might be a standard date string or Date object for parsing robustness
       try { dateObj = new Date(date); } catch { return 'Invalid Date'; }
    } else if (typeof date === 'string') {
       try { dateObj = new Date(date); } catch { return 'Invalid Date'; }
    } else {
      dateObj = date;
    }
    
    if (isNaN(dateObj.getTime())) return 'Invalid Date'; // Check if date is valid
    
    try {
      const day = format(dateObj, 'dd');
      const month = format(dateObj, 'MMM').toUpperCase();
      const year = format(dateObj, 'yyyy');
      return `${day}${month}${year}`;
    } catch (error) { // Catch potential date-fns errors
      console.error("Error formatting date:", error);
      return 'Invalid Date';
    }
  };

  // Helper to find the latest verification time from logs
  const findLatestVerificationTime = (itemId: string): string => {
    const logsForItem = verificationLogs
      .filter(log => log.itemId === itemId && log.status === 'verified') // Only consider successful verifications
      .sort((a, b) => { 
          // Combine date and time for proper sorting - assumes YYYY-MM-DD format for date
          const dateTimeA = new Date(`${a.date}T${a.time}:00`);
          const dateTimeB = new Date(`${b.date}T${b.time}:00`);
          // Handle potential invalid dates during sorting
          if (isNaN(dateTimeA.getTime()) || isNaN(dateTimeB.getTime())) return 0; 
          return dateTimeB.getTime() - dateTimeA.getTime(); // Sort descending
      });
      
    if (logsForItem.length > 0) {
      // Format time as HHMM
      return logsForItem[0].time.replace(':', ''); 
    } 
    return 'N/A'; // Return N/A if no verified log found
  };

  const actions = (
    <div className="flex flex-wrap items-center gap-2">
      <Button
        size="sm"
        variant="blue"
        onClick={() => setShowQRDialog(true)}
        className="h-9 px-3 flex items-center gap-1.5"
      >
        <QrCode className="h-4 w-4" />
        <span className="text-xs uppercase tracking-wider">Scan QR Code</span>
      </Button>

      <Button
        size="sm"
        variant="blue"
        onClick={() => setShowVerifyDialog(true)}
        className="h-9 px-3 flex items-center gap-1.5"
      >
        <ClipboardCheck className="h-4 w-4" />
        <span className="text-xs uppercase tracking-wider">Verify Items</span>
      </Button>

      <Button
        variant="blue"
        size="sm"
        className="h-9 px-3 flex items-center gap-1.5"
        onClick={() => {
          toast({
            title: "Report Generated",
            description: "Sensitive items report has been exported"
          });
        }}
      >
        <FileText className="h-4 w-4" />
        <span className="text-xs uppercase tracking-wider">Export Report</span>
      </Button>
    </div>
  );

  // Contents for details modal
  const renderDetailsModal = () => {
    if (!selectedItem) return null;
    
    const verificationHistory = getItemVerificationLogs(selectedItem.id);

    return (
      <Dialog open={detailsModalOpen} onOpenChange={setDetailsModalOpen}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="text-xl flex items-center gap-2">
              {selectedItem.name}
              <StatusBadgeComponent status={selectedItem.status} />
            </DialogTitle>
            <DialogDescription>
              Serial Number: {selectedItem.serialNumber}
            </DialogDescription>
          </DialogHeader>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 py-4">
            <div>
              <h3 className="text-sm font-medium mb-2">Item Details</h3>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Category:</span>
                  <CategoryCell category={selectedItem.category} />
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Location:</span>
                  <span>{selectedItem.location}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Assigned To:</span>
                  <span>{selectedItem.assignedTo || "Unassigned"}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Assigned Date:</span>
                  <span>{selectedItem.assignedDate || "N/A"}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Last Verified:</span>
                  <span>{selectedItem.lastVerified}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Next Verification:</span>
                  <span>{selectedItem.nextVerification}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Security Level:</span>
                  <span className="capitalize">{selectedItem.securityLevel}</span>
                </div>
                {selectedItem.notes && (
                  <div className="pt-2">
                    <span className="text-muted-foreground">Notes:</span>
                    <p className="mt-1 text-sm">{selectedItem.notes}</p>
                  </div>
                )}
              </div>
            </div>
            
            <div>
              <h3 className="text-sm font-medium mb-2">Verification History</h3>
              {verificationHistory.length > 0 ? (
                <div className="space-y-2 max-h-40 overflow-y-auto pr-2">
                  {verificationHistory.map((log, index) => (
                    <div key={index} className="border-b border-gray-100 dark:border-gray-800 pb-2 last:border-0 last:pb-0">
                      <div className="flex justify-between items-start">
                        <span className="font-medium">{log.date}</span>
                        <StatusBadgeComponent status={log.status} />
                      </div>
                      <div className="text-xs text-muted-foreground mt-1">
                        Verified by {log.verifiedBy} at {log.time}
                      </div>
                      {log.notes && <div className="text-xs mt-1">{log.notes}</div>}
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-sm text-muted-foreground">No verification history available.</div>
              )}
            </div>
          </div>
          
          {/* QR Code Section */}
          <div className="mt-4 py-4 border-t border-dashed">
            <h3 className="text-sm font-medium mb-2">Item QR Code</h3>
            <div className="flex justify-center bg-white p-4 rounded-md">
              <QRDisplay
                value={`handreceipt://sensitive-items/${selectedItem.id}`} 
                size={150} 
                includeMargin={true}
              />
            </div>
            <p className="text-xs text-center text-muted-foreground mt-2">
              Scan this code during physical verification
            </p>
          </div>
          
          {/* Add the Blockchain Ledger component here */}
          <BlockchainLedger item={selectedItem} />
          
          <DialogFooter className="flex flex-wrap gap-2 justify-end">
            {selectedItem.assignedTo === currentUserName && (
              <Button 
                variant="outline" 
                onClick={() => {
                  handleVerifyItem(selectedItem);
                  setDetailsModalOpen(false);
                }}
                className="flex items-center"
              >
                <ShieldCheck className="w-4 h-4 mr-2" />
                Verify Now
              </Button>
            )}
            <Button 
              variant="default" 
              onClick={() => setDetailsModalOpen(false)} 
              className="ml-auto"
            >
              Close
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    );
  };

  return (
    <PageWrapper withPadding={true}>
      <div className="pt-16 pb-12">
        <div className="text-xs uppercase tracking-wider mb-1 text-muted-foreground font-medium">
          SECURITY
        </div>
        
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-3xl font-light tracking-tight mb-1">Sensitive Items</h1>
            <p className="text-sm text-muted-foreground max-w-xl">
              Track, verify, and manage sensitive military equipment requiring special handling and accountability.
            </p>
          </div>
          {actions}
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-10">
        <Card className="border-border shadow-sm bg-card transition-colors">
          <CardContent className="p-4">
            <div className="flex items-center justify-between mb-2">
              <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground">
                VERIFIED TODAY
              </div>
              <div className="p-1.5 bg-green-100 dark:bg-green-900/30 rounded-md">
                <CheckCircle className="h-4 w-4 text-green-600 dark:text-green-400" />
              </div>
            </div>
            <div className="text-2xl font-light tracking-tight text-black dark:text-white">
              {sensitiveItemsStats.verifiedToday}/{sensitiveItemsStats.totalItems}
            </div>
            <p className="text-xs tracking-wide text-muted-foreground mt-0.5">
              Last full check: {sensitiveItemsStats.lastFullVerification}
            </p>
          </CardContent>
        </Card>

        <Card className="border-border shadow-sm bg-card transition-colors">
          <CardContent className="p-4">
            <div className="flex items-center justify-between mb-2">
              <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground">
                PENDING VERIFICATION
              </div>
              <div className="p-1.5 bg-yellow-100 dark:bg-yellow-900/30 rounded-md">
                <Clock className="h-4 w-4 text-yellow-600 dark:text-yellow-400" />
              </div>
            </div>
            <div className="text-2xl font-light tracking-tight text-black dark:text-white">
              {sensitiveItemsStats.pendingVerification}
            </div>
             <p className="text-xs tracking-wide text-muted-foreground mt-0.5">
              Requires attention
            </p>
          </CardContent>
        </Card>

        <Card className="border-border shadow-sm bg-card transition-colors">
          <CardContent className="p-4">
            <div className="flex items-center justify-between mb-2">
              <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground">
                NEXT SCHEDULED CHECK
              </div>
               <div className="p-1.5 bg-blue-100 dark:bg-blue-900/30 rounded-md">
                <CalendarClock className="h-4 w-4 text-blue-600 dark:text-blue-400" />
              </div>
            </div>
            <div className="text-2xl font-light tracking-tight text-black dark:text-white">
               {verificationSchedule.length > 0 ? formatMilitaryDateOnly(verificationSchedule[0].date) : 'N/A'}
            </div>
            <p className="text-xs tracking-wide text-muted-foreground mt-0.5">
              Check schedule for details
            </p>
          </CardContent>
        </Card>
      </div>

      <Card className="mb-8 border-border shadow-sm bg-card">
        <CardContent className="p-4 flex flex-col sm:flex-row items-center gap-4">
          <div className="flex-grow w-full sm:w-auto">
            <Label htmlFor="search-items" className="sr-only">Search</Label>
            <div className="relative">
               <Search className="absolute left-2.5 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
               <Input
                id="search-items"
                type="search"
                placeholder="Search by name or serial number..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-8 w-full"
              />
            </div>
          </div>
          <div className="flex items-center gap-4 w-full sm:w-auto">
             <div className="flex-1">
               <Label htmlFor="filter-category" className="sr-only">Category</Label>
               <Select value={filterCategory} onValueChange={setFilterCategory}>
                  <SelectTrigger id="filter-category" className="w-full sm:w-[180px]">
                    <SelectValue placeholder="Filter by Category" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Categories</SelectItem>
                    {sensitiveItemCategories.map(category => (
                      <SelectItem key={category.id} value={category.id}>{category.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
             </div>
             <div className="flex-1">
                <Label htmlFor="filter-status" className="sr-only">Status</Label>
                <Select value={filterStatus} onValueChange={setFilterStatus}>
                  <SelectTrigger id="filter-status" className="w-full sm:w-[180px]">
                    <SelectValue placeholder="Filter by Status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Statuses</SelectItem>
                    <SelectItem value="verified">Verified</SelectItem>
                    <SelectItem value="pending">Pending</SelectItem>
                    <SelectItem value="overdue">Overdue</SelectItem>
                    <SelectItem value="not-verified">Not Verified</SelectItem>
                  </SelectContent>
                </Select>
             </div>
          </div>
           <Button
              variant="ghost"
              size="sm"
              onClick={clearFilters}
              className="text-muted-foreground hover:text-foreground transition-colors"
              title="Clear Filters"
            >
              <RotateCcw className="h-4 w-4 mr-1" />
              Clear
            </Button>
        </CardContent>
      </Card>

      <Tabs 
        value={assignmentTab} 
        onValueChange={(value) => setAssignmentTab(value as 'me' | 'others' | 'unassigned')} 
        className="w-full mb-6"
      >
        <TabsList className="grid grid-cols-3 h-10 border rounded-none">
          <TabsTrigger value="me" className="text-xs uppercase tracking-wider rounded-none">Assigned to Me</TabsTrigger>
          <TabsTrigger value="others" className="text-xs uppercase tracking-wider rounded-none">Signed Down to Others</TabsTrigger>
          <TabsTrigger value="unassigned" className="text-xs uppercase tracking-wider rounded-none">Unassigned</TabsTrigger>
        </TabsList>
      </Tabs>

      <TooltipProvider>
        {isMobile ? (
          <div className="space-y-4">
            {filteredItems.length > 0 ? (
              filteredItems.map((item) => {
                 // Get date and time separately for the cell
                 const lastVerifiedDateStr = formatMilitaryDateOnly(item.lastVerified);
                 const lastVerifiedTimeStr = findLatestVerificationTime(item.id);

                 // Determine display name for the Assigned To column
                 const displayAssignedTo = item.assignedTo === currentUserName 
                                           ? currentUserFormattedName 
                                           : item.assignedTo || "-";

                return (
                  <Card key={item.id} className="overflow-hidden border-border shadow-sm bg-card transition-colors">
                    <CardHeader className="p-4">
                      <CardTitle className="text-base font-medium">{item.name}</CardTitle>
                      <CardDescription className="text-xs font-mono">{item.serialNumber}</CardDescription>
                    </CardHeader>
                    <CardContent className="p-4 pt-0 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
                      <div>
                        <Label className="text-xs text-muted-foreground">Category</Label>
                        <div className="mt-1"><CategoryCell category={item.category} /></div>
                      </div>
                       <div>
                        <Label className="text-xs text-muted-foreground">Status</Label>
                        <div className="mt-1"><StatusBadgeComponent status={item.status} /></div>
                      </div>
                       <div>
                        <Label className="text-xs text-muted-foreground">Assigned To</Label>
                        <div className="mt-1 truncate">{displayAssignedTo}</div>
                      </div>
                       <div>
                        <Label className="text-xs text-muted-foreground">Last Verified</Label>
                        <div className="mt-1">
                           {lastVerifiedDateStr}{lastVerifiedTimeStr !== 'N/A' ? ` ${lastVerifiedTimeStr}` : ''}
                        </div>
                      </div>
                    </CardContent>
                    <CardFooter className="p-4 pt-0 flex justify-end gap-1 bg-muted/30">
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Button variant="ghost" size="icon" className="h-8 w-8 transition-colors" onClick={() => handleViewDetails(item)}>
                              <Eye className="h-4 w-4" />
                            </Button>
                          </TooltipTrigger>
                          <TooltipContent>View Details</TooltipContent>
                        </Tooltip>
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Button variant="ghost" size="icon" className="h-8 w-8 transition-colors" onClick={() => handleVerifyItem(item)}>
                              <CheckCircle className="h-4 w-4 text-green-600" />
                            </Button>
                          </TooltipTrigger>
                          <TooltipContent>Mark Verified</TooltipContent>
                        </Tooltip>
                        <QRCodeGenerator 
                          itemName={item.name} 
                          serialNumber={item.serialNumber}
                        />
                    </CardFooter>
                  </Card>
                );
              })
            ) : (
              <Card className="border-border shadow-sm bg-card">
                 <CardContent className="p-10 text-center text-muted-foreground">
                  No sensitive items match your filters.
                </CardContent>
              </Card>
            )}
          </div>
        ) : (
          <div className="border rounded-lg overflow-hidden border-border bg-card">
            <div className="relative overflow-x-auto">
              <Table className="table-fixed w-full">
                <TableHeader className="bg-muted/50 sticky top-0 z-10">
                  <TableRow>
                    <TableHead className="py-3 px-4 w-1/4 min-w-[250px] text-black dark:text-white">Item Name</TableHead>
                    <TableHead className="py-3 px-4 w-[180px] min-w-[180px] text-black dark:text-white">Serial Number</TableHead>
                    <TableHead className="py-3 px-4 w-[180px] min-w-[180px] text-black dark:text-white">Category</TableHead>
                    <TableHead className="py-3 px-4 w-[200px] min-w-[200px] text-black dark:text-white">Status</TableHead>
                    <TableHead className="py-3 px-4 w-[200px] min-w-[200px] text-black dark:text-white">Assigned To</TableHead>
                    <TableHead className="py-3 px-4 w-[200px] min-w-[200px] text-black dark:text-white">Last Verified</TableHead>
                    <TableHead className="text-right py-3 px-4 w-[120px] text-black dark:text-white">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredItems.length > 0 ? (
                    filteredItems.map((item) => {
                      // Get date and time separately for the cell
                      const lastVerifiedDateStr = formatMilitaryDateOnly(item.lastVerified);
                      const lastVerifiedTimeStr = findLatestVerificationTime(item.id);

                      // Determine display name for the Assigned To column
                      const displayAssignedTo = item.assignedTo === currentUserName 
                                                ? currentUserFormattedName 
                                                : item.assignedTo || "-";
                      const tooltipAssignedTo = item.assignedTo === currentUserName
                                                ? currentUserFormattedName
                                                : item.assignedTo || "Unassigned";

                      return (
                        <TableRow key={item.id} className="hover:bg-muted/50 transition-colors cursor-pointer" onClick={() => handleViewDetails(item)}>
                          <TableCell className="font-medium py-3 px-4 text-black dark:text-white">
                            <Tooltip>
                              <TooltipTrigger asChild>
                                <span className="truncate block">{item.name}</span>
                              </TooltipTrigger>
                              <TooltipContent>
                                <p>{item.name}</p>
                              </TooltipContent>
                            </Tooltip>
                          </TableCell>
                          <TableCell className="py-3 px-4 font-mono text-black dark:text-white">
                            <Tooltip>
                              <TooltipTrigger asChild>
                                 <span className="truncate block text-xs tracking-wider">{item.serialNumber}</span>
                              </TooltipTrigger>
                               <TooltipContent>
                                <p>{item.serialNumber}</p>
                              </TooltipContent>
                            </Tooltip>
                          </TableCell>
                          <TableCell className="py-3 px-4">
                            <CategoryCell category={item.category} />
                          </TableCell>
                          <TableCell className="py-3 px-4">
                            <StatusBadgeComponent status={item.status} />
                          </TableCell>
                          <TableCell className="py-3 px-4 text-black dark:text-white">
                            <Tooltip>
                              <TooltipTrigger asChild>
                                <span className="truncate block">{displayAssignedTo}</span>
                              </TooltipTrigger>
                              <TooltipContent>
                                <p>{tooltipAssignedTo}</p>
                              </TooltipContent>
                            </Tooltip>
                          </TableCell>
                          <TableCell className="py-3 px-4 text-black dark:text-white">
                            {/* Display Date and Time */}
                            {lastVerifiedDateStr}{lastVerifiedTimeStr !== 'N/A' ? ` ${lastVerifiedTimeStr}` : ''}
                          </TableCell>
                          <TableCell className="text-right py-3 px-4">
                            <div className="flex items-center justify-end gap-0.5">
                               <Tooltip>
                                 <TooltipTrigger asChild>
                                   <Button variant="ghost" size="icon" className="h-8 w-8 transition-colors" onClick={(e) => { e.stopPropagation(); handleViewDetails(item); }}>
                                      <Eye className="h-4 w-4" />
                                   </Button>
                                 </TooltipTrigger>
                                 <TooltipContent>View Details</TooltipContent>
                               </Tooltip>
                               <Tooltip>
                                 <TooltipTrigger asChild>
                                   <Button variant="ghost" size="icon" className="h-8 w-8 transition-colors" onClick={(e) => { e.stopPropagation(); handleVerifyItem(item); }}>
                                      <CheckCircle className="h-4 w-4 text-green-600" />
                                   </Button>
                                  </TooltipTrigger>
                                  <TooltipContent>Mark Verified</TooltipContent>
                               </Tooltip>
                               <QRCodeGenerator 
                                  itemName={item.name} 
                                  serialNumber={item.serialNumber}
                                />
                            </div>
                          </TableCell>
                        </TableRow>
                      );
                    })
                  ) : (
                    <TableRow>
                      <TableCell colSpan={7} className="h-24 text-center text-muted-foreground">
                        No sensitive items match your filters.
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            </div>
          </div>
        )}
      </TooltipProvider>

      {renderDetailsModal()}

      {showVerifyDialog && (
            <Dialog open={showVerifyDialog} onOpenChange={setShowVerifyDialog}>
              <DialogContent className="p-6 bg-card">
                <DialogHeader>
                  <DialogTitle>Start Verification</DialogTitle>
                  <DialogDescription>Scan items or manually verify them below.</DialogDescription>
                </DialogHeader>
                 <p className="text-center py-8">Verification UI / Scanner Placeholder</p>
                <DialogFooter className="sm:justify-end gap-2">
                  <Button variant="outline" onClick={() => setShowVerifyDialog(false)} className="transition-colors">Cancel</Button>
                   <Button variant="default" onClick={() => {}} className="transition-colors">Submit Verification</Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
        )}

         {verificationModalOpen && (
             <Dialog open={verificationModalOpen} onOpenChange={setVerificationModalOpen}>
               <DialogContent className="p-6 bg-card">
                 <DialogHeader>
                   <DialogTitle>Verification Mode Active</DialogTitle>
                   <DialogDescription>Ready to scan or verify items.</DialogDescription>
                 </DialogHeader>
                  <p className="text-center py-8">Verification UI Placeholder</p>
                 <DialogFooter className="sm:justify-end gap-2">
                   <Button variant="outline" onClick={() => setVerificationModalOpen(false)} className="transition-colors">Close</Button>
                 </DialogFooter>
               </DialogContent>
             </Dialog>
         )}

    </PageWrapper>
  );
};

export default SensitiveItems;