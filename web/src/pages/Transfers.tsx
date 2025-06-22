import React, { useState, useEffect, useReducer, useCallback, useMemo } from "react";
import { Transfer } from "@/types";
import { useAuth } from "@/contexts/AuthContext";
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
  Loader2,
  Clock8,
  Filter,
  AlertTriangle,
  ArrowDownCircle,
  ArrowUpCircle,
  History,
  Package,
  Users,
  ArrowLeftRight,
  Activity
} from "lucide-react";
import { format, parseISO } from "date-fns";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { cn } from "@/lib/utils";

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

// Enhanced Tab Button Component with better styling
interface TabButtonProps {
  title: string;
  icon: React.ReactNode;
  isSelected: boolean;
  onClick: () => void;
  badge?: number;
  description?: string;
}

const TabButton: React.FC<TabButtonProps> = ({ title, icon, isSelected, onClick, badge, description }) => (
  <button
    onClick={onClick}
    className={cn(
      "relative p-4 transition-all duration-300 rounded-xl group",
      isSelected 
        ? "bg-white shadow-lg border-2 border-ios-accent/20 scale-[1.02]" 
        : "bg-ios-tertiary-background/30 hover:bg-ios-tertiary-background/50 border-2 border-transparent hover:border-ios-border"
    )}
  >
    <div className="flex flex-col items-center gap-3">
      <div className={cn(
        "p-3 rounded-full transition-all duration-300",
        isSelected 
          ? "bg-ios-accent text-white shadow-md" 
          : "bg-ios-secondary-background text-ios-secondary-text group-hover:bg-white group-hover:shadow-sm"
      )}>
        {icon}
      </div>
      
      <div className="text-center">
        <div className="flex items-center justify-center gap-2">
          <span 
            className={cn(
              "text-sm font-bold uppercase tracking-wider transition-colors duration-300",
              isSelected ? "text-ios-primary-text" : "text-ios-secondary-text",
              "font-['Courier_New',_monospace]"
            )}
          >
            {title}
          </span>
          {badge !== undefined && badge > 0 && (
            <span className={cn(
              "text-xs font-bold px-2 py-0.5 rounded-full transition-all duration-300",
              isSelected 
                ? "bg-ios-accent text-white" 
                : "bg-ios-accent/10 text-ios-accent",
              "font-['Courier_New',_monospace]"
            )}>
              {badge}
            </span>
          )}
        </div>
        
        {description && (
          <p className={cn(
            "text-xs mt-1 transition-colors duration-300",
            isSelected ? "text-ios-secondary-text" : "text-ios-tertiary-text"
          )}>
            {description}
          </p>
        )}
      </div>
    </div>
    
    {/* Active indicator */}
    <div className={cn(
      "absolute bottom-0 left-1/2 transform -translate-x-1/2 h-1 rounded-full transition-all duration-300",
      isSelected 
        ? "w-12 bg-ios-accent" 
        : "w-0 bg-transparent"
    )} />
  </button>
);

// Enhanced Transfer Card Component with modern design
interface TransferCardProps {
  transfer: Transfer;
  isIncoming: boolean;
  onTap: () => void;
  onQuickApprove: () => void;
  onQuickReject: () => void;
  isLoadingApprove?: boolean;
  isLoadingReject?: boolean;
}

const TransferCard: React.FC<TransferCardProps> = ({
  transfer,
  isIncoming,
  onTap,
  onQuickApprove,
  onQuickReject,
  isLoadingApprove = false,
  isLoadingReject = false
}) => {
  const [isPressed, setIsPressed] = useState(false);

  const statusStyles = {
    pending: {
      bg: 'bg-orange-500/10',
      text: 'text-orange-500',
      border: 'border-orange-500/20'
    },
    approved: {
      bg: 'bg-green-500/10',
      text: 'text-green-500',
      border: 'border-green-500/20'
    },
    rejected: {
      bg: 'bg-red-500/10',
      text: 'text-red-500',
      border: 'border-red-500/20'
    }
  }[transfer.status] || {
    bg: 'bg-ios-tertiary-background',
    text: 'text-ios-secondary-text',
    border: 'border-ios-border'
  };

  const formatDate = (dateString: string) => {
    try {
      const date = parseISO(dateString);
      return format(date, 'dd MMM yyyy').toUpperCase();
    } catch {
      return 'UNKNOWN DATE';
    }
  };

  return (
    <div
      className={cn(
        "relative transition-all duration-300 group",
        isPressed ? "scale-[0.98]" : "scale-100"
      )}
      onMouseDown={() => setIsPressed(true)}
      onMouseUp={() => setIsPressed(false)}
      onMouseLeave={() => setIsPressed(false)}
    >
      {/* Glow effect on hover */}
      <div className={cn(
        "absolute -inset-1 rounded-xl opacity-0 group-hover:opacity-20 blur-md transition-opacity duration-300",
        transfer.status === 'pending' && "bg-gradient-to-r from-orange-500 to-amber-500",
        transfer.status === 'approved' && "bg-gradient-to-r from-emerald-500 to-green-500",
        transfer.status === 'rejected' && "bg-gradient-to-r from-red-500 to-pink-500"
      )} />
      
      <CleanCard 
        className={cn(
          "relative cursor-pointer border transition-all duration-300 overflow-hidden",
          "bg-gradient-to-br from-white to-ios-secondary-background/50 shadow-lg hover:shadow-xl hover:scale-[1.01] transform-gpu",
          transfer.status === 'pending' && "border-orange-500/30 hover:border-orange-500/50",
          transfer.status === 'approved' && "border-emerald-500/30 hover:border-emerald-500/50",
          transfer.status === 'rejected' && "border-red-500/30 hover:border-red-500/50",
          isIncoming && transfer.status === 'pending' && "animate-pulse-subtle"
        )}
        onClick={onTap}
        padding="none"
      >
        <div className="p-6">
          <div className="space-y-4">
            {/* Header with item details */}
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <h3 className="text-lg font-semibold text-ios-primary-text font-['Courier_New',_monospace] uppercase tracking-wider">
                  {transfer.name || 'Unknown Item'}
                </h3>
                <p className="text-sm text-ios-secondary-text mt-1 font-['Courier_New',_monospace]">
                  SN: {transfer.serialNumber || 'N/A'}
                </p>
              </div>
              <div className={cn(
                "px-3 py-1 rounded-lg text-xs font-semibold uppercase tracking-wider",
                statusStyles.bg,
                statusStyles.text,
                "font-['Courier_New',_monospace]"
              )}>
                {transfer.status}
              </div>
            </div>

            {/* Enhanced Transfer flow visualization */}
            <div className={cn(
              "relative rounded-xl p-4 overflow-hidden",
              transfer.status === 'pending' && "bg-gradient-to-r from-orange-500/10 to-amber-500/10",
              transfer.status === 'approved' && "bg-gradient-to-r from-emerald-500/10 to-green-500/10",
              transfer.status === 'rejected' && "bg-gradient-to-r from-red-500/10 to-pink-500/10"
            )}>
              <div className="relative z-10 flex items-center justify-between">
                <div className="flex-1">
                  <p className="text-xs font-medium text-ios-tertiary-text uppercase tracking-wider mb-1 font-['Courier_New',_monospace]">
                    FROM
                  </p>
                  <p className="text-sm font-semibold text-ios-primary-text">
                    {transfer.from}
                  </p>
                </div>
                
                <div className="px-4 relative">
                  <div className="absolute inset-0 flex items-center">
                    <div className={cn(
                      "h-0.5 w-full",
                      transfer.status === 'pending' && "bg-gradient-to-r from-orange-500/30 to-amber-500/30",
                      transfer.status === 'approved' && "bg-gradient-to-r from-emerald-500/30 to-green-500/30",
                      transfer.status === 'rejected' && "bg-gradient-to-r from-red-500/30 to-pink-500/30"
                    )} />
                  </div>
                  <div className={cn(
                    "relative z-10 p-2 rounded-full bg-white shadow-md",
                    transfer.status === 'pending' && "text-orange-500",
                    transfer.status === 'approved' && "text-emerald-500",
                    transfer.status === 'rejected' && "text-red-500"
                  )}>
                    <ArrowRight className="h-5 w-5" />
                  </div>
                </div>
                
                <div className="flex-1 text-right">
                  <p className="text-xs font-medium text-ios-tertiary-text uppercase tracking-wider mb-1 font-['Courier_New',_monospace]">
                    TO
                  </p>
                  <p className="text-sm font-semibold text-ios-primary-text">
                    {transfer.to}
                  </p>
                </div>
              </div>
            </div>

            {/* Date and additional info */}
            <div className="flex items-center justify-between pt-2">
              <div className="flex items-center gap-2 text-xs text-ios-tertiary-text">
                <Clock8 className="h-3 w-3" />
                <span className="font-['Courier_New',_monospace]">{formatDate(transfer.date)}</span>
              </div>
              <ArrowRight className="h-4 w-4 text-ios-tertiary-text opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
            </div>
          </div>
        </div>

        {/* Quick actions for pending incoming transfers */}
        {isIncoming && transfer.status === 'pending' && (
          <div className="border-t border-ios-border bg-gradient-to-r from-ios-tertiary-background/50 to-ios-tertiary-background/30">
            <div className="flex divide-x divide-ios-border">
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onQuickReject();
                }}
                disabled={isLoadingReject}
                className={cn(
                  "flex-1 flex items-center justify-center gap-2 py-4",
                  "text-ios-destructive hover:bg-ios-destructive/10",
                  "transition-all duration-200 disabled:opacity-50",
                  "font-['Courier_New',_monospace] text-xs font-semibold uppercase tracking-wider"
                )}
              >
                {isLoadingReject ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <>
                    <XCircle className="h-4 w-4" />
                    <span>Reject</span>
                  </>
                )}
              </button>
              
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onQuickApprove();
                }}
                disabled={isLoadingApprove}
                className={cn(
                  "flex-1 flex items-center justify-center gap-2 py-4",
                  "text-ios-success hover:bg-ios-success/10",
                  "transition-all duration-200 disabled:opacity-50",
                  "font-['Courier_New',_monospace] text-xs font-semibold uppercase tracking-wider"
                )}
              >
                {isLoadingApprove ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <>
                    <CheckCircle className="h-4 w-4" />
                    <span>Approve</span>
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
  
  // Get different transfer categories for stats
  const incomingTransfers = useMemo(() => 
    transfers.filter(t => t.to === currentUser), [transfers, currentUser]);
  const outgoingTransfers = useMemo(() => 
    transfers.filter(t => t.from === currentUser), [transfers, currentUser]);
  const historyTransfers = useMemo(() => 
    transfers.filter(t => t.status !== 'pending'), [transfers]);

  // --- Derived State ---
  const incomingPendingCount = useMemo(() => {
    return transfers.filter(
      transfer => transfer.to === currentUser && transfer.status === "pending"
    ).length;
  }, [transfers, currentUser]);
  
  const outgoingPendingCount = useMemo(() => {
    return transfers.filter(
      transfer => transfer.from === currentUser && transfer.status === "pending"
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
    <div className="min-h-screen bg-gradient-to-br from-ios-background via-ios-tertiary-background/30 to-ios-background relative overflow-hidden">
      {/* Decorative gradient orbs */}
      <div className="absolute top-0 left-0 w-96 h-96 bg-gradient-to-br from-blue-500/10 to-indigo-500/10 rounded-full blur-3xl" />
      <div className="absolute bottom-0 right-0 w-96 h-96 bg-gradient-to-br from-purple-500/10 to-pink-500/10 rounded-full blur-3xl" />
      
      <div className="max-w-7xl mx-auto px-6 py-8 space-y-8 relative z-10">
        {/* Enhanced Header section */}
        <div className="space-y-8">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-3 bg-gradient-to-br from-ios-accent to-ios-accent/80 rounded-xl shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-110 transform-gpu">
                <ArrowLeftRight className="h-6 w-6 text-white" />
              </div>
              <div>
                <h1 className="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700">
                  Transfers
                </h1>
                <p className="text-sm font-medium text-ios-secondary-text mt-1">
                  {getPageDescription()}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Button
                onClick={() => dispatch({ type: 'TOGGLE_NEW_TRANSFER', payload: true })}
                variant="ghost"
                size="sm"
                className="text-sm font-medium text-ios-accent border border-ios-accent hover:bg-blue-500 hover:border-blue-500 hover:text-white px-4 py-2 uppercase transition-all duration-200 rounded-md hover:scale-105 [&:hover_svg]:text-white"
              >
                <Plus className="h-4 w-4 mr-1.5" />
                New Transfer
              </Button>
            </div>
          </div>
        </div>

        {/* Transfer Stats */}
        <TransferStats transfers={transfers || []} />
        
        {/* Tab selector with Property Book styling */}
        <div className="space-y-3">
          <div className="w-full overflow-hidden bg-gradient-to-r from-white to-gray-50 rounded-lg p-1 shadow-md border border-gray-200/50">
            <div className="overflow-x-auto">
              <div className="flex gap-1 w-full">
                {[
                { id: 'incoming' as TransferView, label: 'INCOMING', icon: <ArrowDownCircle className="h-5 w-5" />, count: incomingPendingCount },
                { id: 'outgoing' as TransferView, label: 'OUTGOING', icon: <ArrowUpCircle className="h-5 w-5" />, count: outgoingPendingCount },
                { id: 'history' as TransferView, label: 'HISTORY', icon: <History className="h-5 w-5" />, count: historyTransfers.length }
              ].map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => dispatch({ type: 'SET_ACTIVE_VIEW', payload: tab.id })}
                  className={cn(
                    "flex-1 px-5 py-2.5 text-xs font-bold rounded-lg whitespace-nowrap transition-all duration-300 uppercase tracking-wider font-['Courier_New',_monospace] flex items-center justify-center gap-2 relative",
                    activeView === tab.id
                      ? "bg-blue-500 text-white"
                      : "bg-transparent text-gray-600 hover:bg-gray-100 hover:text-gray-900"
                  )}
                >
                  <span className="relative z-10 flex items-center gap-2">
                    {tab.icon}
                    {tab.label}
                    {tab.count > 0 && (
                      <span className={cn(
                        "ml-1 px-2 py-0.5 rounded-full text-xs font-bold min-w-[1.5rem] inline-flex items-center justify-center",
                        activeView === tab.id
                          ? "bg-white/20 text-white"
                          : "bg-gray-300 text-gray-700"
                      )}>
                        {tab.count}
                      </span>
                    )}
                  </span>
                </button>
              ))}
              </div>
            </div>
          </div>
        </div>

        {/* Enhanced Search and Filter Section */}
        {sortedTransfers.length > 0 && (
          <div>
            <CleanCard className="p-4 bg-gradient-to-br from-white to-ios-secondary-background/50 shadow-lg hover:shadow-xl transition-all duration-300">
              <div className="space-y-4">
                <div className="relative">
                  <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 h-4 w-4 text-ios-tertiary-text" />
                  <Input
                    placeholder={`Search ${activeView.toLowerCase()} transfers...`}
                    value={searchTerm}
                    onChange={(e) => dispatch({ type: 'SET_SEARCH_TERM', payload: e.target.value })}
                    className="pl-12 pr-4 border-ios-border bg-ios-tertiary-background/50 rounded-lg h-12 text-base placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-ios-accent transition-all duration-200"
                  />
                </div>
                
                {/* Filter chips */}
                <div className="flex items-center gap-2 flex-wrap">
                  <div className="flex items-center gap-2 text-xs text-ios-secondary-text">
                    <Filter className="h-3 w-3" />
                    <span className="font-['Courier_New',_monospace] uppercase tracking-wider">Filter:</span>
                  </div>
                  {['all', 'pending', 'approved', 'rejected'].map((status) => (
                    <button
                      key={status}
                      onClick={() => dispatch({ type: 'SET_FILTER_STATUS', payload: status as TransferStatusFilter })}
                      className={cn(
                        "px-3 py-1.5 rounded-lg text-xs font-semibold uppercase tracking-wider transition-all duration-200",
                        "font-['Courier_New',_monospace]",
                        filterStatus === status
                          ? "bg-ios-accent text-white shadow-sm"
                          : "bg-ios-tertiary-background text-ios-secondary-text hover:bg-ios-secondary-background"
                      )}
                    >
                      {status}
                    </button>
                  ))}
                </div>
              </div>
            </CleanCard>
          </div>
        )}

        {/* Main content */}
        <div className="space-y-4">
          {/* Loading State */}
          {isLoadingTransfers && (
            <CleanCard className="py-24 bg-gradient-to-br from-white to-ios-secondary-background/50 shadow-lg">
              <MinimalLoadingView text="LOADING TRANSFERS" />
            </CleanCard>
          )}

          {/* Error State */}
          {!isLoadingTransfers && transfersError && (
            <CleanCard className="py-24 bg-gradient-to-br from-white to-ios-secondary-background/50 shadow-lg">
              <div className="text-center space-y-4">
                <div className="inline-flex p-4 bg-ios-destructive/10 rounded-full">
                  <AlertTriangle className="h-8 w-8 text-ios-destructive" />
                </div>
                <div>
                  <p className="text-lg font-semibold text-ios-destructive mb-2">Error Loading Transfers</p>
                  <p className="text-sm text-ios-secondary-text">{transfersError.message}</p>
                </div>
                <Button
                  onClick={() => queryClient.invalidateQueries({ queryKey: ['transfers'] })}
                  className="bg-ios-accent hover:bg-ios-accent/90 text-white rounded-lg px-6 py-2.5 font-medium shadow-sm transition-all duration-200"
                >
                  Try Again
                </Button>
              </div>
            </CleanCard>
          )}

          {/* Empty State */}
          {!isLoadingTransfers && !transfersError && sortedTransfers.length === 0 && (
            <CleanCard className="py-24 bg-gradient-to-br from-white to-ios-secondary-background/50 shadow-lg">
              <MinimalEmptyState
                icon={
                  activeView === 'incoming' 
                    ? <ArrowDownCircle className="h-12 w-12" /> 
                    : activeView === 'outgoing'
                    ? <ArrowUpCircle className="h-12 w-12" />
                    : <History className="h-12 w-12" />
                }
                title={`NO ${activeView.toUpperCase()} TRANSFERS`}
                description={
                  activeView === 'incoming' 
                    ? "Transfer requests from your connections will appear here"
                    : activeView === 'outgoing'
                    ? "Your outgoing transfer requests will appear here"
                    : "Your complete transfer history will appear here"
                }
                action={activeView !== 'incoming' ? (
                  <Button
                    onClick={() => dispatch({ type: 'TOGGLE_NEW_TRANSFER', payload: true })}
                    className="bg-ios-accent hover:bg-ios-accent/90 text-white rounded-lg px-6 py-2.5 font-medium shadow-sm transition-all duration-200 flex items-center gap-2 border-0"
                  >
                    <Plus className="h-4 w-4" />
                    Create Transfer
                  </Button>
                ) : undefined}
              />
            </CleanCard>
          )}

          {/* Transfer List with stats */}
          {!isLoadingTransfers && !transfersError && sortedTransfers.length > 0 && (
            <>
              {/* Summary Stats */}
              <div className="grid grid-cols-3 gap-4 mb-6">
                <div className="bg-gradient-to-br from-white to-ios-secondary-background rounded-xl p-4 border border-ios-border shadow-sm">
                  <div className="text-2xl font-bold text-ios-primary-text font-['Courier_New',_monospace]">
                    {sortedTransfers.length}
                  </div>
                  <div className="text-xs text-ios-secondary-text uppercase tracking-wider font-['Courier_New',_monospace]">
                    Total
                  </div>
                </div>
                <div className="bg-gradient-to-br from-white to-ios-secondary-background rounded-xl p-4 border border-ios-border shadow-sm">
                  <div className="text-2xl font-bold text-orange-500 font-['Courier_New',_monospace]">
                    {sortedTransfers.filter(t => t.status === 'pending').length}
                  </div>
                  <div className="text-xs text-ios-secondary-text uppercase tracking-wider font-['Courier_New',_monospace]">
                    Pending
                  </div>
                </div>
                <div className="bg-gradient-to-br from-white to-ios-secondary-background rounded-xl p-4 border border-ios-border shadow-sm">
                  <div className="text-2xl font-bold text-green-500 font-['Courier_New',_monospace]">
                    {sortedTransfers.filter(t => t.status === 'approved').length}
                  </div>
                  <div className="text-xs text-ios-secondary-text uppercase tracking-wider font-['Courier_New',_monospace]">
                    Approved
                  </div>
                </div>
              </div>

              {/* Transfer Cards */}
              <div className="space-y-4">
                {sortedTransfers.map((transfer) => (
                  <TransferCard
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
            </>
          )}
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

// Transfer Stats Component
const TransferStats: React.FC<{ transfers: Transfer[] }> = ({ transfers }) => {
  const stats = useMemo(() => {
    const total = transfers.length;
    const pending = transfers.filter(t => t.status === 'pending').length;
    const approved = transfers.filter(t => t.status === 'approved').length;
    const rejected = transfers.filter(t => t.status === 'rejected').length;
    const thisMonth = transfers.filter(t => {
      const createdAt = new Date(t.date);
      const now = new Date();
      return createdAt.getMonth() === now.getMonth() && createdAt.getFullYear() === now.getFullYear();
    }).length;
    
    return { total, pending, approved, rejected, thisMonth };
  }, [transfers]);
  
  return (
    <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-8">
      {[
        { label: 'Total Transfers', value: stats.total, icon: <ArrowLeftRight className="h-5 w-5" />, color: 'orange' },
        { label: 'Pending', value: stats.pending, icon: <Clock8 className="h-5 w-5" />, color: 'amber' },
        { label: 'Approved', value: stats.approved, icon: <CheckCircle className="h-5 w-5" />, color: 'green' },
        { label: 'Rejected', value: stats.rejected, icon: <XCircle className="h-5 w-5" />, color: 'red' },
        { label: 'This Month', value: stats.thisMonth, icon: <Activity className="h-5 w-5" />, color: 'purple' }
      ].map((stat, idx) => (
        <div key={idx} className="group bg-gradient-to-br from-white to-ios-secondary-background/70 rounded-xl p-6 border border-ios-border shadow-lg hover:shadow-xl hover:scale-[1.02] transition-all duration-300 transform-gpu">
          <div className="flex items-center justify-between mb-2">
            <div className={cn(
              "p-3 rounded-lg transition-all duration-300 group-hover:scale-110",
              stat.color === 'orange' && "bg-orange-500/10 text-orange-500",
              stat.color === 'amber' && "bg-amber-500/10 text-amber-500",
              stat.color === 'green' && "bg-green-500/10 text-green-500",
              stat.color === 'red' && "bg-red-500/10 text-red-500",
              stat.color === 'purple' && "bg-purple-500/10 text-purple-500"
            )}>
              {stat.icon}
            </div>
            <span className="text-3xl font-bold text-ios-primary-text font-['Courier_New',_monospace]">
              {stat.value}
            </span>
          </div>
          <p className="text-sm font-medium text-ios-secondary-text">{stat.label}</p>
        </div>
      ))}
    </div>
  );
};

export default Transfers; 