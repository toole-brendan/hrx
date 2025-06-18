import { useState, useEffect, useMemo, useReducer, useCallback } from "react";
import { useProperties, useOfflineSync, useUpdatePropertyComponents, useCreateProperty } from "@/hooks/useProperty";
import { useTransfers } from "@/hooks/useTransfers";
import { Property, Transfer, Component } from "@/types";
import { v4 as uuidv4 } from 'uuid';
import { Input } from "@/components/ui/input";
import { 
  Select, 
  SelectContent, 
  SelectItem, 
  SelectTrigger, 
  SelectValue 
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { useToast } from "@/hooks/use-toast";

// iOS Components
import { 
  CleanCard, 
  ElegantSectionHeader, 
  StatusBadge, 
  ModernPropertyCard,
  FloatingActionButton,
  MinimalEmptyState 
} from "@/components/ios";

import TransferRequestModal from "@/components/modals/TransferRequestModal";
import ComponentList from "@/components/property/ComponentList";
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
  FileText
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
  const assignedToMe = useMemo(() => {
    return properties.map(item => ({
      ...item,
      category: getCategoryFromName(item.name)
    }));
  }, [properties]);
  
  // Create memoized data for signed-out items based on transfers
  const signedOutItems = useMemo(() => {
    return transfers
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
        }
      });
  }, [properties, transfers]);

  // Filter items based on search and category
  const getFilteredItems = useCallback((items: any[], tab: string) => {
    return items.filter(item => {
      const name = item.name || '';
      const serialNumber = item.serialNumber || '';
      const assignedTo = (tab === "signedout" && item.assignedTo) ? item.assignedTo.toLowerCase() : '';
      const searchTermLower = state.searchTerm.toLowerCase();

      const matchesSearch = 
        name.toLowerCase().includes(searchTermLower) ||
        serialNumber.toLowerCase().includes(searchTermLower) ||
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

  // Effect for handling direct navigation to an item via id prop
  useEffect(() => {
    if (!state.isLoading && id) {
      const assignedItem = properties.find(item => item.id === id);
      const signedOutItemDetails = signedOutItems.find(item => item.id === id); 
      
      let itemToSelect: any = null;
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

  return (
    <div className="min-h-screen bg-app-background">
      <div className="max-w-7xl mx-auto px-6 py-8">
        {/* Header */}
        <div className="mb-8">
          <ElegantSectionHeader 
            title="PROPERTY BOOK" 
            className="mb-4"
          />
          
          <div className="flex flex-col sm:flex-row sm:items-center justify-between space-y-4 sm:space-y-0">
            <div>
              <h1 className="text-3xl font-light tracking-tight text-primary-text">
                Equipment Registry
              </h1>
              <p className="text-secondary-text mt-1">
                Manage assigned and transferred property
              </p>
            </div>
            <Button 
              onClick={() => setCreateItemModalOpen(true)}
              className="bg-primary-text hover:bg-black/90 text-white font-medium px-6 py-3 rounded-none flex items-center gap-2"
            >
              <Plus className="h-4 w-4" />
              Add Property
            </Button>
          </div>
        </div>

        {/* Search and Filter Controls */}
        <CleanCard className="mb-6">
          <div className="flex flex-col sm:flex-row gap-4">
            {/* Search */}
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-tertiary-text" />
              <Input
                placeholder="Search by name, serial number, or assignee..."
                value={state.searchTerm}
                onChange={(e) => dispatch({ type: 'SET_SEARCH_TERM', payload: e.target.value })}
                className="pl-10 border-0 border-b border-ios-border rounded-none px-3 py-2 text-base text-primary-text placeholder:text-quaternary-text focus:border-primary-text focus:border-b-2 transition-all duration-200 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
              />
            </div>

            {/* Category Filter */}
            <div className="sm:w-48">
              <Select
                value={state.filterCategory}
                onValueChange={(value) => dispatch({ type: 'SET_FILTER_CATEGORY', payload: value })}
              >
                <SelectTrigger className="border-0 border-b border-ios-border rounded-none px-3 py-2 text-base text-primary-text focus:border-primary-text focus:border-b-2 transition-all duration-200 bg-transparent focus:ring-0 focus:ring-offset-0 h-auto">
                  <SelectValue placeholder="Filter by category" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Categories</SelectItem>
                  {categoryOptions.map((category) => (
                    <SelectItem key={category.value} value={category.value}>
                      {category.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        </CleanCard>

        {/* Tabs */}
        <CleanCard padding="none" className="mb-6">
          <Tabs 
            value={state.activeTab} 
            onValueChange={(value) => dispatch({ type: 'SET_ACTIVE_TAB', payload: value as 'assigned' | 'signedout' })}
            className="w-full"
          >
            <div className="border-b border-ios-border">
              <TabsList className="grid grid-cols-2 w-full bg-transparent">
                <TabsTrigger 
                  value="assigned"
                  className="text-sm uppercase tracking-wide font-medium data-[state=active]:bg-transparent data-[state=active]:text-primary-text data-[state=active]:border-b-2 data-[state=active]:border-ios-accent rounded-none"
                >
                  ASSIGNED TO ME ({assignedToMe.length})
                </TabsTrigger>
                <TabsTrigger 
                  value="signedout"
                  className="text-sm uppercase tracking-wide font-medium data-[state=active]:bg-transparent data-[state=active]:text-primary-text data-[state=active]:border-b-2 data-[state=active]:border-ios-accent rounded-none"
                >
                  SIGNED OUT ({signedOutItems.length})
                </TabsTrigger>
              </TabsList>
            </div>

            <TabsContent value="assigned" className="p-6">
              {state.isLoading ? (
                <div className="space-y-3">
                  {[...Array(5)].map((_, i) => (
                    <Skeleton key={i} className="h-24 w-full" />
                  ))}
                </div>
              ) : currentItems.length === 0 ? (
                <MinimalEmptyState
                  title={state.searchTerm || state.filterCategory !== "all" ? "No items match your search" : "No property assigned"}
                  description={state.searchTerm || state.filterCategory !== "all" ? "Try adjusting your search criteria" : "Start by adding property to your inventory"}
                  icon={<Package className="h-12 w-12" />}
                  action={
                    <Button
                      onClick={() => setCreateItemModalOpen(true)}
                      className="bg-ios-accent hover:bg-accent-hover text-white px-6 py-2 rounded-none"
                    >
                      Add Property
                    </Button>
                  }
                />
              ) : (
                <div className="space-y-4">
                  {currentItems.map((item) => (
                    <ModernPropertyCard
                      key={item.id}
                      property={{
                        itemName: item.name,
                        serialNumber: item.serialNumber,
                        status: item.status as 'operational' | 'maintenance' | 'non-operational',
                        isSensitive: item.category === 'weapons' || item.category === 'optics',
                        category: item.category
                      }}
                      onClick={() => handleViewDetails(item)}
                      selected={state.selectedItemIds.has(item.id)}
                      onSelect={(selected: boolean) => handleItemSelect(item.id)}
                    />
                  ))}
                </div>
              )}
            </TabsContent>

            <TabsContent value="signedout" className="p-6">
              {state.isLoading ? (
                <div className="space-y-3">
                  {[...Array(5)].map((_, i) => (
                    <Skeleton key={i} className="h-24 w-full" />
                  ))}
                </div>
              ) : currentItems.length === 0 ? (
                <MinimalEmptyState
                  title="No signed out items"
                  description="Items you've transferred to others will appear here"
                  icon={<Send className="h-12 w-12" />}
                />
              ) : (
                <div className="space-y-4">
                  {currentItems.map((item) => (
                    <ModernPropertyCard
                      key={item.id}
                      property={{
                        itemName: item.name,
                        serialNumber: item.serialNumber,
                        status: 'operational', // Most signed out items are operational
                        isSensitive: item.category === 'weapons' || item.category === 'optics',
                        category: item.category
                      }}
                      onClick={() => handleViewDetails(item)}
                      selected={state.selectedItemIds.has(item.id)}
                      onSelect={(selected: boolean) => handleItemSelect(item.id)}
                    />
                  ))}
                </div>
              )}
            </TabsContent>
          </Tabs>
        </CleanCard>
      </div>

      {/* Floating Action Button for Bulk Actions */}
      {hasSelectedItems && (
        <FloatingActionButton
          onClick={() => handleBulkAction('export')}
          icon={<FileText className="h-5 w-5" />}
          label={`Export ${state.selectedItemIds.size} items`}
          position="bottom-right"
        />
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
    </div>
  );
};

export default PropertyBook;