import { useState, useEffect, useMemo, useReducer, useCallback, useRef } from"react";
import { useProperties, useOfflineSync, useUpdatePropertyComponents, useCreateProperty } from"@/hooks/useProperty";
import { useTransfers } from"@/hooks/useTransfers";
import { Property, Transfer, Component } from "@/types";
import { v4 as uuidv4 } from 'uuid';
import { Input } from"@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from"@/components/ui/select";
import { Button } from"@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from"@/components/ui/tabs";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from"@/components/ui/dialog";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from"@/components/ui/table";
import { useToast } from"@/hooks/use-toast";
import { CleanCard, ElegantSectionHeader, StatusBadge, ModernPropertyCard, FloatingActionButton, MinimalEmptyState, MinimalLoadingView } from"@/components/ios";
import TransferRequestModal from"@/components/modals/TransferRequestModal";
import ComponentList from"@/components/property/ComponentList";
import { SwipeablePropertyCard } from"@/components/property/SwipeablePropertyCard";
import { ScrollableContainer } from"@/components/ui/scrollable-container";
import { Search, Filter, ArrowDownUp, ArrowLeftRight, Info, ClipboardCheck, Calendar, ShieldCheck, Send, CheckCircle, Package, Shield, Radio, Eye, Wrench, SearchX, ArrowUpDown, ChevronDown, ChevronRight, Plus, Download, FileText, WifiOff, X, Loader2
} from"lucide-react";
import { Checkbox } from"@/components/ui/checkbox";
import BulkActionMenu from"@/components/shared/BulkActionMenu";
import { Skeleton } from"@/components/ui/skeleton";
import { cn } from"@/lib/utils";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from"@/components/ui/tooltip";
import { propertyBookReducer, initialState } from"@/lib/propertyBookReducer";
import { categoryOptions, getCategoryFromName, getCategoryColor, getCategoryIcon, normalizeItemStatus } from"@/lib/propertyUtils";
import CreatePropertyDialog from"@/components/property/CreatePropertyDialog";
import { SendMaintenanceForm } from"@/components/property/SendMaintenanceForm";
import { DA2062ExportDialog } from"@/components/da2062/DA2062ExportDialog";
import { DA2062ImportDialog } from"@/components/da2062/DA2062ImportDialog";

// Type alias for display items
type DisplayItem = Property & {
  assignedTo?: string;
  transferDate?: string;
};

// Filter types (matching iOS)
type PropertyFilterType = 'all' | 'category' | 'status' | 'location';
type PropertyFilterStatus = 'all' | 'operational' | 'non-operational' | 'maintenance' | 'missing';

interface PropertyBookProps { 
  id?: string;
}

const PropertyBook: React.FC<PropertyBookProps> = ({ id }) => {
  console.log("PropertyBook component rendering...", { id });

  // Add error boundary state
  const [hasError, setHasError] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string>("");

  // Use reducer for most state management
  const [state, dispatch] = useReducer(propertyBookReducer, initialState);
  
  // State that remains outside the reducer
  const [selectedItem, setSelectedItem] = useState<Property | null>(null);
  const [transferModalOpen, setTransferModalOpen] = useState(false);
  const [detailsModalOpen, setDetailsModalOpen] = useState(false);
  const [createItemModalOpen, setCreateItemModalOpen] = useState(false);
  const [maintenanceFormModalOpen, setMaintenanceFormModalOpen] = useState(false);
  const [showingDA2062Export, setShowingDA2062Export] = useState(false);
  const [showingDA2062Import, setShowingDA2062Import] = useState(false);
  const [isSelectMode, setIsSelectMode] = useState(false);
  const [selectedPropertiesForExport, setSelectedPropertiesForExport] = useState<Set<string>>(new Set());
  const [showingSortOptions, setShowingSortOptions] = useState(false);
  const [showingAddMenu, setShowingAddMenu] = useState(false);
  const [isOffline, setIsOffline] = useState(!navigator.onLine);
  const [selectedFilterType, setSelectedFilterType] = useState<PropertyFilterType>('all');
  const [selectedStatus, setSelectedStatus] = useState<PropertyFilterStatus>('all');
  const [isSyncing, setIsSyncing] = useState(false);
  const [bulkActionProgress, setBulkActionProgress] = useState<{active: boolean; current: number; total: number}>({active: false, current: 0, total: 0});
  const headerRef = useRef<HTMLDivElement>(null);
  const [isHeaderSticky, setIsHeaderSticky] = useState(false);
  
  const { toast } = useToast();
  
  // Use React Query hooks for data fetching
  const { data: properties = [], isLoading, error } = useProperties();
  const { data: transfers = [] } = useTransfers();
  const updateComponents = useUpdatePropertyComponents();
  const createProperty = useCreateProperty();
  
  console.log("PropertyBook data:", { 
    properties, 
    isLoading, 
    error: error?.message,
    transfers,
    state 
  });

  // Setup offline sync
  useOfflineSync();

  // Setup offline listener
  useEffect(() => {
    const handleOnline = () => setIsOffline(false);
    const handleOffline = () => setIsOffline(true);
    
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
    
    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  // Update loading and error states
  useEffect(() => {
    dispatch({ type: 'SET_LOADING', payload: isLoading });
    dispatch({ type: 'SET_ERROR', payload: error?.message || null });
  }, [isLoading, error]);

  // Create memoized data for assigned items
  const assignedToMe = useMemo(() => {
    const result = properties.map(item => ({
      ...item,
      category: getCategoryFromName(item.name)
    }));
    console.log("assignedToMe computed:", result);
    return result;
  }, [properties]);

  // Create memoized data for signed-out items based on transfers
  const signedOutItems = useMemo(() => {
    const result = transfers
      .filter(transfer => transfer.status === "approved")
      .map(transfer => {
        const originalItem = properties.find(i => i.serialNumber === transfer.serialNumber);
        const derivedCategory = getCategoryFromName(transfer.name);
        
        return {
          ...(originalItem || {}),
          id: originalItem?.id || transfer.id,
          name: transfer.name,
          serialNumber: transfer.serialNumber,
          status: originalItem?.status || "Operational",
          description: originalItem?.description || "Transferred",
          category: derivedCategory,
          location: "Transferred",
          assignedTo: transfer.to,
          transferDate: transfer.date,
          assignedDate: originalItem?.assignedDate || transfer.date,
          components: originalItem?.components || [],
          isComponent: originalItem?.isComponent || false,
          parentItemId: originalItem?.parentItemId,
        };
      });
    console.log("signedOutItems computed:", result);
    return result;
  }, [properties, transfers]);

  // Filter items based on search, category, and status
  const getFilteredItems = useCallback((items: DisplayItem[], tab: string) => {
    return items.filter(item => {
      const name = item.name || '';
      const serialNumber = item.serialNumber || '';
      const nsn = item.nsn || '';
      const assignedTo = (tab === "signedout" && item.assignedTo) ? item.assignedTo.toLowerCase() : '';
      const searchTermLower = state.searchTerm.toLowerCase();
      
      const matchesSearch = name.toLowerCase().includes(searchTermLower) ||
                           serialNumber.toLowerCase().includes(searchTermLower) ||
                           nsn.toLowerCase().includes(searchTermLower) ||
                           (tab === "signedout" && assignedTo.includes(searchTermLower));
      
      // Category filter
      const category = item.category && categoryOptions.some(opt => opt.value === item.category) 
        ? item.category 
        : getCategoryFromName(item.name);
      const matchesCategory = state.filterCategory === "all" || category === state.filterCategory;
      
      // Status filter
      const itemStatus = normalizeItemStatus(item.status || 'Unknown').toLowerCase();
      const matchesStatus = selectedStatus === 'all' || itemStatus === selectedStatus;
      
      return matchesSearch && matchesCategory && matchesStatus;
    });
  }, [state.searchTerm, state.filterCategory, selectedStatus]);

  // Get items for the current tab, filtered and sorted
  const getCurrentItems = useCallback(() => {
    const itemsForTab = state.activeTab === 'assigned' ? assignedToMe : signedOutItems;
    return getFilteredItems(itemsForTab, state.activeTab);
  }, [assignedToMe, signedOutItems, state.activeTab, getFilteredItems]);

  // Handler for item transfer requests
  const handleTransferRequest = useCallback((item: Property) => {
    setSelectedItem(item);
    setTransferModalOpen(true);
  }, []);

  // Handler for viewing item details
  const handleViewDetails = useCallback((item: Property) => {
    const normalizedItem: Property = {
      ...item,
      status: normalizeItemStatus(item.status) as Property['status']
    };
    setSelectedItem(normalizedItem);
    setDetailsModalOpen(true);
  }, []);

  // Handler for recalling an item
  const handleRecallItem = useCallback((item: Property) => {
    toast({
      title: "Recall Action",
      description: "Recall workflow initiated for " + item.name
    });
  }, [toast]);

  // Handler for sending maintenance form
  const handleSendMaintenanceForm = useCallback((item: Property) => {
    setSelectedItem(item);
    setMaintenanceFormModalOpen(true);
  }, []);

  // Handler for adding a component to an item
  const handleAddComponent = async (newComponentData: Omit<Component, 'id'>) => {
    if (!selectedItem) return;
    
    const newComponent: Component = {
      ...newComponentData,
      id: uuidv4()
    };
    
    const updatedComponents = [...(selectedItem.components || []), newComponent];
    
    updateComponents.mutate(
      { id: selectedItem.id, components: updatedComponents },
      {
        onSuccess: (updatedItem) => {
          toast({
            title: "Component Added",
            description: `${newComponent.name} added.`
          });
          setSelectedItem(updatedItem);
        }
      }
    );
  };

  // Handler for updating a component
  const handleUpdateComponent = async (updatedComponent: Component) => {
    if (!selectedItem || !selectedItem.components) return;
    
    const updatedComponents = selectedItem.components.map(comp =>
      comp.id === updatedComponent.id ? updatedComponent : comp
    );
    
    updateComponents.mutate(
      { id: selectedItem.id, components: updatedComponents },
      {
        onSuccess: (updatedItem) => {
          toast({
            title: "Component Updated",
            description: `${updatedComponent.name} updated.`
          });
          setSelectedItem(updatedItem);
        }
      }
    );
  };

  // Handler for removing a component
  const handleRemoveComponent = async (componentId: string) => {
    if (!selectedItem || !selectedItem.components) return;
    
    const componentToRemove = selectedItem.components.find(c => c.id === componentId);
    const updatedComponents = selectedItem.components.filter(comp => comp.id !== componentId);
    
    updateComponents.mutate(
      { id: selectedItem.id, components: updatedComponents },
      {
        onSuccess: (updatedItem) => {
          toast({
            title: "Component Removed",
            description: `${componentToRemove?.name || 'Component'} removed.`
          });
          setSelectedItem(updatedItem);
        }
      }
    );
  };

  // Handler for bulk actions with progress
  const handleBulkAction = useCallback(async (action: string) => {
    const selectedIds = Array.from(state.selectedItemIds);
    setBulkActionProgress({ active: true, current: 0, total: selectedIds.length });
    
    try {
      for (let i = 0; i < selectedIds.length; i++) {
        setBulkActionProgress({ active: true, current: i + 1, total: selectedIds.length });
        // Simulate async operation
        await new Promise(resolve => setTimeout(resolve, 200));
      }
      
      toast({
        title: `${action} completed`,
        description: `Successfully processed ${selectedIds.length} items.`,
      });
    } catch (error) {
      toast({
        title: `${action} failed`,
        description: `An error occurred while processing items.`,
        variant: "destructive",
      });
    } finally {
      setBulkActionProgress({ active: false, current: 0, total: 0 });
      dispatch({ type: 'CLEAR_SELECTIONS' });
    }
  }, [state.selectedItemIds, toast]);

  // Handler for item selection
  const handleItemSelect = useCallback((itemId: string) => {
    dispatch({ type: 'TOGGLE_ITEM_SELECTION', payload: itemId });
  }, []);

  // Handler for creating a new item
  const handleCreateItem = useCallback(async (itemData: {
    name: string;
    serialNumber: string;
    description?: string;
    category: string;
    nsn?: string;
    lin?: string;
    assignToSelf: boolean;
  }) => {
    try {
      await createProperty.mutateAsync({
        name: itemData.name,
        serialNumber: itemData.serialNumber,
        description: itemData.description,
        currentStatus: 'Operational',
        nsn: itemData.nsn,
        lin: itemData.lin,
        assignedToUserId: itemData.assignToSelf ? parseInt(localStorage.getItem('userId') || '0') : undefined,
      });
      
      toast({
        title: "Digital Twin Created",
        description: `${itemData.name} (SN: ${itemData.serialNumber}) has been registered successfully.`,
      });
      
      setCreateItemModalOpen(false);
    } catch (error) {
      if (error instanceof Error) {
        if (error.message?.includes('duplicate') || error.message?.includes('unique') || error.message?.includes('already exists')) {
          toast({
            title: "Duplicate Serial Number",
            description: `An item with serial number ${itemData.serialNumber} already exists.`,
            variant: "destructive",
          });
        } else {
          toast({
            title: "Error Creating Item",
            description: error.message || "Failed to create the digital twin. Please try again.",
            variant: "destructive",
          });
        }
      } else {
        toast({
          title: "Error Creating Item",
          description: "Failed to create the digital twin. Please try again.",
          variant: "destructive",
        });
      }
      throw error;
    }
  }, [createProperty, toast]);

  // Get current items for display
  const currentItems = getCurrentItems();
  const hasSelectedItems = state.selectedItemIds.size > 0;

  console.log("About to render PropertyBook with:", {
    currentItems: currentItems.length,
    isLoading: state.isLoading,
    hasSelectedItems,
    activeTab: state.activeTab
  });

  // Effect for handling direct navigation to an item via id prop
  useEffect(() => {
    if (!state.isLoading && id) {
      const assignedItem = properties.find(item => item.id === id);
      const signedOutItemDetails = signedOutItems.find(item => item.id === id);
      
      let itemToSelect: Property | DisplayItem | null = null;
      
      if (assignedItem) {
        itemToSelect = assignedItem;
      } else if (signedOutItemDetails) {
        itemToSelect = signedOutItemDetails;
      }
      
      if (itemToSelect) {
        const finalSelectedItem: Property = {
          id: itemToSelect.id,
          name: itemToSelect.name,
          serialNumber: itemToSelect.serialNumber,
          assignedDate: itemToSelect.assignedDate || '',
          status: itemToSelect.status,
          description: itemToSelect.description || "",
          category: itemToSelect.category || "other",
          location: itemToSelect.location || "",
          components: itemToSelect.components || [],
          isComponent: itemToSelect.isComponent || false,
          parentItemId: itemToSelect.parentItemId
        };
        
        setSelectedItem(finalSelectedItem);
        setDetailsModalOpen(true);
      }
    }
  }, [id, properties, signedOutItems, state.isLoading]);

  // Sticky header on scroll
  useEffect(() => {
    const handleScroll = () => {
      if (headerRef.current) {
        const scrollTop = window.scrollY;
        setIsHeaderSticky(scrollTop > 100);
      }
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  // Handle error state after all hooks are called
  if (error) {
    console.error("PropertyBook error:", error);
    return (
      <div className="min-h-screen bg-app-background">
        <div className="max-w-7xl mx-auto px-6 py-8">
          <div className="text-center">
            <h1 className="text-2xl font-bold text-red-600 mb-4">Error Loading Property Book</h1>
            <p className="text-gray-600 mb-4">{error?.message || "Unknown error occurred"}</p>
            <Button onClick={() => window.location.reload()}>
              Reload Page
            </Button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen" style={{ backgroundColor: '#FAFAFA' }}>
      {/* Sticky header for mobile */}
      <div 
        ref={headerRef}
        className={cn(
          "fixed top-0 left-0 right-0 z-40 bg-white border-b border-ios-divider transition-all duration-200 md:hidden",
          isHeaderSticky ? "opacity-100 translate-y-0" : "opacity-0 -translate-y-full pointer-events-none"
        )}
      >
        <div className="px-4 py-3">
          <div className="flex items-center justify-between mb-2">
            <h2 className="text-lg font-semibold text-primary-text">Property Book</h2>
            {isSelectMode && (
              <Button
                onClick={() => {
                  setIsSelectMode(false);
                  setSelectedPropertiesForExport(new Set());
                }}
                variant="ghost"
                size="sm"
                className="text-sm font-medium text-ios-accent hover:bg-transparent px-0"
              >
                Cancel
              </Button>
            )}
          </div>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-tertiary-text" />
            <Input
              placeholder="Search properties..."
              value={state.searchTerm}
              onChange={(e) => dispatch({ type: 'SET_SEARCH_TERM', payload: e.target.value })}
              className="pl-10 border-0 bg-gray-50 rounded-lg h-9 text-sm"
            />
          </div>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 md:px-6 py-4 md:py-8">
        {/* Header - iOS style */}
        <div className="mb-6 md:mb-10">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between mb-4 md:mb-6">
            <div className="md:hidden">
              <p className="text-sm text-secondary-text">
                {properties.length} items tracked
              </p>
            </div>
            <div className="hidden md:block"></div>
            {!isSelectMode && properties.length > 0 && (
              <Button
                onClick={() => setIsSelectMode(true)}
                variant="ghost"
                size="sm"
                className="text-sm font-medium text-ios-accent hover:bg-transparent px-0"
              >
                Select
              </Button>
            )}
            {isSelectMode && (
              <Button
                onClick={() => {
                  setIsSelectMode(false);
                  setSelectedPropertiesForExport(new Set());
                }}
                variant="ghost"
                size="sm"
                className="text-sm font-medium text-ios-accent hover:bg-transparent px-0"
              >
                Cancel
              </Button>
            )}
          </div>
          
          {/* Divider */}
          <div className="hidden md:block border-b border-ios-divider mb-6" />
          
          {/* Title section - hidden on mobile when scrolled */}
          <div className="mb-6 md:mb-8">
            <h1 className="text-3xl md:text-5xl font-bold text-primary-text leading-tight" style={{ fontFamily: 'ui-serif, Georgia, serif' }}>
              Property Book
            </h1>
            <p className="hidden md:block text-secondary-text mt-2">
              {properties.length} items tracked
            </p>
          </div>
        </div>
        
        {/* Offline banner with sync status */}
        {isOffline && (
          <div className="mb-4 md:mb-6 bg-ios-warning/10 rounded-lg p-3 md:p-4 border border-ios-warning/20">
            <div className="flex items-center gap-3">
              <WifiOff className="h-4 w-4 text-ios-warning flex-shrink-0" />
              <div className="flex-1">
                <p className="text-sm font-medium text-primary-text">Offline Mode</p>
                <p className="text-xs text-secondary-text">Changes will sync when connected</p>
              </div>
              {isSyncing && (
                <Loader2 className="h-4 w-4 text-ios-warning animate-spin" />
              )}
            </div>
          </div>
        )}

        {/* Search and Filter Controls */}
        <div className="mb-4 md:mb-6 space-y-3 md:space-y-4">
          {/* Desktop search */}
          <div className="hidden md:block">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-tertiary-text" />
              <Input
                placeholder="Search properties..."
                value={state.searchTerm}
                onChange={(e) => dispatch({ type: 'SET_SEARCH_TERM', payload: e.target.value })}
                className="pl-10 border-0 bg-white rounded-lg h-10 text-base placeholder:text-quaternary-text focus-visible:ring-1 focus-visible:ring-ios-accent shadow-sm"
              />
              {state.searchTerm && (
                <button
                  onClick={() => dispatch({ type: 'SET_SEARCH_TERM', payload: '' })}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2"
                >
                  <X className="h-4 w-4 text-tertiary-text" />
                </button>
              )}
            </div>
          </div>

          {/* Mobile search */}
          <div className="md:hidden">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-tertiary-text" />
              <Input
                placeholder="Search properties..."
                value={state.searchTerm}
                onChange={(e) => dispatch({ type: 'SET_SEARCH_TERM', payload: e.target.value })}
                className="pl-10 border-0 bg-white rounded-lg h-10 text-base placeholder:text-quaternary-text focus-visible:ring-1 focus-visible:ring-ios-accent"
              />
              {state.searchTerm && (
                <button
                  onClick={() => dispatch({ type: 'SET_SEARCH_TERM', payload: '' })}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2"
                >
                  <X className="h-4 w-4 text-tertiary-text" />
                </button>
              )}
            </div>
          </div>
          
          {/* Action buttons row */}
          <div className="flex gap-2 md:gap-3">
            {/* Filter/Sort button */}
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowingSortOptions(true)}
              className="border-ios-border text-secondary-text hover:text-primary-text text-xs md:text-sm"
            >
              <Filter className="h-4 w-4 mr-1 md:mr-2" />
              Sort
            </Button>
            
            {/* Add button */}
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowingAddMenu(true)}
              className="border-ios-border text-secondary-text hover:text-primary-text text-xs md:text-sm"
            >
              <Plus className="h-4 w-4 mr-1 md:mr-2" />
              Add
            </Button>
          </div>
          
          {/* iOS-style filter tabs */}
          <div className="space-y-3">
            {/* Main filter type selector */}
            <div className="w-full overflow-hidden">
              <div className="overflow-x-auto scrollbar-hide -mx-4 px-4 md:mx-0 md:px-0" style={{ WebkitOverflowScrolling: 'touch' }}>
                <div className="flex gap-2 w-max pb-1">
                  <FilterTypeChip
                    label="ALL"
                    active={selectedFilterType === 'all'}
                    onClick={() => {
                      setSelectedFilterType('all');
                      dispatch({ type: 'SET_FILTER_CATEGORY', payload: 'all' });
                      setSelectedStatus('all');
                    }}
                  />
                  <FilterTypeChip
                    label="CATEGORY"
                    active={selectedFilterType === 'category'}
                    onClick={() => setSelectedFilterType('category')}
                  />
                  <FilterTypeChip
                    label="STATUS"
                    active={selectedFilterType === 'status'}
                    onClick={() => setSelectedFilterType('status')}
                  />
                  <FilterTypeChip
                    label="LOCATION"
                    active={selectedFilterType === 'location'}
                    onClick={() => setSelectedFilterType('location')}
                  />
                </div>
              </div>
            </div>

            {/* Sub-filter chips */}
            {(selectedFilterType === 'category' || selectedFilterType === 'status') && (
              <div className="w-full overflow-hidden">
                <div className="overflow-x-auto scrollbar-hide -mx-4 px-4 md:mx-0 md:px-0" style={{ WebkitOverflowScrolling: 'touch' }}>
                  <div className="flex gap-2 w-max pb-1">
                    {selectedFilterType === 'category' && (
                      <>
                        <FilterChip
                          label="All"
                          active={state.filterCategory === 'all'}
                          onClick={() => dispatch({ type: 'SET_FILTER_CATEGORY', payload: 'all' })}
                        />
                        {categoryOptions.map((category) => (
                          <FilterChip
                            key={category.value}
                            label={category.label}
                            active={state.filterCategory === category.value}
                            onClick={() => dispatch({ type: 'SET_FILTER_CATEGORY', payload: category.value })}
                          />
                        ))}
                      </>
                    )}
                  
                  {selectedFilterType === 'status' && (
                    <>
                      <FilterChip
                        label="All"
                        active={selectedStatus === 'all'}
                        onClick={() => setSelectedStatus('all')}
                      />
                      <FilterChip
                        label="FMC"
                        active={selectedStatus === 'operational'}
                        onClick={() => setSelectedStatus('operational')}
                      />
                      <FilterChip
                        label="NMC"
                        active={selectedStatus === 'non-operational'}
                        onClick={() => setSelectedStatus('non-operational')}
                      />
                      <FilterChip
                        label="DL"
                        active={selectedStatus === 'maintenance'}
                        onClick={() => setSelectedStatus('maintenance')}
                      />
                      <FilterChip
                        label="Missing"
                        active={selectedStatus === 'missing'}
                        onClick={() => setSelectedStatus('missing')}
                      />
                    </>
                  )}
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Bulk action progress bar */}
        {bulkActionProgress.active && (
          <div className="mb-4 bg-white rounded-lg p-4 shadow-sm border border-ios-border">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-primary-text">Processing items...</span>
              <span className="text-sm text-secondary-text">
                {bulkActionProgress.current} / {bulkActionProgress.total}
              </span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className="bg-ios-accent h-2 rounded-full transition-all duration-300"
                style={{ width: `${(bulkActionProgress.current / bulkActionProgress.total) * 100}%` }}
              />
            </div>
          </div>
        )}

        {/* Main content */}
        <div className="space-y-3">

          {state.isLoading && assignedToMe.length === 0 && !isOffline ? (
            <div className="space-y-3">
              {/* Skeleton loaders for cards */}
              {[1, 2, 3, 4].map((i) => (
                <PropertyCardSkeleton key={i} />
              ))}
            </div>
          ) : error && assignedToMe.length === 0 ? (
            <CleanCard className="py-16 text-center">
              <p className="text-ios-destructive mb-2">Error loading properties</p>
              <p className="text-secondary-text text-sm">{error?.message || "Please try again later"}</p>
              <Button
                onClick={() => window.location.reload()}
                variant="outline"
                size="sm"
                className="mt-4"
              >
                Retry
              </Button>
            </CleanCard>
          ) : currentItems.length === 0 ? (
            <MinimalEmptyState
              title={state.searchTerm || state.filterCategory !== "all" 
                ? "No Results Found" 
                : "No Properties Found"}
              description={state.searchTerm || state.filterCategory !== "all" 
                ? "Try adjusting your search terms or filters." 
                : "Properties assigned to you will appear here."}
              icon={state.searchTerm ? <SearchX className="h-12 w-12" /> : <Package className="h-12 w-12" />}
              action={
                state.searchTerm || state.filterCategory !== "all" ? null : (
                  <Button
                    onClick={() => setShowingAddMenu(true)}
                    className="bg-blue-600 hover:bg-blue-700 text-white"
                  >
                    Add Property
                  </Button>
                )
              }
            />
          ) : (
            <div className="space-y-3">
              {currentItems.map((item) => (
                <SwipeablePropertyCard
                  key={item.id}
                  property={item}
                  isSelected={isSelectMode && selectedPropertiesForExport.has(item.id)}
                  isSelectMode={isSelectMode}
                  onTap={() => {
                    if (isSelectMode) {
                      if (selectedPropertiesForExport.has(item.id)) {
                        const newSet = new Set(selectedPropertiesForExport);
                        newSet.delete(item.id);
                        setSelectedPropertiesForExport(newSet);
                      } else {
                        setSelectedPropertiesForExport(new Set([...selectedPropertiesForExport, item.id]));
                      }
                    } else {
                      handleViewDetails(item);
                    }
                  }}
                  onTransfer={() => {
                    setSelectedItem(item);
                    setTransferModalOpen(true);
                  }}
                  onMaintenance={() => {
                    setSelectedItem(item);
                    setMaintenanceFormModalOpen(true);
                  }}
                  onViewDetails={() => handleViewDetails(item)}
                />
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Floating export button when items are selected */}
      {isSelectMode && selectedPropertiesForExport.size > 0 && (
        <div className="fixed bottom-6 right-6 z-50">
          <Button
            onClick={() => setShowingDA2062Export(true)}
            className="bg-ios-accent hover:bg-ios-accent/90 text-white shadow-lg rounded-lg px-6 py-3"
          >
            <FileText className="h-5 w-5 mr-2" />
            Export DA 2062 ({selectedPropertiesForExport.size})
          </Button>
        </div>
      )}

      {/* Modals */}
      {selectedItem && (
        <TransferRequestModal
          isOpen={transferModalOpen}
          onClose={() => setTransferModalOpen(false)}
          item={selectedItem}
        />
      )}

      <Dialog open={detailsModalOpen} onOpenChange={setDetailsModalOpen}>
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="text-primary-text">{selectedItem?.name}</DialogTitle>
            <DialogDescription className="text-secondary-text">
              Serial Number: {selectedItem?.serialNumber}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-6">
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <label className="text-tertiary-text text-xs uppercase tracking-wide font-medium">
                  STATUS
                </label>
                <div className="mt-1">
                  {selectedItem && (
                    <StatusBadge
                      status={selectedItem.status === 'Operational' ? 'operational' : 
                             selectedItem.status === 'Non-Operational' ? 'non-operational' : 'maintenance'}
                    />
                  )}
                </div>
              </div>
              <div>
                <label className="text-tertiary-text text-xs uppercase tracking-wide font-medium">
                  CATEGORY
                </label>
                <div className="mt-1 text-primary-text font-mono">
                  {selectedItem?.category || 'Other'}
                </div>
              </div>
            </div>

            {selectedItem?.components && selectedItem.components.length > 0 && (
              <div>
                <ElegantSectionHeader title="COMPONENTS" className="mb-4" />
                <ComponentList
                  itemId={selectedItem.id}
                  components={selectedItem.components}
                  onAddComponent={handleAddComponent}
                  onUpdateComponent={handleUpdateComponent}
                  onRemoveComponent={handleRemoveComponent}
                />
              </div>
            )}
          </div>
          <DialogFooter className="gap-2">
            <Button
              variant="outline"
              onClick={() => setDetailsModalOpen(false)}
              className="text-primary-text border-ios-border hover:bg-gray-50"
            >
              Close
            </Button>
            <Button
              onClick={() => {
                setDetailsModalOpen(false);
                if (selectedItem) handleTransferRequest(selectedItem);
              }}
              className="bg-ios-accent hover:bg-accent-hover text-white"
            >
              Transfer Item
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <CreatePropertyDialog
        isOpen={createItemModalOpen}
        onClose={() => setCreateItemModalOpen(false)}
        onSubmit={handleCreateItem}
      />

      {selectedItem && (
        <SendMaintenanceForm
          open={maintenanceFormModalOpen}
          onClose={() => setMaintenanceFormModalOpen(false)}
          property={{
            id: typeof selectedItem.id === 'string' ? parseInt(selectedItem.id) : selectedItem.id,
            name: selectedItem.name,
            serialNumber: selectedItem.serialNumber,
            nsn: selectedItem.nsn,
            location: selectedItem.location,
          }}
        />
      )}
      
      {/* DA 2062 Export Dialog */}
      <DA2062ExportDialog
        isOpen={showingDA2062Export}
        onClose={() => {
          setShowingDA2062Export(false);
          setIsSelectMode(false);
          setSelectedPropertiesForExport(new Set());
        }}
        selectedProperties={Array.from(selectedPropertiesForExport).map(id => 
          properties.find(p => p.id === id)
        ).filter(Boolean) as Property[]}
      />
      
      {/* DA 2062 Import Dialog */}
      <DA2062ImportDialog
        isOpen={showingDA2062Import}
        onClose={() => setShowingDA2062Import(false)}
        onImportComplete={(count) => {
          toast({
            title: 'Import successful',
            description: `${count} items imported successfully`,
          });
          // Refetch properties to show newly imported items
          window.location.reload(); // Simple refresh for now
        }}
      />
      
      {/* Sort Options Action Sheet */}
      <Dialog open={showingSortOptions} onOpenChange={setShowingSortOptions}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle>Sort Properties</DialogTitle>
          </DialogHeader>
          <div className="space-y-2">
            <Button
              variant="ghost"
              className="w-full justify-start"
              onClick={() => {
                // Sort by name logic
                setShowingSortOptions(false);
              }}
            >
              By Name
            </Button>
            <Button
              variant="ghost"
              className="w-full justify-start"
              onClick={() => {
                // Sort by serial number logic
                setShowingSortOptions(false);
              }}
            >
              By Serial Number
            </Button>
            <Button
              variant="ghost"
              className="w-full justify-start"
              onClick={() => {
                // Sort by status logic
                setShowingSortOptions(false);
              }}
            >
              By Status
            </Button>
          </div>
        </DialogContent>
      </Dialog>
      
      {/* Add Menu Action Sheet */}
      <Dialog open={showingAddMenu} onOpenChange={setShowingAddMenu}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle>Add Property</DialogTitle>
          </DialogHeader>
          <div className="space-y-2">
            <Button
              variant="ghost"
              className="w-full justify-start"
              onClick={() => {
                setShowingAddMenu(false);
                setCreateItemModalOpen(true);
              }}
            >
              Create New Property
            </Button>
            <Button
              variant="ghost"
              className="w-full justify-start"
              onClick={() => {
                setShowingAddMenu(false);
                setShowingDA2062Import(true);
              }}
            >
              Import from DA-2062
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
};

// Filter Type Chip Component (iOS style)
interface FilterTypeChipProps {
  label: string;
  active: boolean;
  onClick: () => void;
}

const FilterTypeChip: React.FC<FilterTypeChipProps> = ({ label, active, onClick }) => {
  return (
    <button
      onClick={onClick}
      className={cn(
        "px-4 py-2 text-xs font-medium rounded whitespace-nowrap transition-all uppercase tracking-[0.06em]",
        active
          ? "bg-primary-text text-white"
          : "bg-secondary-background text-secondary-text border border-ios-border"
      )}
    >
      {label}
    </button>
  );
};

// Filter Chip Component
interface FilterChipProps {
  label: string;
  active: boolean;
  onClick: () => void;
}

const FilterChip: React.FC<FilterChipProps> = ({ label, active, onClick }) => {
  return (
    <button
      onClick={onClick}
      className={cn(
        "px-4 py-2 text-xs font-medium rounded whitespace-nowrap transition-all uppercase tracking-[0.06em]",
        active
          ? "bg-primary-text text-white"
          : "bg-secondary-background text-secondary-text border border-ios-border"
      )}
    >
      {label}
    </button>
  );
};

// Property Card Skeleton Component
const PropertyCardSkeleton: React.FC = () => {
  return (
    <CleanCard padding="none">
      <div className="p-6">
        <div className="space-y-5">
          {/* Header skeleton */}
          <div className="flex items-start justify-between">
            <div className="flex-1 space-y-3">
              <Skeleton className="h-6 w-3/4" />
              <Skeleton className="h-4 w-1/2" />
              <Skeleton className="h-3 w-1/3" />
            </div>
            <Skeleton className="h-8 w-8 rounded-full" />
          </div>
          
          {/* Status skeleton */}
          <div className="flex items-center justify-between">
            <Skeleton className="h-4 w-20" />
            <div className="space-y-1">
              <Skeleton className="h-3 w-16 ml-auto" />
              <Skeleton className="h-3 w-20" />
            </div>
          </div>
          
          {/* Action skeleton */}
          <div className="pt-3 border-t border-ios-divider">
            <Skeleton className="h-4 w-16 ml-auto" />
          </div>
        </div>
      </div>
    </CleanCard>
  );
};

export default PropertyBook;