import { useState, useEffect, useMemo, useReducer, useCallback, useRef, useLayoutEffect } from "react";
import { useLocation } from "wouter";
import { useProperties, useOfflineSync, useUpdatePropertyComponents, useCreateProperty } from "@/hooks/useProperty";
import { useTransfers } from "@/hooks/useTransfers";
import { Property, Transfer, Component } from "@/types";
import { v4 as uuidv4 } from 'uuid';
import { Input } from "@/components/ui/input";
import { VirtualPropertyList } from "@/components/VirtualPropertyList";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { useToast } from "@/hooks/use-toast";
import { CleanCard, ElegantSectionHeader, StatusBadge, ModernPropertyCard, FloatingActionButton, MinimalEmptyState, MinimalLoadingView } from "@/components/ios";
import TransferRequestModal from "@/components/modals/TransferRequestModal";
import ComponentList from "@/components/property/ComponentList";
import { SwipeablePropertyCard } from "@/components/property/SwipeablePropertyCard";
import { ScrollableContainer } from "@/components/ui/scrollable-container";
import { 
  Search, 
  Filter, 
  ArrowDownUp, 
  ArrowLeftRight, 
  Info, 
  ClipboardCheck, 
  Calendar, 
  ShieldCheck, 
  Send, 
  CheckCircle, 
  Package, 
  Shield, 
  Radio, 
  Eye, 
  Wrench, 
  SearchX, 
  ArrowUpDown, 
  ChevronDown, 
  ChevronRight, 
  Plus, 
  Download, 
  FileText, 
  WifiOff, 
  X, 
  Loader2,
  Bell,
  SlidersHorizontal,
  BarChart3,
  Zap,
  ArrowRight,
  Activity,
  AlertTriangle
} from "lucide-react";
import { Checkbox } from "@/components/ui/checkbox";
import BulkActionMenu from "@/components/shared/BulkActionMenu";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { propertyBookReducer, initialState } from "@/lib/propertyBookReducer";
import { categoryOptions, getCategoryFromName, getCategoryColor, getCategoryIcon, normalizeItemStatus } from "@/lib/propertyUtils";
import CreatePropertyDialog from "@/components/property/CreatePropertyDialog";
import { DA2062ExportDialog } from "@/components/da2062/DA2062ExportDialog";
import { DA2062ImportDialog } from "@/components/da2062/DA2062ImportDialog";

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

// Custom hook for drag-to-scroll functionality
const useDragToScroll = () => {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [startX, setStartX] = useState(0);
  const [scrollLeft, setScrollLeft] = useState(0);

  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    if (!scrollRef.current) return;
    setIsDragging(true);
    setStartX(e.pageX - scrollRef.current.offsetLeft);
    setScrollLeft(scrollRef.current.scrollLeft);
  }, []);

  const handleMouseUp = useCallback(() => {
    setIsDragging(false);
  }, []);

  const handleMouseMove = useCallback((e: React.MouseEvent) => {
    if (!isDragging || !scrollRef.current) return;
    e.preventDefault();
    const x = e.pageX - scrollRef.current.offsetLeft;
    const walk = (x - startX) * 2; // Multiply by 2 for faster scrolling
    scrollRef.current.scrollLeft = scrollLeft - walk;
  }, [isDragging, startX, scrollLeft]);

  const handleMouseLeave = useCallback(() => {
    setIsDragging(false);
  }, []);

  useEffect(() => {
    const handleMouseUpGlobal = () => setIsDragging(false);
    window.addEventListener('mouseup', handleMouseUpGlobal);
    return () => window.removeEventListener('mouseup', handleMouseUpGlobal);
  }, []);

  return {
    scrollRef,
    handlers: {
      onMouseDown: handleMouseDown,
      onMouseUp: handleMouseUp,
      onMouseMove: handleMouseMove,
      onMouseLeave: handleMouseLeave,
    },
    isDragging
  };
};

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
  const [showingDA2062Export, setShowingDA2062Export] = useState(false);
  const [showingDA2062Import, setShowingDA2062Import] = useState(false);
  const [showingSortOptions, setShowingSortOptions] = useState(false);
  const [showingAddMenu, setShowingAddMenu] = useState(false);
  const [isOffline, setIsOffline] = useState(!navigator.onLine);
  const [selectedFilterType, setSelectedFilterType] = useState<PropertyFilterType>('all');
  const [selectedStatus, setSelectedStatus] = useState<PropertyFilterStatus>('all');
  const [isSyncing, setIsSyncing] = useState(false);
  const [bulkActionProgress, setBulkActionProgress] = useState<{active: boolean; current: number; total: number}>({active: false, current: 0, total: 0});
  const headerRef = useRef<HTMLDivElement>(null);
  const [isHeaderSticky, setIsHeaderSticky] = useState(false);
  const [containerWidth, setContainerWidth] = useState<number>(0);
  const containerRef = useRef<HTMLDivElement>(null);
  
  // Drag-to-scroll for filter containers
  const mainFilterScroll = useDragToScroll();
  const subFilterScroll = useDragToScroll();
  
  const { toast } = useToast();
  const [location] = useLocation();
  
  // Use React Query hooks for data fetching
  const { data: properties = [], isLoading, error } = useProperties();
  const { data: transfers = [] } = useTransfers();
  const updateComponents = useUpdatePropertyComponents();
  const createProperty = useCreateProperty();
  
  // Handle URL parameters
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const action = urlParams.get('action');
    
    if (action === 'import-da2062') {
      setShowingDA2062Import(true);
      // Clear the query parameter to avoid reopening on refresh
      const newUrl = window.location.pathname;
      window.history.replaceState({}, '', newUrl);
    }
  }, [location]);
  
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

  // ResizeObserver for responsive behavior
  useLayoutEffect(() => {
    if (!containerRef.current) return;

    const resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        setContainerWidth(entry.contentRect.width);
      }
    });

    resizeObserver.observe(containerRef.current);

    return () => {
      resizeObserver.disconnect();
    };
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
    <div ref={containerRef} className="min-h-screen bg-gradient-to-br from-ios-background via-ios-tertiary-background/30 to-ios-background relative overflow-hidden">
      {/* Decorative gradient orbs */}
      <div className="absolute top-0 left-0 w-96 h-96 bg-gradient-to-br from-blue-500/10 to-indigo-500/10 rounded-full blur-3xl" />
      <div className="absolute bottom-0 right-0 w-96 h-96 bg-gradient-to-br from-purple-500/10 to-pink-500/10 rounded-full blur-3xl" />
      {/* Sticky header for mobile */}
      <div 
        ref={headerRef}
        className={cn(
          "fixed top-0 left-0 right-0 z-40 bg-white/80 backdrop-blur-lg border-b border-ios-divider transition-all duration-300 md:hidden",
          isHeaderSticky ? "opacity-100 translate-y-0 shadow-lg" : "opacity-0 -translate-y-full pointer-events-none"
        )}
      >
        <div className="px-4 py-3">
          <div className="flex items-center justify-between mb-2">
            <h2 className="text-lg font-bold text-ios-primary-text font-mono uppercase tracking-wider">Property Book</h2>
          </div>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-ios-tertiary-text" />
            <Input
              placeholder="Search properties..."
              value={state.searchTerm}
              onChange={(e) => dispatch({ type: 'SET_SEARCH_TERM', payload: e.target.value })}
              className="pl-10 border-0 bg-gradient-to-r from-gray-100 to-gray-50 rounded-lg h-9 text-sm shadow-inner transition-all duration-200 focus:shadow-md"
            />
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-6 py-8 relative z-10">
        {/* Enhanced Header */}
        <div className="mb-12 animate-in fade-in duration-500">
          <div className="flex items-center justify-between mb-8">
            <div className="flex items-center gap-3">
              <div className="p-3 bg-gradient-to-br from-ios-accent to-ios-accent/80 rounded-xl shadow-lg transform hover:scale-105 transition-all duration-300">
                <Package className="h-6 w-6 text-white" />
              </div>
              <div>
                <h1 className="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700">
                  Property Book
                </h1>
                <p className="text-sm font-medium text-ios-secondary-text mt-1">
                  {properties.length} items tracked • {assignedToMe.length} assigned
                </p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              {getCurrentItems().length > 0 && (
                <Button
                  onClick={() => setShowingDA2062Export(true)}
                  variant="ghost"
                  size="sm"
                  className="text-sm font-medium text-ios-accent border border-ios-accent hover:bg-blue-500 hover:border-blue-500 hover:text-white px-4 py-2 uppercase transition-all duration-200 rounded-md hover:scale-105 [&:hover_svg]:text-white"
                >
                  <FileText className="h-4 w-4 mr-1.5" />
                  Generate DA 2062
                </Button>
              )}
            </div>
          </div>
          
          {/* Key Stats Cards */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
            <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl p-6 border border-gray-200/50 shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-[1.02] group">
              <div className="flex items-start justify-between mb-4">
                <div className="p-3 bg-gradient-to-br from-ios-accent/10 to-ios-accent/20 rounded-lg group-hover:scale-110 transition-transform duration-300">
                  <Package className="h-5 w-5 text-ios-accent" />
                </div>
              </div>
              <div>
                <div className="text-3xl font-black text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 mb-1 font-mono">
                  {properties.length}
                </div>
                <h3 className="text-sm font-semibold text-ios-secondary-text">Total Items</h3>
              </div>
            </div>
            
            <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl p-6 border border-gray-200/50 shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-[1.02] group">
              <div className="flex items-start justify-between mb-4">
                <div className="p-3 bg-gradient-to-br from-green-500/10 to-green-500/20 rounded-lg group-hover:scale-110 transition-transform duration-300">
                  <CheckCircle className="h-5 w-5 text-green-500" />
                </div>
              </div>
              <div>
                <div className="text-3xl font-black text-transparent bg-clip-text bg-gradient-to-r from-green-700 to-green-500 mb-1 font-mono">
                  {properties.filter(p => normalizeItemStatus(p.status) === 'operational').length}
                </div>
                <h3 className="text-sm font-semibold text-ios-secondary-text">Operational</h3>
              </div>
            </div>
            
            <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl p-6 border border-gray-200/50 shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-[1.02] group">
              <div className="flex items-start justify-between mb-4">
                <div className="p-3 bg-gradient-to-br from-orange-500/10 to-orange-500/20 rounded-lg group-hover:scale-110 transition-transform duration-300">
                  <Wrench className="h-5 w-5 text-orange-500" />
                </div>
              </div>
              <div>
                <div className="text-3xl font-black text-transparent bg-clip-text bg-gradient-to-r from-orange-700 to-orange-500 mb-1 font-mono">
                  {properties.filter(p => normalizeItemStatus(p.status) === 'maintenance').length}
                </div>
                <h3 className="text-sm font-semibold text-ios-secondary-text">In Maintenance</h3>
              </div>
            </div>
            
            <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl p-6 border border-gray-200/50 shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-[1.02] group">
              <div className="flex items-start justify-between mb-4">
                <div className="p-3 bg-gradient-to-br from-blue-500/10 to-blue-500/20 rounded-lg group-hover:scale-110 transition-transform duration-300">
                  <ArrowLeftRight className="h-5 w-5 text-blue-500" />
                </div>
              </div>
              <div>
                <div className="text-3xl font-black text-transparent bg-clip-text bg-gradient-to-r from-blue-700 to-blue-500 mb-1 font-mono">
                  {transfers.filter(t => t.status === 'pending').length}
                </div>
                <h3 className="text-sm font-semibold text-ios-secondary-text">Pending Transfers</h3>
              </div>
            </div>
          </div>
        </div>
        
        {/* Offline banner with sync status */}
        {isOffline && (
          <div className="mb-4 md:mb-6 bg-gradient-to-r from-orange-50 to-amber-50 rounded-lg p-3 md:p-4 border border-orange-200/50 shadow-md animate-in slide-in-from-top duration-300">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-orange-100 rounded-lg">
                <WifiOff className="h-4 w-4 text-orange-600" />
              </div>
              <div className="flex-1">
                <p className="text-sm font-semibold text-gray-900">Offline Mode</p>
                <p className="text-xs text-gray-600">Changes will sync when connected</p>
              </div>
              {isSyncing && (
                <div className="p-2">
                  <Loader2 className="h-4 w-4 text-orange-600 animate-spin" />
                </div>
              )}
            </div>
          </div>
        )}

        {/* Search and Filter Controls */}
        <div className="mb-0">
          {/* Search Bar with Actions */}
          <div className="flex gap-3 mb-6">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-ios-tertiary-text" />
              <Input
                placeholder="Search by name, serial number, or NSN..."
                value={state.searchTerm}
                onChange={(e) => dispatch({ type: 'SET_SEARCH_TERM', payload: e.target.value })}
                className="pl-10 pr-10 border border-gray-200/50 bg-gradient-to-r from-white to-gray-50 rounded-lg h-11 text-base placeholder:text-gray-400 focus-visible:ring-2 focus-visible:ring-ios-accent shadow-md hover:shadow-lg transition-all duration-200 font-['SF_Pro_Text',_-apple-system,_BlinkMacSystemFont,_sans-serif]"
              />
              {state.searchTerm && (
                <button
                  onClick={() => dispatch({ type: 'SET_SEARCH_TERM', payload: '' })}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 p-1 hover:bg-ios-tertiary-background rounded transition-colors"
                >
                  <X className="h-4 w-4 text-ios-tertiary-text" />
                </button>
              )}
            </div>
            
            {/* Action buttons */}
            <Button
              onClick={() => setShowingSortOptions(true)}
              className="bg-gradient-to-r from-white to-gray-50 hover:from-gray-50 hover:to-gray-100 text-ios-primary-text border border-gray-200/50 rounded-lg px-4 h-11 font-semibold shadow-md hover:shadow-lg transition-all duration-200 hover:scale-105"
            >
              <SlidersHorizontal className="h-4 w-4 mr-2" />
              <span className="hidden md:inline">Filter & Sort</span>
              <span className="md:hidden">Filter</span>
            </Button>
            
            <Button
              onClick={() => setShowingAddMenu(true)}
              className="bg-blue-500 text-white hover:bg-blue-600 rounded-lg px-4 h-11 font-semibold transition-all duration-200 border-0"
            >
              <Plus className="h-4 w-4 mr-2" />
              <span className="hidden md:inline">Add Item</span>
              <span className="md:hidden">Add</span>
            </Button>
          </div>
          
          {/* Section Header */}
          <div className="flex items-center gap-3 mb-4">
            <div className="p-2 bg-gradient-to-br from-blue-500/10 to-blue-500/20 rounded-lg shadow-md">
              <Package className="h-5 w-5 text-blue-500" />
            </div>
            <div>
              <h2 className="text-sm font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 uppercase tracking-wider font-mono">
                ASSIGNED ITEMS
              </h2>
              <p className="text-xs font-medium text-gray-600 mt-0.5">{getCurrentItems().length} items match your filters</p>
            </div>
          </div>
        </div>
        
        {/* Filter tabs and content */}
        <div className="">
          <div className="space-y-3 mb-3">
            {/* Main filter type selector */}
            <div className="w-fit overflow-hidden bg-gradient-to-r from-white to-gray-50 rounded-lg p-1 shadow-md border border-gray-200/50">
              <div 
                ref={mainFilterScroll.scrollRef}
                className={cn(
                  "filter-scroll-container overflow-x-auto scrollbar-hide",
                  mainFilterScroll.isDragging && "cursor-grabbing"
                )}
                style={{ 
                  WebkitOverflowScrolling: 'touch',
                  overflowX: 'auto',
                  overscrollBehavior: 'contain',
                  userSelect: mainFilterScroll.isDragging ? 'none' : 'auto'
                }}
                {...mainFilterScroll.handlers}
              >
                <div className="flex gap-1 w-max">
                  <FilterTypeChip
                    label="ALL ITEMS"
                    active={selectedFilterType === 'all'}
                    onClick={() => {
                      setSelectedFilterType('all');
                      dispatch({ type: 'SET_FILTER_CATEGORY', payload: 'all' });
                      setSelectedStatus('all');
                    }}
                  />
                  <FilterTypeChip
                    label="BY CATEGORY"
                    active={selectedFilterType === 'category'}
                    onClick={() => setSelectedFilterType('category')}
                  />
                  <FilterTypeChip
                    label="BY STATUS"
                    active={selectedFilterType === 'status'}
                    onClick={() => setSelectedFilterType('status')}
                  />
                  <FilterTypeChip
                    label="BY LOCATION"
                    active={selectedFilterType === 'location'}
                    onClick={() => setSelectedFilterType('location')}
                  />
                </div>
              </div>
            </div>

            {/* Sub-filter chips */}
            {(selectedFilterType === 'category' || selectedFilterType === 'status') && (
              <div className="w-fit overflow-hidden rounded-lg p-3">
                <div 
                  ref={subFilterScroll.scrollRef}
                  className={cn(
                    "filter-scroll-container overflow-x-auto scrollbar-hide",
                    subFilterScroll.isDragging && "cursor-grabbing"
                  )}
                  style={{ 
                    WebkitOverflowScrolling: 'touch',
                    overflowX: 'auto',
                    overscrollBehavior: 'contain',
                    userSelect: subFilterScroll.isDragging ? 'none' : 'auto'
                  }}
                  {...subFilterScroll.handlers}
                >
                  <div className="flex gap-2.5 w-max">
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

          {/* Bulk action progress bar */}
        {bulkActionProgress.active && (
          <div className="mb-4 bg-gradient-to-r from-white to-gray-50 rounded-lg p-4 shadow-lg border border-gray-200/50 animate-in slide-in-from-bottom duration-300">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-semibold text-gray-900">Processing items...</span>
              <span className="text-sm font-medium text-gray-600">
                {bulkActionProgress.current} / {bulkActionProgress.total}
              </span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2 overflow-hidden">
              <div 
                className="bg-gradient-to-r from-ios-accent to-ios-accent/80 h-2 rounded-full transition-all duration-500 ease-out"
                style={{ width: `${(bulkActionProgress.current / bulkActionProgress.total) * 100}%` }}
              />
            </div>
          </div>
        )}

        {/* Main content section */}
          <div className="space-y-3">
            {state.isLoading && assignedToMe.length === 0 && !isOffline ? (
              <div className="space-y-4 py-2">
                {/* Skeleton loaders for cards */}
                {[1, 2, 3, 4].map((i) => (
                  <div key={i} className="px-1">
                    <PropertyCardSkeleton />
                  </div>
                ))}
              </div>
            ) : error && assignedToMe.length === 0 ? (
              <div className="bg-gradient-to-br from-red-50 to-orange-50 rounded-xl p-16 text-center shadow-lg border border-red-200/50">
                <div className="p-4 bg-red-100 rounded-full w-16 h-16 mx-auto mb-4 flex items-center justify-center">
                  <AlertTriangle className="h-8 w-8 text-red-600" />
                </div>
                <p className="text-red-700 font-semibold mb-2">Error loading properties</p>
                <p className="text-red-600 text-sm">{error?.message || "Please try again later"}</p>
                <Button
                  onClick={() => window.location.reload()}
                  variant="outline"
                  size="sm"
                  className="mt-4 border-red-300 hover:bg-red-50 text-red-700"
                >
                  Retry
                </Button>
              </div>
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
                    className="bg-blue-500 hover:bg-blue-600 text-white border-0"
                  >
                    Add Property
                  </Button>
                )
              }
            />
          ) : (
            <div className="h-[calc(100vh-300px)] min-h-[400px]">
              <VirtualPropertyList
                properties={currentItems}
                onPropertyClick={(property) => {
                  handleViewDetails(property);
                }}
                onTransfer={(property) => {
                  setSelectedItem(property);
                  setTransferModalOpen(true);
                }}
              />
            </div>
          )}
          </div>
        </div>
      </div>


      {/* Modals */}
      {selectedItem && (
        <TransferRequestModal
          isOpen={transferModalOpen}
          onClose={() => setTransferModalOpen(false)}
          item={selectedItem}
        />
      )}

      <Dialog open={detailsModalOpen} onOpenChange={setDetailsModalOpen}>
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-hidden flex flex-col bg-gradient-to-b from-white to-gray-50/50 backdrop-blur-xl shadow-2xl border border-gray-200/50">
          <DialogHeader className="border-b border-ios-divider pb-5">
            <div className="flex items-start gap-4">
              <div className={cn(
                "p-3 rounded-xl flex-shrink-0 shadow-md transition-all duration-300 hover:scale-110",
                selectedItem && getCategoryFromName(selectedItem.name) !== 'other' 
                  ? getCategoryColor(selectedItem.name).replace('text-', 'bg-').replace('500', '500/10')
                  : 'bg-gradient-to-br from-gray-100 to-gray-200'
              )}>
                {selectedItem && getCategoryFromName(selectedItem.name) !== 'other' ? (
                  <span className={cn("text-2xl", getCategoryColor(selectedItem.name))}>
                    {getCategoryIcon(selectedItem.name)}
                  </span>
                ) : (
                  <Package className="h-6 w-6 text-ios-secondary-text" />
                )}
              </div>
              <div className="flex-1">
                <DialogTitle className="text-2xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 mb-2">
                  {selectedItem?.name}
                </DialogTitle>
                <div className="flex flex-wrap items-center gap-3 text-sm">
                  <span className="flex items-center gap-1.5 text-ios-secondary-text">
                    <FileText className="h-4 w-4" />
                    <span className="font-mono">SN: {selectedItem?.serialNumber}</span>
                  </span>
                  {selectedItem?.nsn && (
                    <span className="flex items-center gap-1.5 text-ios-secondary-text">
                      <Package className="h-4 w-4" />
                      <span className="font-mono">NSN: {selectedItem?.nsn}</span>
                    </span>
                  )}
                  {selectedItem?.lin && (
                    <span className="flex items-center gap-1.5 text-ios-secondary-text">
                      <Shield className="h-4 w-4" />
                      <span className="font-mono">LIN: {selectedItem?.lin}</span>
                    </span>
                  )}
                </div>
              </div>
              {selectedItem?.isSensitive && (
                <div className="p-2 bg-orange-500/10 rounded-lg">
                  <Shield className="h-5 w-5 text-orange-500" />
                </div>
              )}
            </div>
          </DialogHeader>
          
          <div className="flex-1 overflow-y-auto px-1">
            <div className="p-6 space-y-6">
              {/* Key Information Grid */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Category & Location Card */}
                <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl p-5 shadow-lg border border-gray-200/50 hover:shadow-xl transition-all duration-300">
                  <div className="flex items-center gap-3 mb-3">
                    <div className="p-2 bg-gradient-to-br from-blue-500/10 to-blue-500/20 rounded-lg">
                      <Info className="h-4 w-4 text-blue-500" />
                    </div>
                    <h3 className="text-xs font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 uppercase tracking-wider font-mono">
                      CLASSIFICATION
                    </h3>
                  </div>
                  <div className="space-y-3">
                    <div>
                      <p className="text-xs text-ios-tertiary-text uppercase tracking-wider mb-1">Category</p>
                      <p className="text-sm font-medium text-ios-primary-text capitalize">
                        {selectedItem?.category || 'Other'}
                      </p>
                    </div>
                    {selectedItem?.location && (
                      <div>
                        <p className="text-xs text-ios-tertiary-text uppercase tracking-wider mb-1">Location</p>
                        <p className="text-sm font-medium text-ios-primary-text">
                          {selectedItem.location}
                        </p>
                      </div>
                    )}
                  </div>
                </div>
                
                {/* Assignment Info Card */}
                <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl p-5 shadow-lg border border-gray-200/50 hover:shadow-xl transition-all duration-300">
                  <div className="flex items-center gap-3 mb-3">
                    <div className="p-2 bg-gradient-to-br from-purple-500/10 to-purple-500/20 rounded-lg">
                      <Calendar className="h-4 w-4 text-purple-500" />
                    </div>
                    <h3 className="text-xs font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 uppercase tracking-wider font-mono">
                      ASSIGNMENT INFO
                    </h3>
                  </div>
                  <div className="space-y-3">
                    <div>
                      <p className="text-xs text-gray-500 uppercase tracking-wider mb-1 font-semibold">Assigned Date</p>
                      <p className="text-sm font-bold text-ios-primary-text font-mono">
                        {selectedItem?.assignedDate ? 
                          (() => {
                            const date = new Date(selectedItem.assignedDate);
                            const day = date.getDate().toString().padStart(2, '0');
                            const month = date.toLocaleDateString('en-US', { month: 'short' }).toUpperCase();
                            const year = date.getFullYear();
                            return `${day}${month}${year}`;
                          })()
                          : 'UNKNOWN'
                        }
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              
              {/* Transfer History */}
              <div className="bg-gradient-to-r from-ios-accent/10 to-ios-accent/5 rounded-xl p-5 border border-ios-accent/20 shadow-lg hover:shadow-xl transition-all duration-300">
                <div className="flex items-center gap-3 mb-4">
                  <div className="p-2 bg-gradient-to-br from-white to-gray-50 rounded-lg shadow-md">
                    <ArrowLeftRight className="h-4 w-4 text-ios-accent" />
                  </div>
                  <h3 className="text-xs font-semibold text-ios-primary-text uppercase tracking-wider font-mono">
                    TRANSFER HISTORY
                  </h3>
                </div>
                <div className="space-y-3">
                  {/* Mock transfer history - replace with actual data */}
                  {[
                    { from: 'SGT JOHNSON', to: 'CPT SMITH', date: '2024-12-15T14:30:00', status: 'completed' },
                    { from: 'PVT WILLIAMS', to: 'SGT JOHNSON', date: '2024-10-20T09:15:00', status: 'completed' },
                    { from: 'SUPPLY', to: 'PVT WILLIAMS', date: '2024-08-05T11:00:00', status: 'completed' }
                  ].map((transfer, index) => (
                    <div key={index} className="flex items-start gap-3 pb-3 border-b border-ios-divider last:border-0 last:pb-0">
                      <div className="p-1.5 bg-gradient-to-br from-ios-accent/10 to-ios-accent/20 rounded-full mt-0.5 hover:scale-110 transition-transform duration-200">
                        <CheckCircle className="h-3 w-3 text-ios-accent" />
                      </div>
                      <div className="flex-1">
                        <div className="flex items-center justify-between mb-1">
                          <p className="text-sm font-medium text-ios-primary-text">
                            {transfer.from} → {transfer.to}
                          </p>
                          <span className="text-xs text-green-500 font-medium uppercase">Completed</span>
                        </div>
                        <p className="text-xs text-ios-tertiary-text font-mono">
                          {(() => {
                            const date = new Date(transfer.date);
                            const day = date.getDate().toString().padStart(2, '0');
                            const month = date.toLocaleDateString('en-US', { month: 'short' }).toUpperCase();
                            const year = date.getFullYear();
                            const time = date.toLocaleTimeString('en-US', { 
                              hour: '2-digit', 
                              minute: '2-digit',
                              hour12: false 
                            });
                            return `${day}${month}${year} ${time}`;
                          })()}
                        </p>
                      </div>
                    </div>
                  ))}
                  {/* If no transfer history */}
                  {false && (
                    <p className="text-sm text-ios-tertiary-text text-center py-4">
                      No transfer history available
                    </p>
                  )}
                </div>
              </div>
              
              {/* Description if available */}
              {selectedItem?.description && (
                <div className="bg-white rounded-xl p-5 shadow-sm border border-ios-border">
                  <div className="flex items-center gap-3 mb-3">
                    <div className="p-2 bg-purple-500/10 rounded-lg">
                      <FileText className="h-4 w-4 text-purple-500" />
                    </div>
                    <h3 className="text-xs font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 uppercase tracking-wider font-mono">
                      DESCRIPTION
                    </h3>
                  </div>
                  <p className="text-sm text-ios-secondary-text leading-relaxed">
                    {selectedItem.description}
                  </p>
                </div>
              )}
              
              {/* Components section */}
              {selectedItem?.components && selectedItem.components.length > 0 && (
                <div className="bg-white rounded-xl p-5 shadow-sm border border-ios-border">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 bg-orange-500/10 rounded-lg">
                      <Package className="h-4 w-4 text-orange-500" />
                    </div>
                    <h3 className="text-xs font-bold text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700 uppercase tracking-wider font-mono">
                      COMPONENTS ({selectedItem.components.length})
                    </h3>
                  </div>
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
          </div>
          
          <DialogFooter className="border-t border-ios-divider pt-4 px-6 pb-6">
            <Button
              onClick={() => {
                setDetailsModalOpen(false);
                if (selectedItem) handleTransferRequest(selectedItem);
              }}
              className="bg-ios-accent hover:bg-ios-accent/90 text-white font-medium shadow-sm transition-all duration-200 border-0"
            >
              <ArrowLeftRight className="h-4 w-4 mr-2" />
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

      
      {/* DA 2062 Export Dialog */}
      <DA2062ExportDialog
        isOpen={showingDA2062Export}
        onClose={() => {
          setShowingDA2062Export(false);
        }}
        selectedProperties={getCurrentItems()}
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
        <DialogContent className="max-w-sm bg-gradient-to-b from-white to-gray-50 backdrop-blur-xl shadow-2xl border border-gray-200/50">
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
        <DialogContent className="max-w-sm bg-gradient-to-b from-white to-gray-50 backdrop-blur-xl shadow-2xl border border-gray-200/50">
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

// Enhanced Filter Type Chip Component
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
        "px-5 py-2.5 text-xs font-bold rounded-lg whitespace-nowrap transition-all duration-300 uppercase tracking-wider font-mono",
        active
          ? "bg-blue-500 text-white"
          : "bg-transparent text-gray-600 hover:bg-gray-100 hover:text-gray-900"
      )}
    >
      {label}
    </button>
  );
};

// Enhanced Filter Chip Component
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
        "px-5 py-2.5 text-xs font-bold rounded-lg whitespace-nowrap transition-all duration-300 uppercase tracking-wider font-mono",
        active
          ? "bg-blue-500 text-white"
          : "bg-white text-gray-600 border border-gray-200/50 hover:text-gray-900"
      )}
    >
      {label}
    </button>
  );
};

// Enhanced Property Card Skeleton Component
const PropertyCardSkeleton: React.FC = () => {
  return (
    <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl shadow-lg border border-gray-200/50 overflow-hidden">
      <div className="p-6">
        <div className="space-y-5">
          {/* Header skeleton */}
          <div className="flex items-start justify-between">
            <div className="flex-1 space-y-3">
              <Skeleton className="h-6 w-3/4 bg-gradient-to-r from-gray-200 to-gray-100 animate-pulse" />
              <Skeleton className="h-4 w-1/2 bg-gradient-to-r from-gray-200 to-gray-100 animate-pulse" />
              <Skeleton className="h-3 w-1/3 bg-gradient-to-r from-gray-200 to-gray-100 animate-pulse" />
            </div>
            <Skeleton className="h-10 w-10 rounded-lg bg-gradient-to-r from-gray-200 to-gray-100 animate-pulse" />
          </div>
          
          {/* Status skeleton */}
          <div className="flex items-center justify-between">
            <Skeleton className="h-6 w-24 rounded-full bg-gradient-to-r from-gray-200 to-gray-100 animate-pulse" />
            <div className="space-y-1">
              <Skeleton className="h-3 w-16 ml-auto bg-gradient-to-r from-gray-200 to-gray-100 animate-pulse" />
              <Skeleton className="h-3 w-20 bg-gradient-to-r from-gray-200 to-gray-100 animate-pulse" />
            </div>
          </div>
          
          {/* Action skeleton */}
          <div className="pt-3 border-t border-gray-200/50">
            <Skeleton className="h-4 w-20 ml-auto bg-gradient-to-r from-gray-200 to-gray-100 animate-pulse" />
          </div>
        </div>
      </div>
    </div>
  );
};

export default PropertyBook;