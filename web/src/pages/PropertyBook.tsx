import { useState, useEffect, useMemo, useReducer, useCallback } from"react";
import { useProperties, useOfflineSync, useUpdatePropertyComponents, useCreateProperty } from"@/hooks/useProperty";
import { useTransfers } from"@/hooks/useTransfers";
import { Property, Transfer, Component } from"@/types";
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
import { Search, Filter, ArrowDownUp, ArrowLeftRight, Info, ClipboardCheck, Calendar, ShieldCheck, Send, CheckCircle, Package, Shield, Radio, Eye, Wrench, SearchX, ArrowUpDown, ChevronDown, ChevronRight, Plus, Download, FileText, WifiOff, X
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
import { DA2062ExportDialog } from"@/components/da2062/DA2062ExportDialog"; interface PropertyBookProps { 
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
  const [isSelectMode, setIsSelectMode] = useState(false);
  const [selectedPropertiesForExport, setSelectedPropertiesForExport] = useState<Set<number>>(new Set());
  const [showingSortOptions, setShowingSortOptions] = useState(false);
  const [showingAddMenu, setShowingAddMenu] = useState(false);
  const [isOffline, setIsOffline] = useState(!navigator.onLine);
  
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

  // Filter items based on search and category
  const getFilteredItems = useCallback((items: any[], tab: string) => {
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
      
      const category = item.category && categoryOptions.some(opt => opt.value === item.category) 
        ? item.category 
        : getCategoryFromName(item.name);
      const matchesCategory = state.filterCategory === "all" || category === state.filterCategory;
      
      return matchesSearch && matchesCategory;
    });
  }, [state.searchTerm, state.filterCategory]);

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

  // Handler for bulk actions
  const handleBulkAction = useCallback((action: string) => {
    console.log(`Bulk action triggered: ${action}`, {
      selectedIds: Array.from(state.selectedItemIds)
    });
    toast({
      title: `Bulk Action: ${action}`,
      description: `Triggered for ${state.selectedItemIds.size} items. (Implementation Pending)`,
    });
    // Clear selections after bulk action
    dispatch({ type: 'CLEAR_SELECTIONS' });
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
    } catch (error: any) {
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
      
      let itemToSelect: any = null;
      
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
      <div className="max-w-4xl mx-auto px-6 py-8">
        {/* Header - iOS style */}
        <div className="mb-10">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between mb-6">
            <div></div>
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
          <div className="border-b border-ios-divider mb-6" />
          
          {/* Title section */}
          <div className="mb-8">
            <h1 className="text-5xl font-bold text-primary-text leading-tight" style={{ fontFamily: 'ui-serif, Georgia, serif' }}>
              Property Book
            </h1>
            <p className="text-secondary-text mt-2">
              {properties.length} items tracked
            </p>
          </div>
        </div>
        
        {/* Offline banner */}
        {isOffline && (
          <div className="mb-6 bg-ios-warning/10 rounded-lg p-4 border border-ios-warning/20">
            <div className="flex items-center gap-3">
              <WifiOff className="h-4 w-4 text-ios-warning" />
              <div className="flex-1">
                <p className="text-sm font-medium text-primary-text">Offline Mode</p>
                <p className="text-xs text-secondary-text">Changes will sync when connected</p>
              </div>
            </div>
          </div>
        )}

        {/* Search and Filter Controls */}
        <div className="mb-6 space-y-4">
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
          
          {/* Action buttons row */}
          <div className="flex gap-3">
            {/* Filter/Sort button */}
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowingSortOptions(true)}
              className="border-ios-border text-secondary-text hover:text-primary-text"
            >
              <Filter className="h-4 w-4 mr-2" />
              Sort
            </Button>
            
            {/* Add button */}
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowingAddMenu(true)}
              className="border-ios-border text-secondary-text hover:text-primary-text"
            >
              <Plus className="h-4 w-4 mr-2" />
              Add
            </Button>
          </div>
          
          {/* Filter chips */}
          <div className="flex gap-2 overflow-x-auto pb-2">
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
          </div>
        </div>

        {/* Main content */}
        <div className="space-y-3">

          {state.isLoading && assignedToMe.length === 0 && !isOffline ? (
            <CleanCard className="py-16">
              <MinimalLoadingView text="Loading properties..." />
            </CleanCard>
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
                <PropertyCard
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
                // Import from DA-2062 logic
                toast({
                  title: "Import from DA-2062",
                  description: "This feature is coming soon.",
                });
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
        "px-3 py-1.5 text-xs font-medium rounded-full whitespace-nowrap transition-colors uppercase tracking-wider",
        active
          ? "bg-ios-accent text-white"
          : "bg-ios-background text-tertiary-text hover:bg-ios-border/20"
      )}
    >
      {label}
    </button>
  );
};

// Property Card Component
interface PropertyCardProps {
  property: Property;
  isSelected: boolean;
  isSelectMode: boolean;
  onTap: () => void;
  onTransfer: () => void;
}

const PropertyCard: React.FC<PropertyCardProps> = ({ 
  property, 
  isSelected, 
  isSelectMode, 
  onTap,
  onTransfer 
}) => {
  const [isPressed, setIsPressed] = useState(false);
  const category = getCategoryFromName(property.name);
  const categoryIcon = getCategoryIcon(property.name);
  const needsVerification = !property.verified;
  const lastInventoryDate = property.lastInventoryDate;
  
  const getStatusColor = (status: string) => {
    const normalizedStatus = normalizeItemStatus(status);
    switch (normalizedStatus) {
      case 'Operational': return 'text-ios-success';
      case 'Maintenance': 
      case 'Non-Operational': return 'text-ios-warning';
      case 'Missing': return 'text-ios-destructive';
      default: return 'text-secondary-text';
    }
  };
  
  const getVerificationDateColor = (date: string | null) => {
    if (!date) return 'text-tertiary-text';
    const daysSince = Math.floor((Date.now() - new Date(date).getTime()) / (1000 * 60 * 60 * 24));
    if (daysSince > 90) return 'text-ios-destructive';
    if (daysSince > 30) return 'text-ios-warning';
    return 'text-secondary-text';
  };
  
  return (
    <div
      className={`transition-transform duration-150 ${isPressed ? 'scale-[0.98]' : 'scale-100'}`}
      onMouseDown={() => setIsPressed(true)}
      onMouseUp={() => setIsPressed(false)}
      onMouseLeave={() => setIsPressed(false)}
    >
      <CleanCard 
        className={cn(
          "cursor-pointer hover:shadow-md transition-shadow duration-200 overflow-hidden",
          isSelected && "ring-2 ring-ios-accent"
        )}
        onClick={onTap}
        padding="none"
      >
        <div className="p-6">
          <div className="space-y-5">
            {/* Property header with serif font */}
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-2">
                  {isSelectMode && (
                    <div className={cn(
                      "w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors flex-shrink-0",
                      isSelected ? "bg-ios-accent border-ios-accent" : "border-ios-border"
                    )}>
                      {isSelected && (
                        <svg className="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                      )}
                    </div>
                  )}
                  <h3 className="text-lg font-medium text-primary-text" style={{ fontFamily: 'ui-serif, Georgia, serif' }}>
                    {property.name}
                  </h3>
                  {property.isSensitive && (
                    <Shield className="h-4 w-4 text-ios-warning" />
                  )}
                  {needsVerification && (
                    <Info className="h-4 w-4 text-ios-destructive" />
                  )}
                </div>
                <p className="text-sm text-secondary-text font-mono">
                  SN: {property.serialNumber}
                </p>
                {property.nsn && (
                  <p className="text-xs text-tertiary-text font-mono mt-1">
                    NSN: {property.nsn}
                  </p>
                )}
              </div>
              
              {/* Category icon */}
              {category !== 'other' && (
                <span className={cn("text-2xl", getCategoryColor(property.name))}>
                  {categoryIcon}
                </span>
              )}
            </div>
            
            {/* Status and verification info */}
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <span className={cn("text-xs uppercase tracking-wide font-medium", getStatusColor(property.status || 'Unknown'))}>
                  {property.status || 'Unknown'}
                </span>
              </div>
              
              {lastInventoryDate && (
                <div className="text-right">
                  <p className="text-xs text-tertiary-text">Last verified</p>
                  <p className={cn("text-xs font-medium", getVerificationDateColor(lastInventoryDate))}>
                    {new Date(lastInventoryDate).toLocaleDateString()}
                  </p>
                </div>
              )}
            </div>
            
            {/* Action buttons for non-select mode */}
            {!isSelectMode && (
              <div className="pt-3 border-t border-ios-divider flex justify-end">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={(e) => {
                    e.stopPropagation();
                    onTransfer();
                  }}
                  className="text-ios-accent hover:bg-transparent px-0 text-sm font-medium"
                >
                  Transfer
                </Button>
              </div>
            )}
          </div>
        </div>
      </CleanCard>
    </div>
  );
};

export default PropertyBook;