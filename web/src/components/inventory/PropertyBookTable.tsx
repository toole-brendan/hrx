import React, { Fragment } from "react";
import { InventoryItem, Component } from "@/types";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Checkbox } from "@/components/ui/checkbox";
import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";
import { PropertyBookState } from "@/lib/propertyBookReducer";
import { getCategoryColor, getCategoryIcon, getCategoryFromName, getCategoryLabel } from "@/lib/inventoryUtils";
import { 
  ArrowLeftRight, 
  CheckCircle, 
  Info, 
  SearchX, 
  ArrowUpDown,
  ChevronDown,
  ChevronRight
} from "lucide-react";
import QRCodeGenerator from "@/components/common/QRCodeGenerator";

// Define types for our table components
export type DisplayItem = InventoryItem & { 
  assignedTo?: string; 
  transferDate?: string; 
};

type PropertyBookTableProps = {
  items: DisplayItem[];
  tab: 'assigned' | 'signedout';
  state: PropertyBookState;
  dispatch: React.Dispatch<any>;
  onItemSelect: (itemId: string) => void;
  onToggleExpand: (itemId: string) => void;
  onSelectAll: (checked: boolean) => void;
  onTransferRequest: (item: InventoryItem) => void;
  onViewDetails: (item: InventoryItem) => void;
  onRecallItem: (item: InventoryItem) => void;
  onRequestSort: (key: string) => void;
  isLoading: boolean;
  error: string | null;
  StatusBadge: React.FC<{ status: string }>;
};

const PropertyBookTable: React.FC<PropertyBookTableProps> = ({
  items,
  tab,
  state,
  dispatch,
  onItemSelect,
  onToggleExpand,
  onSelectAll,
  onTransferRequest,
  onViewDetails,
  onRecallItem,
  onRequestSort,
  isLoading,
  error,
  StatusBadge
}) => {
  // Handle filtered item display
  const filtered = items;
  const allSelected = filtered.length > 0 && filtered.every(item => state.selectedItemIds.has(item.id));
  const indeterminate = filtered.some(item => state.selectedItemIds.has(item.id)) && !allSelected;
  
  // Calculate the colspan based on visible columns
  const colSpanCount = 7; // Checkbox, Name, SN, Category, Date/AssignedTo, Status, Actions
  
  // Log expandable items for debugging
  console.log('Expandable items:', items.filter(item => item.components && item.components.length > 0)
    .map(item => ({
      id: item.id,
      name: item.name,
      componentCount: item.components?.length || 0,
      isExpanded: state.expandedItemIds.has(item.id)
    }))
  );
  console.log('Expanded item IDs in state:', Array.from(state.expandedItemIds));
  
  // Sortable header component
  const SortableHeader: React.FC<{ columnKey: string; children: React.ReactNode }> = ({ columnKey, children }) => (
    <TableHead 
      className={`py-4 px-4 text-black dark:text-white min-w-[150px] w-auto cursor-pointer hover:bg-muted/80 transition-colors`}
      onClick={() => onRequestSort(columnKey)}
    >
      <div className="flex items-center">
        {children}
        <ArrowUpDown className="ml-2 h-3 w-3 text-muted-foreground" /> 
      </div>
    </TableHead>
  );

  return (
    <TooltipProvider>
      {isLoading ? (
        <div className="space-y-2 p-4">
          {/* Loading skeleton - kept same as original */}
          <div className="flex items-center space-x-4">
            <div className="h-5 w-5 rounded-none bg-muted animate-pulse" /> 
            <div className="h-4 flex-1 rounded-none bg-muted animate-pulse" />
            <div className="h-4 w-32 rounded-none bg-muted animate-pulse" />
            <div className="h-4 w-32 rounded-none bg-muted animate-pulse" />
            <div className="h-4 w-24 rounded-none bg-muted animate-pulse" />
            <div className="h-4 w-20 rounded-none bg-muted animate-pulse" />
            <div className="h-4 w-16 rounded-none bg-muted animate-pulse" />
          </div>
          <div className="flex items-center space-x-4">
            <div className="h-5 w-5 rounded-none bg-muted animate-pulse" /> 
            <div className="h-4 flex-1 rounded-none bg-muted animate-pulse" />
            <div className="h-4 w-32 rounded-none bg-muted animate-pulse" />
            <div className="h-4 w-32 rounded-none bg-muted animate-pulse" />
            <div className="h-4 w-24 rounded-none bg-muted animate-pulse" />
            <div className="h-4 w-20 rounded-none bg-muted animate-pulse" />
            <div className="h-4 w-16 rounded-none bg-muted animate-pulse" />
          </div>
        </div>
      ) : error ? (
        <div className="p-4 text-center text-red-600">Error: {error}</div>
      ) : (
        <div className="relative overflow-x-auto">
          <Table>
            <TableHeader className="bg-muted/50 sticky top-0 z-10">
              <TableRow>
                <TableHead className="w-[60px] px-4 py-4 text-black dark:text-white">
                  <Checkbox 
                    id={`select-all-${tab}`}
                    checked={allSelected}
                    onCheckedChange={onSelectAll}
                    aria-label={`Select all items in ${tab} tab`}
                    data-state={indeterminate ? 'indeterminate' : (allSelected ? 'checked' : 'unchecked')}
                  />
                </TableHead>
                <SortableHeader columnKey="name">Item Name</SortableHeader>
                <SortableHeader columnKey="serialNumber">Serial Number</SortableHeader>
                <SortableHeader columnKey="category">Category</SortableHeader>
                {tab === 'assigned' ? (
                  <SortableHeader columnKey="assignedDate">Assigned Date</SortableHeader>
                ) : (
                  <SortableHeader columnKey="assignedTo">Assigned To</SortableHeader>
                )}
                <SortableHeader columnKey="status">Status</SortableHeader>
                <TableHead className="text-right pr-4 w-[120px] min-w-[120px] py-4 px-4 text-black dark:text-white">
                  Actions
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filtered.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={colSpanCount} className="h-32 text-center text-muted-foreground">
                    <div className="flex flex-col items-center justify-center gap-2">
                      <SearchX className="h-10 w-10 text-muted-foreground/50" />
                      <span>No items found matching your criteria.</span>
                    </div>
                  </TableCell>
                </TableRow>
              ) : (
                filtered.map((item) => (
                  <PropertyBookTableRow
                    key={item.id}
                    item={item}
                    tab={tab}
                    state={state}
                    onItemSelect={onItemSelect}
                    onToggleExpand={onToggleExpand}
                    onTransferRequest={onTransferRequest}
                    onViewDetails={onViewDetails}
                    onRecallItem={onRecallItem}
                    StatusBadge={StatusBadge}
                  />
                ))
              )}
            </TableBody>
          </Table>
        </div>
      )}
    </TooltipProvider>
  );
};

// Table row component for each property item
type PropertyBookTableRowProps = {
  item: DisplayItem;
  tab: 'assigned' | 'signedout';
  state: PropertyBookState;
  onItemSelect: (itemId: string) => void;
  onToggleExpand: (itemId: string) => void;
  onTransferRequest: (item: InventoryItem) => void;
  onViewDetails: (item: InventoryItem) => void;
  onRecallItem: (item: InventoryItem) => void;
  StatusBadge: React.FC<{ status: string }>;
};

const PropertyBookTableRow: React.FC<PropertyBookTableRowProps> = React.memo(({
  item,
  tab,
  state,
  onItemSelect,
  onToggleExpand,
  onTransferRequest,
  onViewDetails,
  onRecallItem,
  StatusBadge
}) => {
  const itemCategory = item.category && item.category !== 'other' 
    ? item.category 
    : getCategoryFromName(item.name);
  
  // Make sure components is never undefined
  const components = item.components || [];
  const hasComponents = components.length > 0;
  const isExpanded = state.expandedItemIds.has(item.id);
  
  // Add console logging to help debug what's happening
  console.log(`Item ${item.name} (${item.id}):`, { 
    hasComponents, 
    isExpanded,
    componentsCount: components.length,
    componentsList: components,
    expandedItemIds: Array.from(state.expandedItemIds)
  });
  
  // Function to handle row click for expansion
  const handleRowClick = () => {
    if (hasComponents) {
      console.log('Row clicked for item:', item.id);
      onToggleExpand(item.id);
    }
  };
  
  return (
    <Fragment>
      <TableRow
        data-state={state.selectedItemIds.has(item.id) ? 'selected' : ''}
        className={cn(
          "hover:bg-muted/50 data-[state=selected]:bg-blue-900/20",
          hasComponents && "cursor-pointer"
        )}
        onClick={handleRowClick}
      >
        <TableCell className="px-4 py-4" onClick={(e) => e.stopPropagation()}>
          <Checkbox 
            id={`select-${item.id}`}
            checked={state.selectedItemIds.has(item.id)}
            onCheckedChange={() => onItemSelect(item.id)}
            aria-labelledby={`item-label-${item.id}`}
          />
        </TableCell>
        <TableCell className="py-4 px-4 text-black dark:text-white">
          <div className="flex items-center gap-2">
            {hasComponents && (
              <span 
                onClick={(e) => { e.stopPropagation(); onToggleExpand(item.id); }} 
                className="cursor-pointer hover:bg-gray-200 dark:hover:bg-gray-700 p-1 rounded"
              >
                {isExpanded ? 
                  <ChevronDown className="h-4 w-4 text-muted-foreground"/> : 
                  <ChevronRight className="h-4 w-4 text-muted-foreground"/>
                }
              </span>
            )}
            {!hasComponents && <span className="w-4"></span>}
            <Tooltip>
              <TooltipTrigger asChild>
                <div id={`item-label-${item.id}`} className="font-semibold truncate">
                  {item.name}
                  {hasComponents && (
                    <span className="text-xs ml-2 text-muted-foreground">
                      ({components.length} component{components.length !== 1 ? 's' : ''})
                    </span>
                  )}
                </div>
              </TooltipTrigger>
              <TooltipContent><p>{item.name}</p></TooltipContent>
            </Tooltip>
          </div>
        </TableCell>
        <TableCell className="py-4 px-4 text-xs text-muted-foreground dark:text-gray-400">
          <span className="font-mono tracking-wider">{item.serialNumber}</span>
        </TableCell>
        <TableCell className="py-4 px-4">
          <div className="flex items-center gap-2">
            <span className={getCategoryColor(item.name)}>
              {getCategoryIcon(item.name)}
            </span>
            <Tooltip>
              <TooltipTrigger asChild>
                <span className="capitalize text-sm">
                  {itemCategory.replace(/-/g, ' ')}
                </span>
              </TooltipTrigger>
              <TooltipContent>
                <p>{getCategoryLabel(itemCategory)}</p>
              </TooltipContent>
            </Tooltip>
          </div>
        </TableCell>
        {tab === 'assigned' ? (
          <TableCell className="py-4 px-4 text-xs text-muted-foreground dark:text-gray-400">
            {item.assignedDate}
          </TableCell> 
        ) : (
          <TableCell className="py-4 px-4 text-xs text-muted-foreground dark:text-gray-400">
            <Tooltip>
              <TooltipTrigger asChild>
                <span className="truncate block">{item.assignedTo}</span>
              </TooltipTrigger>
              <TooltipContent><p>{item.assignedTo}</p></TooltipContent>
            </Tooltip>
          </TableCell> 
        )}
        <TableCell className="py-4 px-4">
          <StatusBadge status={item.status} />
        </TableCell>
        <TableCell className="text-right py-4 px-4" onClick={(e) => e.stopPropagation()}>
          <div className="flex justify-end items-center gap-1">
            {tab === 'assigned' && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button 
                    variant="ghost" 
                    size="icon" 
                    onClick={() => onTransferRequest(item as InventoryItem)} 
                    className="h-8 w-8"
                  >
                    <ArrowLeftRight className="h-4 w-4" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Request Transfer</TooltipContent>
              </Tooltip>
            )}
            {tab === 'signedout' && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button 
                    variant="ghost" 
                    size="icon" 
                    onClick={() => onRecallItem(item as InventoryItem)} 
                    className="h-8 w-8"
                  >
                    <CheckCircle className="h-4 w-4 text-green-600" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Initiate Recall</TooltipContent>
              </Tooltip>
            )}
            <QRCodeGenerator 
              itemName={item.name} 
              serialNumber={item.serialNumber}
            />
            <Tooltip>
              <TooltipTrigger asChild>
                <Button 
                  variant="ghost" 
                  size="icon" 
                  onClick={() => onViewDetails(item as InventoryItem)} 
                  className="h-8 w-8"
                >
                  <Info className="h-4 w-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>View Details</TooltipContent>
            </Tooltip>
          </div>
        </TableCell>
      </TableRow>
      
      {/* Conditional Row for Components */}
      {hasComponents && isExpanded && (
        <ComponentsRow
          itemId={item.id}
          components={components}
          colSpanCount={7} // Make sure this matches the number of columns in the table
        />
      )}
    </Fragment>
  );
});

// Components row component to show expanded component details
type ComponentsRowProps = {
  itemId: string;
  components: Component[];
  colSpanCount: number;
};

const ComponentsRow: React.FC<ComponentsRowProps> = React.memo(({
  itemId,
  components,
  colSpanCount
}) => {
  // Console log for debugging
  console.log(`Rendering ComponentsRow for item ${itemId}:`, { components, colSpanCount });
  
  return (
    <TableRow key={`${itemId}-components`} className="bg-muted/30 dark:bg-muted/10">
      <TableCell colSpan={colSpanCount} className="py-3 px-4">
        <div className="pl-10">
          <h4 className="text-xs uppercase tracking-wider font-medium text-muted-foreground mb-2">
            Components:
          </h4>
          <ul className="space-y-1 text-sm">
            {components.length === 0 ? (
              <li className="text-muted-foreground">No components found</li>
            ) : (
              components.map((comp) => (
                <li key={comp.id} className="flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2">
                    <span className="font-medium">{comp.name}</span>
                    {comp.serialNumber && (
                      <span className="font-mono text-muted-foreground">
                        (SN: {comp.serialNumber})
                      </span>
                    )}
                    {comp.quantity && comp.required && (
                      <span className="text-muted-foreground ml-2">
                        Qty: {comp.quantity} {comp.required ? "(Required)" : ""}
                      </span>
                    )}
                  </div>
                  {comp.status && (
                    <span className={`inline-block px-2 py-1 text-xs rounded-full whitespace-nowrap
                      ${comp.status === 'present' 
                        ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400' 
                        : comp.status === 'missing' 
                        ? 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400' 
                        : 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400'}`
                    }>
                      {comp.status}
                    </span>
                  )}
                </li>
              ))
            )}
          </ul>
        </div>
      </TableCell>
    </TableRow>
  );
});

PropertyBookTableRow.displayName = 'PropertyBookTableRow';
ComponentsRow.displayName = 'ComponentsRow';

export default PropertyBookTable; 