import React, { useState, useEffect, useReducer, useCallback, useMemo } from "react";
// import { useParams } from 'react-router-dom'; // Removed import as it's not installed/used
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

// iOS Components
import {
  CleanCard,
  ElegantSectionHeader,
  StatusBadge as IOSStatusBadge,
  MinimalEmptyState,
  MinimalLoadingView
} from "@/components/ios";

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
  showNewTransfer: boolean;
  showTransferDetails: Transfer | null;
  transferToConfirm: { id: string; action: 'approve' | 'reject' } | null;
}

type TransfersAction =
  | { type: 'SET_SEARCH_TERM'; payload: string }
  | { type: 'SET_FILTER_STATUS'; payload: TransferStatusFilter }
  | { type: 'SET_ACTIVE_VIEW'; payload: TransferView }
  | { type: 'SET_SORT_CONFIG'; payload: SortField }
  | { type: 'TOGGLE_NEW_TRANSFER'; payload: boolean }
  | { type: 'SHOW_DETAILS'; payload: Transfer | null }
  | { type: 'CONFIRM_ACTION'; payload: { id: string; action: 'approve' | 'reject' } | null }
  | { type: 'RESET_FILTERS' };

const initialState: TransfersState = {
  searchTerm: "",
  filterStatus: "all",
  activeView: 'incoming',
  sortConfig: { field: 'date', order: 'desc' },
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
  id?: string; // Add this for route params like /transfers/:id
}

const Transfers: React.FC<TransfersProps> = ({ id }) => {
  const { user } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient(); // Get query client
  const [state, dispatch] = useReducer(transfersReducer, initialState);
  const { searchTerm, filterStatus, activeView, sortConfig, showNewTransfer, showTransferDetails, transferToConfirm } = state;

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
      toast({
        title: "Error",
        description: `Failed to create transfer: ${error.message}`,
        variant: "destructive"
      });
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
            user.name || currentUser || 'Unknown User'
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

  // Use the actual authenticated user instead of mock data
  const currentUser = user?.name || (user?.firstName && user?.lastName ? `${user.firstName} ${user.lastName}` : null) || 'Unknown User';

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
      updateStatusMutation.mutate({ id, status: 'rejected', notes: reason });
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

  // --- Filtering and Sorting Logic (Memoized) ---
  const filteredTransfers = useMemo(() => {
    return transfers.filter(transfer => {
      const matchesView =
        (activeView === 'incoming' && transfer.to === currentUser) ||
        (activeView === 'outgoing' && transfer.from === currentUser) ||
        (activeView === 'history' && (transfer.to === currentUser || transfer.from === currentUser));

      const matchesSearch = !searchTerm || // Return true if searchTerm is empty
        transfer.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        transfer.serialNumber.toLowerCase().includes(searchTerm.toLowerCase()) ||
        transfer.from.toLowerCase().includes(searchTerm.toLowerCase()) ||
        transfer.to.toLowerCase().includes(searchTerm.toLowerCase());

      const matchesStatus = filterStatus === "all" || transfer.status === filterStatus;

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
    toast({
      title: "Exporting Transfer",
      description: `Preparing PDF for ${transfer?.name || 'item'}...`
    });
    setTimeout(() => {
      toast({
        title: "Export Complete (Demo)",
        description: `Transfer document for ${transfer?.name || 'item'} exported.`
      });
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
      case 'incoming':
        return "Review and manage transfer requests sent to you";
      case 'outgoing':
        return "Track transfer requests you've initiated";
      case 'history':
        return "View your complete transfer history (incoming and outgoing)";
      default:
        return "Manage equipment transfer requests and assignments";
    }
  }, [activeView]);

  const getPageTitle = () => "Transfer Management";

  // --- Render Logic ---
  return (
    <div className="min-h-screen bg-app-background">
      <div className="max-w-7xl mx-auto px-6 py-8">
        {/* Header */}
        <div className="mb-8">
          <ElegantSectionHeader title="TRANSFERS" className="mb-4" />
          <div className="flex flex-col sm:flex-row sm:items-center justify-between space-y-4 sm:space-y-0">
            <div>
              <h1 className="text-3xl font-light tracking-tight text-primary-text">
                {getPageTitle()}
              </h1>
              <p className="text-secondary-text mt-1">
                {getPageDescription()}
              </p>
            </div>
            <Button
              onClick={() => dispatch({ type: 'TOGGLE_NEW_TRANSFER', payload: true })}
              className="bg-primary-text hover:bg-black/90 text-white font-medium px-6 py-3 rounded-none flex items-center gap-2"
            >
              <Plus className="h-4 w-4" />
              New Transfer
            </Button>
          </div>
        </div>

        {/* Tabs */}
        <CleanCard padding="none" className="mb-6">
          <Tabs
            value={activeView}
            onValueChange={(value) => dispatch({ type: 'SET_ACTIVE_VIEW', payload: value as TransferView })}
            className="w-full"
          >
            <div className="border-b border-ios-border">
              <TabsList className="grid grid-cols-3 w-full bg-transparent">
                {(['incoming', 'outgoing', 'history'] as TransferView[]).map((view) => (
                  <TabsTrigger
                    key={view}
                    value={view}
                    className="text-sm uppercase tracking-wide font-medium data-[state=active]:bg-transparent data-[state=active]:text-primary-text data-[state=active]:border-b-2 data-[state=active]:border-ios-accent rounded-none relative"
                  >
                    {view.charAt(0).toUpperCase() + view.slice(1)}
                    {view === 'incoming' && incomingPendingCount > 0 && (
                      <Badge className="ml-2 px-1.5 py-0.5 h-5 min-w-[1.25rem] bg-ios-destructive text-white rounded-full text-[10px] flex items-center justify-center">
                        {incomingPendingCount}
                      </Badge>
                    )}
                  </TabsTrigger>
                ))}
              </TabsList>
            </div>

            {/* Tab Content */}
            <div className="p-6">
              {/* Search and Filter Controls */}
              <div className="flex flex-col sm:flex-row gap-4 mb-6">
                {/* Search */}
                <div className="flex-1 relative">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-tertiary-text" />
                  <Input
                    placeholder={`Search ${activeView} transfers... (name, SN, user)`}
                    value={searchTerm}
                    onChange={(e) => dispatch({ type: 'SET_SEARCH_TERM', payload: e.target.value })}
                    className="pl-10 border-0 border-b border-ios-border rounded-none px-3 py-2 text-base text-primary-text placeholder:text-quaternary-text focus:border-primary-text focus:border-b-2 transition-all duration-200 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
                  />
                </div>

                {/* Status Filter */}
                <div className="sm:w-48">
                  <Select
                    value={filterStatus}
                    onValueChange={(value) => dispatch({ type: 'SET_FILTER_STATUS', payload: value as TransferStatusFilter })}
                  >
                    <SelectTrigger className="border-0 border-b border-ios-border rounded-none px-3 py-2 text-base text-primary-text focus:border-primary-text focus:border-b-2 transition-all duration-200 bg-transparent focus:ring-0 focus:ring-offset-0 h-auto">
                      <SelectValue placeholder="Filter by status" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All Statuses</SelectItem>
                      <SelectItem value="pending">Pending</SelectItem>
                      <SelectItem value="approved">Approved</SelectItem>
                      <SelectItem value="rejected">Rejected</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                {/* Reset Button */}
                <Button
                  onClick={handleResetFilters}
                  variant="outline"
                  className="text-primary-text border-ios-border hover:bg-gray-50 rounded-none px-4 py-2"
                >
                  <RefreshCw className="h-4 w-4 mr-2" />
                  Reset
                </Button>
              </div>

              {/* Transfer List Content */}
              <CleanCard>
                {/* Loading State */}
                {isLoadingTransfers && (
                  <MinimalLoadingView text="Loading transfers..." size="lg" className="py-16" />
                )}

                {/* Error State */}
                {!isLoadingTransfers && transfersError && (
                  <div className="py-16 text-center text-ios-destructive">
                    <AlertCircle className="h-8 w-8 mx-auto mb-2" />
                    <p>Error loading transfers: {transfersError.message}</p>
                    <p className="text-sm mt-1 text-secondary-text">Please try again later.</p>
                  </div>
                )}

                {/* Transfer List */}
                {!isLoadingTransfers && !transfersError && (
                  sortedTransfers.length === 0 ? (
                    <MinimalEmptyState
                      title={searchTerm || filterStatus !== "all" ? "No transfers match your search" : `No ${activeView} transfers`}
                      description={searchTerm || filterStatus !== "all" ? "Try adjusting your search criteria" : `${activeView === 'incoming' ? 'You have no pending transfer requests' : activeView === 'outgoing' ? 'You haven\'t initiated any transfers' : 'No transfer history found'}`}
                      icon={<Send className="h-12 w-12" />}
                      action={activeView !== 'incoming' ? (
                        <Button
                          onClick={() => dispatch({ type: 'TOGGLE_NEW_TRANSFER', payload: true })}
                          className="bg-ios-accent hover:bg-accent-hover text-white px-6 py-2 rounded-none"
                        >
                          Create Transfer
                        </Button>
                      ) : undefined}
                    />
                  ) : (
                    <>
                      {/* Transfer List Header */}
                      <TransferListHeader
                        sortConfig={sortConfig}
                        onSort={handleSort}
                      />
                      <ScrollArea className="h-[calc(100vh-450px)]">
                        {sortedTransfers.map((transfer) => (
                          <TransferRow
                            key={transfer.id}
                            transfer={transfer}
                            currentUser={currentUser}
                            isLoadingApprove={updateStatusMutation.isPending && updateStatusMutation.variables?.id === transfer.id && updateStatusMutation.variables?.status === 'approved'}
                            isLoadingReject={updateStatusMutation.isPending && updateStatusMutation.variables?.id === transfer.id && updateStatusMutation.variables?.status === 'rejected'}
                            onConfirmAction={(id: string, action: 'approve' | 'reject') => dispatch({ type: 'CONFIRM_ACTION', payload: { id, action } })}
                            onShowDetails={(t: Transfer) => dispatch({ type: 'SHOW_DETAILS', payload: t })}
                          />
                        ))}
                      </ScrollArea>
                    </>
                  )
                )}
              </CleanCard>
            </div>
          </Tabs>
        </CleanCard>
      </div>

      {/* Modals and Dialogs */}
      <NewTransferDialog
        isOpen={showNewTransfer}
        currentUser={currentUser}
        isPending={createTransferMutation.isPending}
        onClose={() => dispatch({ type: 'TOGGLE_NEW_TRANSFER', payload: false })}
        onSubmit={handleCreateTransfer}
      />

      {showTransferDetails && (
        <TransferDetailsModal
          transfer={showTransferDetails}
          isOpen={!!showTransferDetails}
          currentUser={currentUser}
          isUpdating={updateStatusMutation.isPending && updateStatusMutation.variables?.id === showTransferDetails.id}
          onClose={() => dispatch({ type: 'SHOW_DETAILS', payload: null })}
          onConfirmAction={(id, action) => dispatch({ type: 'CONFIRM_ACTION', payload: { id, action } })}
        />
      )}

      {transferToConfirm && (
        <TransferConfirmationDialog
          confirmation={transferToConfirm}
          isPending={updateStatusMutation.isPending && updateStatusMutation.variables?.id === transferToConfirm.id}
          transferName={transfers.find(t => t.id === transferToConfirm.id)?.name}
          onClose={() => dispatch({ type: 'CONFIRM_ACTION', payload: null })}
          onConfirm={(id: string, action: 'approve' | 'reject') => {
            if (action === 'approve') {
              handleApprove(id);
            } else {
              handleReject(id);
            }
          }}
        />
      )}
    </div>
  );
};

export default Transfers;