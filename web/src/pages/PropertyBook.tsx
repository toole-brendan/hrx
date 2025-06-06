import { useState, useEffect, useMemo, useReducer, useCallback } from "react";
import { useProperties, useOfflineSync, useUpdatePropertyComponents, useCreateProperty } from "@/hooks/useProperty";
import { useTransfers } from "@/hooks/useTransfers";
import { Property, Transfer, Component } from "@/types";
import { v4 as uuidv4 } from 'uuid';
import { 
  Card, 
  CardContent, 
  CardHeader, 
  CardTitle, 
  CardDescription 
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { 
  Select, 
  SelectContent, 
  SelectItem, 
  SelectTrigger, 
  SelectValue 
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { useToast } from "@/hooks/use-toast";
import { PageHeader } from "@/components/ui/page-header";
import { PageWrapper } from "@/components/ui/page-wrapper";
import TransferRequestModal from "@/components/modals/TransferRequestModal";
import ComponentList from "@/components/property/ComponentList";
import PropertyBookTable, { DisplayItem } from "@/components/property/PropertyBookTable";
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
  Plus
} from "lucide-react";
import { Checkbox } from "@/components/ui/checkbox";
import BulkActionMenu from "@/components/shared/BulkActionMenu";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { propertyBookReducer, initialState } from "@/lib/propertyBookReducer";
import { 
  categoryOptions, 
  getCategoryFromName, 
  getCategoryColor, 
  getCategoryIcon,
  normalizeItemStatus 
} from "@/lib/propertyUtils";
import CreatePropertyDialog from "@/components/property/CreatePropertyDialog";
import { SendMaintenanceForm } from "@/components/property/SendMaintenanceForm";

interface PropertyBookProps {
  id?: string;
}

// Status Badge Component - Styled consistently with design guide
const StatusBadge = ({ status }: { status: string }) => {
  // Style mapping for each status type - Updated to align with military terminology
  const statusStyles: Record<string, { textColor: string; borderColor: string; bgColor: string; label: string }> = {
    "Operational": { 
      textColor: "text-green-700 dark:text-green-400",
      borderColor: "border-green-600 dark:border-green-500",
      bgColor: "bg-green-100/70 dark:bg-transparent",
      label: "OPERATIONAL"
    },
    "Deadline - Maintenance": { 
      textColor: "text-red-700 dark:text-red-400",
      borderColor: "border-red-600 dark:border-red-500",
      bgColor: "bg-red-100/70 dark:bg-transparent",
      label: "DEADLINE - MAINT"
    },
    "Deadline - Supply": { 
      textColor: "text-yellow-700 dark:text-yellow-400", 
      borderColor: "border-yellow-600 dark:border-yellow-500",
      bgColor: "bg-yellow-100/70 dark:bg-transparent",
      label: "DEADLINE - SUPPLY"
    },
    "Lost": { 
      textColor: "text-gray-700 dark:text-gray-400",
      borderColor: "border-gray-600 dark:border-gray-500",
      bgColor: "bg-gray-100/70 dark:bg-transparent",
      label: "LOST"
    },
    // Legacy status mappings for backward compatibility
    "Non-Operational": { 
      textColor: "text-red-700 dark:text-red-400",
      borderColor: "border-red-600 dark:border-red-500",
      bgColor: "bg-red-100/70 dark:bg-transparent",
      label: "DEADLINE - MAINT" // Map to new terminology
    },
    "Damaged": { 
      textColor: "text-red-700 dark:text-red-400",
      borderColor: "border-red-600 dark:border-red-500",
      bgColor: "bg-red-100/70 dark:bg-transparent",
      label: "DEADLINE - MAINT" // Map to new terminology
    },
    "In Repair": { 
      textColor: "text-red-700 dark:text-red-400",
      borderColor: "border-red-600 dark:border-red-500",
      bgColor: "bg-red-100/70 dark:bg-transparent",
      label: "DEADLINE - MAINT" // Map to new terminology
    }
  };

  // Default to Operational if status doesn't exist in our mapping
  const style = statusStyles[status] || statusStyles['Operational'];
  
  return (
    <Badge className={`uppercase ${style.bgColor} ${style.textColor} border ${style.borderColor} text-[10px] tracking-wider font-medium px-2 py-0.5 rounded-none`}>
      {style.label}
    </Badge>
  );
};

const PropertyBook: React.FC<PropertyBookProps> = ({ id }) => {
  // Use reducer for most state management
  const [state, dispatch] = useReducer(propertyBookReducer, initialState);
  
  // State that remains outside the reducer
  const [selectedItem, setSelectedItem] = useState<Property | null>(null);
  const [transferModalOpen, setTransferModalOpen] = useState(false);
  const [detailsModalOpen, setDetailsModalOpen] = useState(false);
  const [createItemModalOpen, setCreateItemModalOpen] = useState(false);
  const [maintenanceFormModalOpen, setMaintenanceFormModalOpen] = useState(false);
  
  const { toast } = useToast();
  
  // Use React Query hooks for data fetching
  const { data: properties = [], isLoading, error } = useProperties();
  const { data: transfers = [] } = useTransfers();
  const updateComponents = useUpdatePropertyComponents();
  const createProperty = useCreateProperty();
  
  // Setup offline sync
  useOfflineSync();

  // Update loading and error states
  useEffect(() => {
    dispatch({ type: 'SET_LOADING', payload: isLoading });
    dispatch({ type: 'SET_ERROR', payload: error?.message || null });
  }, [isLoading, error]);

  // Create memoized data for assigned items
  const assignedToMe: DisplayItem[] = useMemo(() => {
    // Map existing properties to ensure categories are using the new system
    return properties.map(item => ({
      ...item,
      // Derive category from name if not already set or using old system
      category: getCategoryFromName(item.name)
    }));
  }, [properties]);
  
  // Create memoized data for signed-out items based on transfers
  const signedOutItems: DisplayItem[] = useMemo(() => {
    return transfers
      .filter(transfer => transfer.status === "approved") // Assuming approved means signed out
      .map(transfer => {
        const originalItem = properties.find(i => i.serialNumber === transfer.serialNumber);
        const derivedCategory = getCategoryFromName(transfer.name);
        
        return {
          ...(originalItem || {}), // Spread original item data if found
          id: originalItem?.id || transfer.id, // Use original ID if available
          name: transfer.name,
          serialNumber: transfer.serialNumber,
          status: originalItem?.status || "Operational", // Use original status or default
          description: originalItem?.description || "Transferred",
          category: derivedCategory, // Use our new category system 
          location: "Transferred", // Indicate location change
          assignedTo: transfer.to, // Person/Unit it's signed to
          transferDate: transfer.date, // Date of transfer
          assignedDate: originalItem?.assignedDate || transfer.date, // Original assignment date or transfer date
          components: originalItem?.components || [], // Keep components info
          isComponent: originalItem?.isComponent || false,
          parentItemId: originalItem?.parentItemId,
        }
      });
  }, [properties, transfers]);

  // Filter items based on search and category
  const getFilteredItems = useCallback((items: DisplayItem[], tab: string): DisplayItem[] => {
    return items.filter(item => {
      const name = item.name || '';
      const serialNumber = item.serialNumber || '';
      const assignedTo = (tab === "signedout" && item.assignedTo) ? item.assignedTo.toLowerCase() : '';
      const searchTermLower = state.searchTerm.toLowerCase();

      const matchesSearch = 
        name.toLowerCase().includes(searchTermLower) ||
        serialNumber.toLowerCase().includes(searchTermLower) ||
        (tab === "signedout" && assignedTo.includes(searchTermLower));
      
      // Use either the item's category if it matches our system, or derive it from the name
      const category = item.category && categoryOptions.some(opt => opt.value === item.category) 
        ? item.category 
        : getCategoryFromName(item.name);
        
      const matchesCategory = state.filterCategory === "all" || category === state.filterCategory;

      return matchesSearch && matchesCategory;
    });
  }, [state.searchTerm, state.filterCategory]);

  // Sort filtered items if a sort config is active
  const getSortedItems = useCallback((items: DisplayItem[]): DisplayItem[] => {
    if (!state.sortConfig || !state.sortConfig.key) return items;
    
    const { key, direction } = state.sortConfig;
    const sortedItems = [...items].sort((a, b) => {
      const aValue = a[key as keyof DisplayItem];
      const bValue = b[key as keyof DisplayItem];
      
      // Handle string and date comparisons
      if (typeof aValue === 'string' && typeof bValue === 'string') {
        const comparison = aValue.localeCompare(bValue);
        return direction === 'ascending' ? comparison : -comparison;
      }
      
      // Handle numeric comparisons
      if (typeof aValue === 'number' && typeof bValue === 'number') {
        return direction === 'ascending' ? aValue - bValue : bValue - aValue;
      }
      
      // Default - return 0 if we can't compare
      return 0;
    });
    
    return sortedItems;
  }, [state.sortConfig]);

  // Get items for the current tab, filtered and sorted
  const getCurrentItems = useCallback((): DisplayItem[] => {
    const itemsForTab = state.activeTab === 'assigned' ? assignedToMe : signedOutItems;
    const filteredItems = getFilteredItems(itemsForTab, state.activeTab);
    return getSortedItems(filteredItems);
  }, [assignedToMe, signedOutItems, state.activeTab, getFilteredItems, getSortedItems]);

  // Handler for item transfer requests
  const handleTransferRequest = useCallback((item: Property) => {
    setSelectedItem(item);
    setTransferModalOpen(true);
  }, []);

  // Handler for viewing item details
  const handleViewDetails = useCallback((item: Property) => {
    // Normalize status to new format when viewing details
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
    
    const newComponent: Component = { ...newComponentData, id: uuidv4() };
    const updatedComponents = [...(selectedItem.components || []), newComponent];
    
    updateComponents.mutate(
      { id: selectedItem.id, components: updatedComponents },
      {
        onSuccess: (updatedItem) => {
          toast({ title: "Component Added", description: `${newComponent.name} added.` });
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
          toast({ title: "Component Updated", description: `${updatedComponent.name} updated.` });
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

  // Handler for sorting
  const handleRequestSort = useCallback((key: string) => {
    // If already sorting by this key, toggle direction
    if (state.sortConfig?.key === key) {
      if (state.sortConfig.direction === 'ascending') {
        dispatch({ type: 'SET_SORT', payload: { key, direction: 'descending' } });
      } else {
        dispatch({ type: 'CLEAR_SORT' });
      }
    } else {
      // Start sorting by this key in ascending order
      dispatch({ type: 'SET_SORT', payload: { key, direction: 'ascending' } });
    }
    
    toast({ 
      title: "Sorting", 
      description: `Sorting by ${key}` 
    });
  }, [state.sortConfig, toast]);

  // Handlers for table component
  const handleItemSelect = useCallback((itemId: string) => {
    dispatch({ type: 'TOGGLE_ITEM_SELECTION', payload: itemId });
  }, []);

  const handleToggleExpand = useCallback((itemId: string) => {
    console.log('Toggle expand for item:', itemId);
    console.log('Current expanded items before toggle:', Array.from(state.expandedItemIds));
    
    // Find the item to check it has components
    const itemToExpand = [...assignedToMe, ...signedOutItems].find(item => item.id === itemId);
    console.log('Item being toggled:', itemToExpand);
    
    dispatch({ type: 'TOGGLE_EXPAND_ITEM', payload: itemId });
    
    // Log state after toggle to confirm it changed (will show on next render)
    setTimeout(() => {
      console.log('Expanded items after toggle:', Array.from(state.expandedItemIds));
    }, 0);
  }, [state.expandedItemIds, assignedToMe, signedOutItems]);

  const handleSelectAll = useCallback((checked: boolean) => {
    const currentItems = getCurrentItems();
    dispatch({ 
      type: 'TOGGLE_SELECT_ALL', 
      payload: { 
        itemIds: currentItems.map(item => item.id), 
        selected: checked 
      } 
    });
  }, [getCurrentItems]);

  const handleTabChange = useCallback((value: string) => {
    dispatch({ type: 'SET_ACTIVE_TAB', payload: value as 'assigned' | 'signedout' });
  }, []);

  // Effect for handling direct navigation to an item via id prop
  useEffect(() => {
    if (!state.isLoading && id) {
      const assignedItem = properties.find(item => item.id === id);
      const signedOutItemDetails = signedOutItems.find(item => item.id === id); 
      
      let itemToSelect: DisplayItem | null = null;
      if (assignedItem) { itemToSelect = assignedItem; } 
      else if (signedOutItemDetails) { itemToSelect = signedOutItemDetails; }

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
      if (error.message?.includes('duplicate') || error.message?.includes('unique')) {
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
      throw error; // Re-throw to let the dialog handle loading state
    }
  }, [createProperty, toast]);

  // UI components and layout
  const actions = (
    <div className="flex items-center gap-2">
      <Button 
        size="sm" 
        variant="blue"
        className="h-9 px-3 flex items-center gap-1.5"
        onClick={() => setCreateItemModalOpen(true)}
      >
        <Plus className="h-4 w-4" />
        <span className="text-xs uppercase tracking-wider">Create Item</span>
      </Button>
    </div>
  );

  // Get current items for display
  const currentItems = getCurrentItems();
  const allFilteredInTabSelected = currentItems.length > 0 && 
                               currentItems.every(item => state.selectedItemIds.has(item.id));
  const isIndeterminate = currentItems.some(item => state.selectedItemIds.has(item.id)) && 
                      !allFilteredInTabSelected;

  return (
    <PageWrapper withPadding={true}>
      <div className="pt-16 pb-10">
        <div className="text-xs uppercase tracking-wider font-medium mb-1 text-muted-foreground">
          EQUIPMENT
        </div>
        
        <div className="flex flex-col sm:flex-row sm:items-center justify-between space-y-4 sm:space-y-0">
          <div>
            <h1 className="text-3xl font-light tracking-tight mb-1">Property Book</h1>
            <p className="text-sm text-muted-foreground max-w-xl">
              View your assigned equipment and items signed down to others
            </p>
          </div>
          {actions}
        </div>
      </div>
      
      {state.selectedItemIds.size > 0 && (
        <div className="mb-6">
          <BulkActionMenu 
            selectedItemCount={state.selectedItemIds.size} 
            onActionTriggered={handleBulkAction} 
          />
        </div>
      )}

      <Tabs 
        defaultValue="assigned" 
        value={state.activeTab} 
        onValueChange={handleTabChange} 
        className="w-full mb-6"
      >
        <TabsList className="grid grid-cols-2 h-10 border rounded-none">
          <TabsTrigger value="assigned" className="text-xs uppercase tracking-wider rounded-none">
            Assigned to Me
          </TabsTrigger>
          <TabsTrigger value="signedout" className="text-xs uppercase tracking-wider rounded-none">
            Signed Down to Others
          </TabsTrigger>
        </TabsList>
      </Tabs>

      <Card className="mb-8 border-border shadow-none bg-card">
        <CardContent className="p-4 flex flex-col md:flex-row items-center gap-4">
          <div className="flex-grow w-full md:w-auto">
            <div className="relative">
              <Search className="absolute left-2.5 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder={`Search ${state.activeTab === 'assigned' ? 'assigned items' : 'signed out items'}...`}
                value={state.searchTerm}
                onChange={(e) => dispatch({ type: 'SET_SEARCH_TERM', payload: e.target.value })}
                className="pl-8 w-full"
              />
            </div>
          </div>
          <div className="w-full md:w-64">
            <Select 
              value={state.filterCategory} 
              onValueChange={(value) => dispatch({ type: 'SET_FILTER_CATEGORY', payload: value })}
            >
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Filter by category" />
              </SelectTrigger>
              <SelectContent>
                {categoryOptions.map(option => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      <Card className="overflow-hidden border-border shadow-none bg-card">
        <CardContent className="p-0">
          <PropertyBookTable
            items={currentItems}
            tab={state.activeTab}
            state={state}
            dispatch={dispatch}
            onItemSelect={handleItemSelect}
            onToggleExpand={handleToggleExpand}
            onSelectAll={handleSelectAll}
            onTransferRequest={handleTransferRequest}
            onViewDetails={handleViewDetails}
            onRecallItem={handleRecallItem}
            onSendMaintenanceForm={handleSendMaintenanceForm}
            onRequestSort={handleRequestSort}
            isLoading={state.isLoading}
            error={state.error}
            StatusBadge={StatusBadge}
          />
        </CardContent>
      </Card>

      {/* Create Item Dialog */}
      <CreatePropertyDialog
        isOpen={createItemModalOpen}
        onClose={() => setCreateItemModalOpen(false)}
        onSubmit={handleCreateItem}
      />

      {/* Transfer Request Modal */}
      {selectedItem && (
        <TransferRequestModal
          isOpen={transferModalOpen}
          onClose={() => {
            setTransferModalOpen(false);
            setSelectedItem(null);
          }}
          item={selectedItem}
          onTransferSuccess={() => {
            setTransferModalOpen(false);
            setSelectedItem(null);
            toast({
              title: "Transfer Initiated",
              description: "The transfer request has been sent successfully."
            });
          }}
        />
      )}

      {/* Item Details Modal */}
      {selectedItem && (
        <Dialog open={detailsModalOpen} onOpenChange={setDetailsModalOpen}>
          <DialogContent className="sm:max-w-2xl md:max-w-3xl lg:max-w-4xl bg-card">
            <DialogHeader>
              <DialogTitle className="text-lg font-medium">Equipment Details</DialogTitle>
              <DialogDescription>
                Detailed information for {selectedItem.name} (SN: {selectedItem.serialNumber})
              </DialogDescription>
            </DialogHeader>
            <div className="py-4 max-h-[70vh] overflow-y-auto pr-2">
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 text-sm mb-6 border-b border-border pb-4">
                <div>
                  <p className="text-xs uppercase tracking-wider font-medium text-muted-foreground mb-1">
                    Category
                  </p>
                  <div className="flex items-center gap-2">
                    <span className={getCategoryColor(selectedItem.name)}>
                      {getCategoryIcon(selectedItem.name)}
                    </span>
                    <span className="capitalize">
                      {getCategoryFromName(selectedItem.name).replace(/-/g, ' ')}
                    </span>
                  </div>
                </div>
                <div>
                  <p className="text-xs uppercase tracking-wider font-medium text-muted-foreground mb-1">
                    Status
                  </p>
                  <StatusBadge status={selectedItem.status} />
                </div>
                <div>
                  <p className="text-xs uppercase tracking-wider font-medium text-muted-foreground mb-1">
                    Assigned Date
                  </p>
                  <p className="text-xs text-muted-foreground">{selectedItem.assignedDate || "N/A"}</p>
                </div>
              </div>

              <div className="mb-4">
                <h4 className="text-xs uppercase tracking-wider font-medium text-muted-foreground mb-2">
                  Components
                </h4>
                <ComponentList 
                  itemId={selectedItem.id}
                  components={selectedItem.components || []} 
                  onAddComponent={handleAddComponent}
                  onUpdateComponent={handleUpdateComponent}
                  onRemoveComponent={handleRemoveComponent}
                />
              </div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setDetailsModalOpen(false)}>Close</Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      )}

      {/* Maintenance Form Modal */}
      {selectedItem && (
        <SendMaintenanceForm
          property={{
            id: typeof selectedItem.id === 'string' ? parseInt(selectedItem.id) : selectedItem.id,
            name: selectedItem.name,
            serialNumber: selectedItem.serialNumber,
            nsn: selectedItem.nsn,
            location: selectedItem.location,
          }}
          open={maintenanceFormModalOpen}
          onClose={() => {
            setMaintenanceFormModalOpen(false);
            setSelectedItem(null);
          }}
        />
      )}
    </PageWrapper>
  );
};

export default PropertyBook;