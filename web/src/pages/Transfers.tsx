import React, { useState, useEffect, useReducer, useCallback, useMemo } from "react";
// import { useParams } from 'react-router-dom'; // Removed import as it's not installed/used
import { user as mockUser } from "@/lib/mockData"; // Keep mockUser for now
import { Transfer } from "@/types";
import { useAuth } from "@/contexts/AuthContext";
import { recordToBlockchain, isBlockchainEnabled } from "@/lib/blockchain";
import { sensitiveItems } from "@/lib/sensitiveItemsData";
import BlockchainLedger from "@/components/blockchain/BlockchainLedger";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
  CardFooter
} from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Separator } from "@/components/ui/separator";
import StatusBadge from "@/components/common/StatusBadge"; // Ensure this path is correct
import QRScannerModal from "@/components/shared/QRScannerModal"; // Ensure this path is correct
import { useToast } from "@/hooks/use-toast";
import { PageWrapper } from "@/components/ui/page-wrapper";
import { PageHeader } from "@/components/ui/page-header";
import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Filter,
  CheckCircle,
  XCircle,
  ScanLine,
  Clock,
  FileText,
  Send,
  Search,
  Plus,
  ChevronDown,
  RefreshCw,
  Calendar,
  ArrowUpDown,
  ArrowUp, // Added for sort indicator
  ArrowDown, // Added for sort indicator
  AlignLeft,
  Fingerprint,
  Share2,
  MoreVertical,
  History,
  Inbox,
  ExternalLink,
  AlertCircle,
  CornerDownLeft,
  Award,
  Printer,
  Loader2, // For loading state
  BookOpen // For Property Book link
} from "lucide-react";
import { format, parseISO } from "date-fns";
import QRCodeGenerator from "@/components/common/QRCodeGenerator";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"; 
// Import the extracted components
import { 
  TransferListHeader, 
  TransferRow, 
  EmptyState, 
  TransferDetailsModal, 
  NewTransferDialog, 
  TransferConfirmationDialog 
} from '@/components/transfers'; 
// Import the transfer service
import { 
  fetchTransfers, 
  createTransfer, 
  updateTransferStatus 
} from '@/services/transferService';

// --- State Management with useReducer (Modified) ---

type SortField = 'date' | 'name' | 'from' | 'to';
type SortOrder = 'asc' | 'desc';
type TransferView = 'incoming' | 'outgoing' | 'history';
type TransferStatusFilter = 'all' | 'pending' | 'approved' | 'rejected';

interface SortConfig {
  field: SortField;
  order: SortOrder;
}

interface TransfersState {
  searchTerm: string;
  filterStatus: TransferStatusFilter;
  activeView: TransferView;
  sortConfig: SortConfig;
  showScanner: boolean;
  showNewTransfer: boolean;
  showTransferDetails: Transfer | null;
  transferToConfirm: { id: string; action: 'approve' | 'reject' } | null;
}

type TransfersAction =
  | { type: 'SET_SEARCH_TERM'; payload: string }
  | { type: 'SET_FILTER_STATUS'; payload: TransferStatusFilter }
  | { type: 'SET_ACTIVE_VIEW'; payload: TransferView }
  | { type: 'SET_SORT_CONFIG'; payload: SortField }
  | { type: 'TOGGLE_SCANNER'; payload: boolean }
  | { type: 'TOGGLE_NEW_TRANSFER'; payload: boolean }
  | { type: 'SHOW_DETAILS'; payload: Transfer | null }
  | { type: 'CONFIRM_ACTION'; payload: { id: string; action: 'approve' | 'reject' } | null }
  | { type: 'RESET_FILTERS' };

const initialState: TransfersState = {
  searchTerm: "",
  filterStatus: "all",
  activeView: 'incoming',
  sortConfig: { field: 'date', order: 'desc' },
  showScanner: false,
  showNewTransfer: false,
  showTransferDetails: null,
  transferToConfirm: null,
};

function transfersReducer(state: TransfersState, action: TransfersAction): TransfersState {
  switch (action.type) {
    case 'SET_SEARCH_TERM':
      return { ...state, searchTerm: action.payload };
    case 'SET_FILTER_STATUS':
      return { ...state, filterStatus: action.payload };
    case 'SET_ACTIVE_VIEW':
      return { ...state, activeView: action.payload, searchTerm: '', filterStatus: 'all' };
    case 'SET_SORT_CONFIG':
      const newOrder = state.sortConfig.field === action.payload && state.sortConfig.order === 'asc' ? 'desc' : 'asc';
      return { ...state, sortConfig: { field: action.payload, order: newOrder } };
    case 'TOGGLE_SCANNER':
      return { ...state, showScanner: action.payload };
    case 'TOGGLE_NEW_TRANSFER':
      return { ...state, showNewTransfer: action.payload };
    case 'SHOW_DETAILS':
      return { ...state, showTransferDetails: action.payload };
    case 'CONFIRM_ACTION':
      return { ...state, transferToConfirm: action.payload };
    case 'RESET_FILTERS':
      return {
        ...state,
        searchTerm: "",
        filterStatus: "all",
        sortConfig: { field: 'date', order: 'desc' },
      };
    default:
      return state;
  }
}

// --- Component Definition ---

interface TransfersProps {
  id?: string;  // Add this for route params like /transfers/:id
}

const Transfers: React.FC<TransfersProps> = ({ id }) => {
  const { user } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient(); // Get query client

  const [state, dispatch] = useReducer(transfersReducer, initialState);
  const { searchTerm, filterStatus, activeView, sortConfig, showScanner, showNewTransfer, showTransferDetails, transferToConfirm } = state;

  // Fetch transfers using useQuery
  const { 
    data: transfers = [], // Default to empty array
    isLoading: isLoadingTransfers, // Rename to avoid conflict
    error: transfersError 
  } = useQuery<Transfer[], Error>({
    queryKey: ['transfers'],
    queryFn: fetchTransfers,
  });

  // --- Mutations ---
  const createTransferMutation = useMutation({ 
    mutationFn: createTransfer, 
    onSuccess: (newTransfer) => {
      queryClient.invalidateQueries({ queryKey: ['transfers'] });
      dispatch({ type: 'TOGGLE_NEW_TRANSFER', payload: false });
      toast({ 
        title: "Transfer Created", 
        description: `Transfer request for ${newTransfer.name} sent to ${newTransfer.to}.` 
      });
    },
    onError: (error) => {
      toast({ title: "Error", description: `Failed to create transfer: ${error.message}`, variant: "destructive" });
    }
  });

  const updateStatusMutation = useMutation({ 
    mutationFn: updateTransferStatus,
    onSuccess: (updatedTransfer) => {
      queryClient.invalidateQueries({ queryKey: ['transfers'] });
      dispatch({ type: 'CONFIRM_ACTION', payload: null }); // Close confirmation dialog
      toast({ 
        title: `Transfer ${updatedTransfer.status === 'approved' ? 'Approved' : 'Rejected'}`,
        description: `Transfer of ${updatedTransfer.name} ${updatedTransfer.status}.`,
        variant: updatedTransfer.status === 'rejected' ? "destructive" : "default"
      });
      // Blockchain logic (can be moved here or called after success)
      handleBlockchainRecord(updatedTransfer); 
    },
    onError: (error, variables) => {
      toast({ 
        title: "Error", 
        description: `Failed to ${variables.status} transfer: ${error.message}`, 
        variant: "destructive" 
      });
      dispatch({ type: 'CONFIRM_ACTION', payload: null }); // Close confirmation dialog on error too
    }
  });

  // Helper for Blockchain recording
  const handleBlockchainRecord = (transfer: Transfer) => {
    if (!user) {
      console.error("User not found for blockchain recording.");
      return; // Cannot record without user info
    }
    const sensitiveItem = sensitiveItems.find(item => item.serialNumber === transfer.serialNumber);
    if (sensitiveItem && transfer.status === 'approved') { 
      try {
        if (isBlockchainEnabled(sensitiveItem)) {
          const blockchainRecord = recordToBlockchain(
            sensitiveItem,
            'transfer',
            {
              from: transfer.from,
              to: transfer.to,
              transferId: transfer.id,
              date: new Date().toISOString()
            },
            user.name
          );
          console.log(`Blockchain record created: ${blockchainRecord.txId}`);
          // Optional: Add blockchain TX to toast?
        }
      } catch (error) {
        console.error("Failed to record transfer to blockchain:", error);
        // Don't block UI, maybe log error to monitoring service
      }
    }
  };

  // Use the mock user directly for the demo
  const currentUser = mockUser.name; // "CPT Rodriguez, Michael"

  // Update useEffect to use query data
  useEffect(() => {
    if (id && !isLoadingTransfers && transfers.length > 0) { // Check query loading state and data
      const transfer = transfers.find(t => t.id === id);
      if (transfer && !showTransferDetails) { // Avoid dispatching if already showing
        dispatch({ type: 'SHOW_DETAILS', payload: transfer });
      }
    }
  }, [id, transfers, isLoadingTransfers, showTransferDetails]);

  // --- Update Transfer Actions to use Mutations ---
  const handleApprove = (id: string) => {
    // No longer need START_LOADING/STOP_LOADING dispatch
    // Dispatch action only shows confirmation dialog
    if (transferToConfirm?.id === id && transferToConfirm?.action === 'approve') {
        updateStatusMutation.mutate({ id, status: 'approved' });
        // Logic moved to onSuccess/handleBlockchainRecord
    }
  };

  const handleReject = (id: string, reason: string = "Rejected by recipient") => {
    // No longer need START_LOADING/STOP_LOADING dispatch
    if (transferToConfirm?.id === id && transferToConfirm?.action === 'reject') {
        updateStatusMutation.mutate({ id, status: 'rejected', reason });
        // Logic moved to onSuccess
    }
  };

  const handleCreateTransfer = (data: { itemName: string; serialNumber: string; to: string }) => {
    // No longer need START_LOADING/STOP_LOADING dispatch
    const newTransferData = {
      name: data.itemName,
      serialNumber: data.serialNumber,
      from: currentUser, // Assuming currentUser is correct
      to: data.to,
      // id, date, status will be set by backend/DB
    };
    createTransferMutation.mutate(newTransferData as any); // Assert type or adjust Omit
    // Logic moved to onSuccess
  };

  // Update QR Scan handler (no direct mutation needed here, just opens modals/forms)
  const handleScanComplete = (result: string) => {
    try {
      const [serialNumber, name] = result.split('|');
      if (!serialNumber) throw new Error("Invalid QR Code format");

      const existingTransfer = transfers.find(item => item.serialNumber === serialNumber);

      if (existingTransfer) {
        dispatch({ type: 'SHOW_DETAILS', payload: existingTransfer });
        toast({ title: "Transfer Found", description: `Showing details for ${existingTransfer.name}` });
      } else {
        // Pre-fill new transfer form? (Optional enhancement)
        dispatch({ type: 'TOGGLE_NEW_TRANSFER', payload: true });
        toast({ title: "New Transfer Initiated", description: `Ready to create transfer for SN: ${serialNumber}` });
      }
    } catch (error) {
      toast({ title: "QR Scan Error", description: error instanceof Error ? error.message : "Unknown error", variant: "destructive" });
    } finally {
      dispatch({ type: 'TOGGLE_SCANNER', payload: false });
    }
  };

  // --- Filtering and Sorting Logic (Memoized) ---
  const filteredTransfers = useMemo(() => {
    return transfers.filter(transfer => {
      const matchesView =
        (activeView === 'incoming' && transfer.to === currentUser) ||
        (activeView === 'outgoing' && transfer.from === currentUser) ||
        (activeView === 'history' && (transfer.to === currentUser || transfer.from === currentUser));

      const matchesSearch =
        !searchTerm || // Return true if searchTerm is empty
        transfer.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        transfer.serialNumber.toLowerCase().includes(searchTerm.toLowerCase()) ||
        transfer.from.toLowerCase().includes(searchTerm.toLowerCase()) ||
        transfer.to.toLowerCase().includes(searchTerm.toLowerCase());

      const matchesStatus =
        filterStatus === "all" ||
        transfer.status === filterStatus;

      return matchesView && matchesSearch && matchesStatus;
    });
  }, [transfers, activeView, currentUser, searchTerm, filterStatus]);

  const sortedTransfers = useMemo(() => {
    return [...filteredTransfers].sort((a, b) => {
      let comparison = 0;
      const fieldA = a[sortConfig.field];
      const fieldB = b[sortConfig.field];

      if (sortConfig.field === 'date') {
        // Compare ISO date strings directly
        comparison = (fieldA && fieldB) ? fieldA.localeCompare(fieldB) : 0;
      } else if (typeof fieldA === 'string' && typeof fieldB === 'string') {
        comparison = fieldA.localeCompare(fieldB);
      }
      // Add more specific comparisons if needed (e.g., numbers)

      return sortConfig.order === 'asc' ? comparison : -comparison;
    });
  }, [filteredTransfers, sortConfig]);

  // --- Derived State ---
  const incomingPendingCount = useMemo(() => {
    return transfers.filter(
      transfer => transfer.to === currentUser && transfer.status === "pending"
    ).length;
  }, [transfers, currentUser]);

  // --- Event Handlers ---
  const handleSort = (field: SortField) => {
    dispatch({ type: 'SET_SORT_CONFIG', payload: field });
  };

  const handleResetFilters = () => {
    dispatch({ type: 'RESET_FILTERS' });
  };

  const handleExportTransfer = (id: string) => {
    const transfer = transfers.find(t => t.id === id);
    toast({ title: "Exporting Transfer", description: `Preparing PDF for ${transfer?.name || 'item'}...` });
    setTimeout(() => {
      toast({ title: "Export Complete (Demo)", description: `Transfer document for ${transfer?.name || 'item'} exported.` });
    }, 1500);
  };

  // --- Initial Notification Effect ---
  useEffect(() => {
    if (incomingPendingCount > 0) {
      const timer = setTimeout(() => {
        toast({
          title: `${incomingPendingCount} Pending Incoming Transfer${incomingPendingCount > 1 ? 's' : ''}`,
          description: `You have ${incomingPendingCount} transfer request${incomingPendingCount > 1 ? 's' : ''} waiting for review.`,
          variant: "default",
        });
      }, 1000);
      return () => clearTimeout(timer);
    }
  }, [incomingPendingCount, toast]); // Dependency on toast ensures it's stable

  // --- UI Helper Functions ---
  const getPageDescription = useCallback(() => {
    switch (activeView) {
      case 'incoming': return "Review and manage transfer requests sent to you";
      case 'outgoing': return "Track transfer requests you've initiated";
      case 'history': return "View your complete transfer history (incoming and outgoing)";
      default: return "Manage equipment transfer requests and assignments";
    }
  }, [activeView]);

  const getPageTitle = () => "Transfers"; // Title is constant

  // --- Render Logic ---
  return (
    <PageWrapper withPadding={true}>
      <div className="pt-16 pb-10">
        {/* Page Header */}
        <div className="text-xs uppercase tracking-wider font-medium mb-1 text-muted-foreground">
          EQUIPMENT
        </div>
        <div className="flex flex-col sm:flex-row sm:items-center justify-between space-y-4 sm:space-y-0">
          <div>
            <h1 className="text-3xl font-light tracking-tight mb-1">{getPageTitle()}</h1>
            <p className="text-sm text-muted-foreground max-w-xl">
              {getPageDescription()}
            </p>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <Button
              size="sm"
              variant="blue"
              onClick={() => dispatch({ type: 'TOGGLE_NEW_TRANSFER', payload: true })}
              className="h-9 px-3 flex items-center gap-1.5"
            >
              <Plus className="h-4 w-4" />
              <span className="text-xs uppercase tracking-wider">New Transfer</span>
            </Button>
            <Button
              size="sm"
              variant="blue"
              onClick={() => dispatch({ type: 'TOGGLE_SCANNER', payload: true })}
              className="h-9 px-3 flex items-center gap-1.5"
            >
              <ScanLine className="h-4 w-4" />
              <span className="text-xs uppercase tracking-wider">Scan QR</span>
            </Button>
            {/* QR Code Generator might be less relevant here than in QRManagement */}
            {/* <QRCodeGenerator ... /> */}
          </div>
        </div>
      </div>

      {/* Tabs - Styling updated to match guide */}
      <Tabs
        value={activeView}
        onValueChange={(value) => dispatch({ type: 'SET_ACTIVE_VIEW', payload: value as TransferView })}
        className="w-full mb-6"
      >
        <TabsList className="grid grid-cols-3 h-10 border rounded-none">
          {(['incoming', 'outgoing', 'history'] as TransferView[]).map((view) => (
            <TabsTrigger
              key={view}
              value={view}
              className="text-xs uppercase tracking-wider rounded-none"
            >
              {view.charAt(0).toUpperCase() + view.slice(1)}
              {view === 'incoming' && incomingPendingCount > 0 && (
                <Badge
                  className="ml-2 px-1.5 py-0.5 h-5 min-w-[1.25rem] bg-destructive text-destructive-foreground rounded-full text-[10px] flex items-center justify-center"
                >
                  {incomingPendingCount}
                </Badge>
              )}
            </TabsTrigger>
          ))}
        </TabsList>
      </Tabs>

      {/* Filter Bar Card - Styling updated */}
      <Card className="mb-6 border-border shadow-none bg-card rounded-none">
        <CardContent className="p-4 flex flex-col md:flex-row items-center gap-3">
          <div className="flex-grow w-full md:w-auto">
            <div className="relative">
              <Search className="absolute left-2.5 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder={`Search ${activeView} transfers... (name, SN, user)`}
                value={searchTerm}
                onChange={(e) => dispatch({ type: 'SET_SEARCH_TERM', payload: e.target.value })}
                className="pl-8 w-full rounded-none h-9"
              />
            </div>
          </div>
          <div className="w-full md:w-[180px]">
            <Select
              value={filterStatus}
              onValueChange={(value) => dispatch({ type: 'SET_FILTER_STATUS', payload: value as TransferStatusFilter })}
            >
              <SelectTrigger className="w-full rounded-none h-9 text-xs">
                <SelectValue placeholder="Filter by status" />
              </SelectTrigger>
              <SelectContent className="rounded-none">
                <SelectItem value="all">All Statuses</SelectItem>
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="approved">Approved</SelectItem>
                <SelectItem value="rejected">Rejected</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <Button
            onClick={handleResetFilters}
            variant="ghost"
            size="sm"
            className="text-muted-foreground h-9 px-3 rounded-none hover:bg-muted"
          >
            <RefreshCw className="h-4 w-4 mr-1" />
            <span className="text-xs uppercase tracking-wider">Reset</span>
          </Button>
        </CardContent>
      </Card>

      {/* Main Content Card - Transfer List */}
      <Card className="overflow-hidden border-border shadow-none bg-card rounded-none">
        <CardContent className="p-0">
          {/* Use Loading/Error states from useQuery */}
          {isLoadingTransfers && (
            <div className="py-16 text-center flex items-center justify-center text-muted-foreground">
              <Loader2 className="h-5 w-5 mr-2 animate-spin" />
              Loading transfers...
            </div>
          )}
          {!isLoadingTransfers && transfersError && (
            <div className="py-16 text-center text-destructive">
              <AlertCircle className="h-8 w-8 mx-auto mb-2" />
              <p>Error loading transfers: {transfersError.message}</p>
              <p className="text-sm mt-1">Please try again later.</p>
            </div>
          )}
          
          {!isLoadingTransfers && !transfersError && (
            sortedTransfers.length === 0 ? (
              // Use imported EmptyState component
              <EmptyState 
                activeView={activeView}
                searchTerm={searchTerm}
                filterStatus={filterStatus}
                onInitiateTransfer={() => dispatch({ type: 'TOGGLE_NEW_TRANSFER', payload: true })}
              />
            ) : (
              <>
                {/* Use imported TransferListHeader component */}
                <TransferListHeader 
                  sortConfig={sortConfig} 
                  onSort={handleSort} 
                />
                <ScrollArea className="h-[calc(100vh-450px)]"> {/* Adjust height as needed */}
                  {sortedTransfers.map((transfer) => (
                    // Use imported TransferRow component
                    <TransferRow 
                      key={transfer.id} 
                      transfer={transfer} 
                      currentUser={currentUser}
                      activeView={activeView}
                      isLoadingApprove={updateStatusMutation.isPending && updateStatusMutation.variables?.id === transfer.id && updateStatusMutation.variables?.status === 'approved'}
                      isLoadingReject={updateStatusMutation.isPending && updateStatusMutation.variables?.id === transfer.id && updateStatusMutation.variables?.status === 'rejected'}
                      onConfirmAction={(id, action) => dispatch({ type: 'CONFIRM_ACTION', payload: { id, action } })}
                      onShowDetails={(t) => dispatch({ type: 'SHOW_DETAILS', payload: t })}
                    />
                  ))}
                </ScrollArea>
              </>
            )
          )}
        </CardContent>
      </Card>

      {/* --- Modals and Dialogs --- */}

      {/* QR Scanner Modal */}
      {showScanner && (
        <QRScannerModal
          isOpen={showScanner}
          onClose={() => dispatch({ type: 'TOGGLE_SCANNER', payload: false })}
          onScan={handleScanComplete}
        />
      )}

      {/* Using extracted components */}
      <NewTransferDialog
        isOpen={showNewTransfer}
        currentUser={currentUser}
        isPending={createTransferMutation.isPending}
        onClose={() => dispatch({ type: 'TOGGLE_NEW_TRANSFER', payload: false })}
        onSubmit={handleCreateTransfer}
      />

      <TransferDetailsModal
        transfer={showTransferDetails}
        isOpen={!!showTransferDetails}
        currentUser={currentUser}
        isUpdating={updateStatusMutation.isPending && updateStatusMutation.variables?.id === showTransferDetails?.id}
        onClose={() => dispatch({ type: 'SHOW_DETAILS', payload: null })}
        onConfirmAction={(id, action) => dispatch({ type: 'CONFIRM_ACTION', payload: { id, action } })}
      />

      <TransferConfirmationDialog
        confirmation={transferToConfirm}
        isPending={updateStatusMutation.isPending && updateStatusMutation.variables?.id === transferToConfirm?.id}
        transferName={transfers.find(t => t.id === transferToConfirm?.id)?.name}
        onClose={() => dispatch({ type: 'CONFIRM_ACTION', payload: null })}
        onConfirm={(id, action) => {
          if (action === 'approve') {
            handleApprove(id);
          } else {
            handleReject(id);
          }
        }}
      />
    </PageWrapper>
  );
};

export default Transfers;