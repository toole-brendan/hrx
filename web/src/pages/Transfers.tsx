import React, { useState, useEffect, useReducer, useCallback, useMemo } from "react";
import { Transfer } from "@/types";
import { useAuth } from "@/contexts/AuthContext";
import { recordToBlockchain, isBlockchainEnabled } from "@/lib/blockchain";
import { sensitiveItems } from "@/lib/sensitiveItemsData";
import { Input } from "@/components/ui/input";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import {
  Search,
  Plus,
  ArrowRight,
  CheckCircle,
  XCircle,
  Loader2
} from "lucide-react";
import { format, parseISO } from "date-fns";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

// Import the extracted components
import {
  TransferDetailsModal,
  NewTransferDialog
} from '@/components/transfers';
import TransferConfirmationDialog from '@/components/transfers/TransferConfirmationDialog';

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
  MinimalEmptyState,
  MinimalLoadingView
} from "@/components/ios";

// --- State Management with useReducer ---
type TransferView = 'incoming' | 'outgoing' | 'history';
type TransferStatusFilter = 'all' | 'pending' | 'approved' | 'rejected';

interface TransfersState {
  searchTerm: string;
  filterStatus: TransferStatusFilter;
  activeView: TransferView;
  showNewTransfer: boolean;
  showTransferDetails: Transfer | null;
  transferToConfirm: { id: string; action: 'approve' | 'reject' } | null;
}

type TransfersAction =
  | { type: 'SET_SEARCH_TERM'; payload: string }
  | { type: 'SET_FILTER_STATUS'; payload: TransferStatusFilter }
  | { type: 'SET_ACTIVE_VIEW'; payload: TransferView }
  | { type: 'TOGGLE_NEW_TRANSFER'; payload: boolean }
  | { type: 'SHOW_DETAILS'; payload: Transfer | null }
  | { type: 'CONFIRM_ACTION'; payload: { id: string; action: 'approve' | 'reject' } | null }
  | { type: 'RESET_FILTERS' };

const initialState: TransfersState = {
  searchTerm: "",
  filterStatus: "all",
  activeView: 'incoming',
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
      };
    default:
      return state;
  }
}

// Tab Button Component (iOS style)
interface TabButtonProps {
  title: string;
  isSelected: boolean;
  onClick: () => void;
  badge?: number;
}

const TabButton: React.FC<TabButtonProps> = ({ title, isSelected, onClick, badge }) => (
  <button
    onClick={onClick}
    className="relative pb-4 transition-all duration-200"
  >
    <div className="flex items-center space-x-2">
      <span 
        className={`text-sm font-medium uppercase tracking-wider transition-colors duration-200 ${
          isSelected ? 'text-ios-accent' : 'text-tertiary-text'
        }`}
      >
        {title}
      </span>
      {badge !== undefined && badge > 0 && (
        <span className="bg-ios-destructive text-white text-[11px] font-medium px-1.5 py-0.5 rounded-full min-w-[1.25rem] text-center">
          {badge}
        </span>
      )}
    </div>
    <div 
      className={`absolute bottom-0 left-0 right-0 h-0.5 transition-all duration-200 ${
        isSelected ? 'bg-ios-accent' : 'bg-transparent'
      }`}
    />
  </button>
);

// Elegant Transfer Card Component (iOS style)
interface ElegantTransferCardProps {
  transfer: Transfer;
  isIncoming: boolean;
  onTap: () => void;
  onQuickApprove: () => void;
  onQuickReject: () => void;
  isLoadingApprove?: boolean;
  isLoadingReject?: boolean;
}

const ElegantTransferCard: React.FC<ElegantTransferCardProps> = ({
  transfer,
  isIncoming,
  onTap,
  onQuickApprove,
  onQuickReject,
  isLoadingApprove = false,
  isLoadingReject = false
}) => {
  const [isPressed, setIsPressed] = useState(false);

  const statusColor = {
    pending: 'text-ios-warning',
    approved: 'text-ios-success',
    rejected: 'text-ios-destructive'
  }[transfer.status] || 'text-secondary-text';

  const formatDate = (dateString: string) => {
    try {
      const date = parseISO(dateString);
      return format(date, 'dd MMM HH:mm').toUpperCase();
    } catch {
      return 'UNKNOWN DATE';
    }
  };

  return (
    <div
      className={`transition-transform duration-150 ${isPressed ? 'scale-[0.98]' : 'scale-100'}`}
      onMouseDown={() => setIsPressed(true)}
      onMouseUp={() => setIsPressed(false)}
      onMouseLeave={() => setIsPressed(false)}
    >
      <CleanCard 
        className="cursor-pointer hover:shadow-md transition-shadow duration-200 overflow-hidden"
        onClick={onTap}
        padding="none"
      >
        <div className="p-6">
          <div className="space-y-5">
            {/* Property header with serif font */}
            <div>
              <h3 className="text-lg font-medium text-primary-text" style={{ fontFamily: 'ui-serif, Georgia, serif' }}>
                {transfer.name || 'Unknown Item'}
              </h3>
              <p className="text-sm text-secondary-text mt-1 font-mono">
                SN: {transfer.serialNumber || 'Unknown'}
              </p>
            </div>

            {/* Transfer participants */}
            <div className="flex items-center space-x-8">
              <div className="flex-1">
                <p className="text-xs uppercase tracking-wide text-tertiary-text mb-1">FROM</p>
                <p className="text-sm font-medium text-primary-text">{transfer.from}</p>
              </div>
              
              <ArrowRight className="h-4 w-4 text-tertiary-text flex-shrink-0" />
              
              <div className="flex-1">
                <p className="text-xs uppercase tracking-wide text-tertiary-text mb-1">TO</p>
                <p className="text-sm font-medium text-primary-text">{transfer.to}</p>
              </div>
            </div>

            {/* Status and timestamp */}
            <div className="flex items-center justify-between">
              <span className={`text-xs font-medium uppercase tracking-wider ${statusColor}`}>
                {transfer.status}
              </span>
              <span className="text-xs text-tertiary-text font-mono">
                {formatDate(transfer.date)}
              </span>
            </div>
          </div>
        </div>

        {/* Quick actions for pending incoming transfers */}
        {isIncoming && transfer.status === 'pending' && (
          <div className="border-t border-ios-border bg-gray-50/50">
            <div className="flex divide-x divide-ios-border">
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onQuickReject();
                }}
                disabled={isLoadingReject}
                className="flex-1 flex items-center justify-center space-x-2 py-3 text-ios-destructive hover:bg-gray-100 transition-colors duration-150 disabled:opacity-50"
              >
                {isLoadingReject ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <>
                    <XCircle className="h-4 w-4" />
                    <span className="text-xs font-medium uppercase tracking-wider">Reject</span>
                  </>
                )}
              </button>
              
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onQuickApprove();
                }}
                disabled={isLoadingApprove}
                className="flex-1 flex items-center justify-center space-x-2 py-3 text-ios-success hover:bg-gray-100 transition-colors duration-150 disabled:opacity-50"
              >
                {isLoadingApprove ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <>
                    <CheckCircle className="h-4 w-4" />
                    <span className="text-xs font-medium uppercase tracking-wider">Approve</span>
                  </>
                )}
              </button>
            </div>
          </div>
        )}
      </CleanCard>
    </div>
  );
};

// --- Component Definition ---
interface TransfersProps {
  id?: string;
}

const Transfers: React.FC<TransfersProps> = ({ id }) => {
  const { user } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [state, dispatch] = useReducer(transfersReducer, initialState);
  const { searchTerm, filterStatus, activeView, showNewTransfer, showTransferDetails, transferToConfirm } = state;

  // Fetch transfers using useQuery
  const {
    data: transfers = [],
    isLoading: isLoadingTransfers,
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
      dispatch({ type: 'CONFIRM_ACTION', payload: null });
      toast({
        title: `Transfer ${updatedTransfer.status === 'approved' ? 'Approved' : 'Rejected'}`,
        description: `Transfer of ${updatedTransfer.name} ${updatedTransfer.status}.`,
        variant: updatedTransfer.status === 'rejected' ? "destructive" : "default"
      });
      handleBlockchainRecord(updatedTransfer);
    },
    onError: (error, variables) => {
      toast({
        title: "Error",
        description: `Failed to ${variables.status} transfer: ${error.message}`,
        variant: "destructive"
      });
      dispatch({ type: 'CONFIRM_ACTION', payload: null });
    }
  });

  // Helper for Blockchain recording
  const handleBlockchainRecord = (transfer: Transfer) => {
    if (!user) {
      console.error("User not found for blockchain recording.");
      return;
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
        }
      } catch (error) {
        console.error("Failed to record transfer to blockchain:", error);
      }
    }
  };

  // Use the actual authenticated user
  const currentUser = user?.name || (user?.firstName && user?.lastName ? `${user.firstName} ${user.lastName}` : null) || 'Unknown User';

  // Update useEffect to use query data
  useEffect(() => {
    if (id && !isLoadingTransfers && transfers.length > 0) {
      const transfer = transfers.find(t => t.id === id);
      if (transfer && !showTransferDetails) {
        dispatch({ type: 'SHOW_DETAILS', payload: transfer });
      }
    }
  }, [id, transfers, isLoadingTransfers, showTransferDetails]);

  // --- Update Transfer Actions to use Mutations ---
  const handleApprove = (id: string) => {
    if (transferToConfirm?.id === id && transferToConfirm?.action === 'approve') {
      updateStatusMutation.mutate({ id, status: 'approved' });
    }
  };

  const handleReject = (id: string, reason: string = "Rejected by recipient") => {
    if (transferToConfirm?.id === id && transferToConfirm?.action === 'reject') {
      updateStatusMutation.mutate({ id, status: 'rejected', notes: reason });
    }
  };

  const handleCreateTransfer = (data: { itemName: string; serialNumber: string; to: string }) => {
    const newTransferData = {
      name: data.itemName,
      serialNumber: data.serialNumber,
      from: currentUser,
      to: data.to,
    };
    createTransferMutation.mutate(newTransferData as any);
  };

  // --- Filtering and Sorting Logic (Memoized) ---
  const filteredTransfers = useMemo(() => {
    return transfers.filter(transfer => {
      const matchesView =
        (activeView === 'incoming' && transfer.to === currentUser) ||
        (activeView === 'outgoing' && transfer.from === currentUser) ||
        (activeView === 'history' && (transfer.to === currentUser || transfer.from === currentUser));

      const matchesSearch = !searchTerm ||
        transfer.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        transfer.serialNumber.toLowerCase().includes(searchTerm.toLowerCase()) ||
        transfer.from.toLowerCase().includes(searchTerm.toLowerCase()) ||
        transfer.to.toLowerCase().includes(searchTerm.toLowerCase());

      const matchesStatus = filterStatus === "all" || transfer.status === filterStatus;

      return matchesView && matchesSearch && matchesStatus;
    });
  }, [transfers, activeView, currentUser, searchTerm, filterStatus]);

  // Sort transfers by date (newest first)
  const sortedTransfers = useMemo(() => {
    return [...filteredTransfers].sort((a, b) => {
      const dateA = new Date(a.date).getTime();
      const dateB = new Date(b.date).getTime();
      return dateB - dateA;
    });
  }, [filteredTransfers]);

  // --- Derived State ---
  const incomingPendingCount = useMemo(() => {
    return transfers.filter(
      transfer => transfer.to === currentUser && transfer.status === "pending"
    ).length;
  }, [transfers, currentUser]);

  // --- UI Helper Functions ---
  const getPageDescription = useCallback(() => {
    switch (activeView) {
      case 'incoming':
        return "Review and manage transfer requests sent to you";
      case 'outgoing':
        return "Track transfer requests you've initiated";
      case 'history':
        return "View your complete transfer history";
      default:
        return "Manage equipment transfer requests and assignments";
    }
  }, [activeView]);

  // --- Render Logic ---
  return (
    <div className="min-h-screen" style={{ backgroundColor: '#FAFAFA' }}>
      <div className="max-w-4xl mx-auto px-6 py-8">
        {/* Header - iOS style */}
        <div className="mb-10">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between mb-6">
            <div></div>
            <Button
              onClick={() => dispatch({ type: 'TOGGLE_NEW_TRANSFER', payload: true })}
              variant="ghost"
              size="sm"
              className="text-sm font-medium text-ios-accent hover:bg-transparent px-0"
            >
              New
            </Button>
          </div>
          
          {/* Divider */}
          <div className="border-b border-ios-divider mb-6" />
          
          {/* Title section */}
          <div className="mb-8">
            <h1 className="text-5xl font-bold text-primary-text leading-tight" style={{ fontFamily: 'ui-serif, Georgia, serif' }}>
              Transfer Management
            </h1>
          </div>
        </div>

        {/* Tab selector - iOS style */}
        <div className="mb-6">
          <div className="border-b border-ios-border">
            <div className="flex justify-between items-center">
              <TabButton
                title="incoming"
                isSelected={activeView === 'incoming'}
                onClick={() => dispatch({ type: 'SET_ACTIVE_VIEW', payload: 'incoming' })}
                badge={incomingPendingCount}
              />
              <TabButton
                title="outgoing"
                isSelected={activeView === 'outgoing'}
                onClick={() => dispatch({ type: 'SET_ACTIVE_VIEW', payload: 'outgoing' })}
              />
              <TabButton
                title="history"
                isSelected={activeView === 'history'}
                onClick={() => dispatch({ type: 'SET_ACTIVE_VIEW', payload: 'history' })}
              />
            </div>
          </div>
        </div>

        {/* Search and Filter - iOS style */}
        {sortedTransfers.length > 0 && (
          <div className="mb-6 space-y-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-tertiary-text" />
              <Input
                placeholder={`Search ${activeView} transfers...`}
                value={searchTerm}
                onChange={(e) => dispatch({ type: 'SET_SEARCH_TERM', payload: e.target.value })}
                className="pl-10 border-0 bg-white rounded-lg h-10 text-base placeholder:text-quaternary-text focus-visible:ring-1 focus-visible:ring-ios-accent shadow-sm"
              />
            </div>
          </div>
        )}

        {/* Main content */}
        <div className="space-y-3">
          {/* Loading State */}
          {isLoadingTransfers && (
            <CleanCard className="py-16">
              <MinimalLoadingView text="Loading transfers..." />
            </CleanCard>
          )}

          {/* Error State */}
          {!isLoadingTransfers && transfersError && (
            <CleanCard className="py-16 text-center">
              <p className="text-ios-destructive mb-2">Error loading transfers</p>
              <p className="text-sm text-secondary-text">{transfersError.message}</p>
            </CleanCard>
          )}

          {/* Empty State */}
          {!isLoadingTransfers && !transfersError && sortedTransfers.length === 0 && (
            <CleanCard className="py-16">
              <MinimalEmptyState
                icon={activeView === 'incoming' ? 'arrow.down.circle' : 'arrow.up.circle'}
                title={`No ${activeView} transfers`}
                description={
                  activeView === 'incoming' 
                    ? "Transfer requests from your connections will appear here."
                    : activeView === 'outgoing'
                    ? "Your outgoing transfer requests will appear here."
                    : "Your complete transfer history will appear here."
                }
                action={activeView !== 'incoming' ? (
                  <Button
                    onClick={() => dispatch({ type: 'TOGGLE_NEW_TRANSFER', payload: true })}
                    className="bg-ios-accent hover:bg-accent-hover text-white px-6 py-2 rounded-none"
                  >
                    Create Transfer
                  </Button>
                ) : undefined}
              />
            </CleanCard>
          )}

          {/* Transfer List */}
          {!isLoadingTransfers && !transfersError && sortedTransfers.map((transfer) => (
            <ElegantTransferCard
              key={transfer.id}
              transfer={transfer}
              isIncoming={activeView === 'incoming'}
              onTap={() => dispatch({ type: 'SHOW_DETAILS', payload: transfer })}
              onQuickApprove={() => {
                dispatch({ type: 'CONFIRM_ACTION', payload: { id: transfer.id, action: 'approve' } });
                handleApprove(transfer.id);
              }}
              onQuickReject={() => {
                dispatch({ type: 'CONFIRM_ACTION', payload: { id: transfer.id, action: 'reject' } });
                handleReject(transfer.id);
              }}
              isLoadingApprove={updateStatusMutation.isPending && updateStatusMutation.variables?.id === transfer.id && updateStatusMutation.variables?.status === 'approved'}
              isLoadingReject={updateStatusMutation.isPending && updateStatusMutation.variables?.id === transfer.id && updateStatusMutation.variables?.status === 'rejected'}
            />
          ))}
        </div>

        {/* Bottom padding for mobile navigation */}
        <div className="h-24"></div>
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