import React from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { MaintenanceItem } from "@/lib/maintenanceData"; // Adjust path if needed
import { MaintenanceItemRow } from './MaintenanceItemRow'; // Import the row component
import { Search, Wrench, RefreshCw, ArrowUpDown, ArrowUp, ArrowDown } from 'lucide-react';
import { Button } from "@/components/ui/button";

// Props interface for the component
interface MaintenanceListProps {
  items: MaintenanceItem[];
  searchTerm: string;
  setSearchTerm: (term: string) => void;
  filterCategory: string;
  setFilterCategory: (category: string) => void;
  filterStatus: string;
  setFilterStatus: (status: string) => void;
  filterPriority: string;
  setFilterPriority: (priority: string) => void;
  onViewDetails: (item: MaintenanceItem) => void;
  onStartMaintenance: (item: MaintenanceItem) => void;
  onCompleteMaintenance: (item: MaintenanceItem) => void;
  onResetFilters: () => void;
  sortConfig: { field: keyof MaintenanceItem | 'none'; order: 'asc' | 'desc' };
  onSort: (field: keyof MaintenanceItem | 'none') => void;
}

// Helper component for sortable table headers
const SortableHeader = ({
    label,
    field,
    sortConfig,
    onSort
}: {
    label: string;
    field: keyof MaintenanceItem | 'none';
    sortConfig: { field: keyof MaintenanceItem | 'none'; order: 'asc' | 'desc' };
    onSort: (field: keyof MaintenanceItem | 'none') => void;
    className?: string;
}) => {
    const isActive = sortConfig.field === field;
    const Icon = isActive ? (sortConfig.order === 'asc' ? ArrowUp : ArrowDown) : ArrowUpDown;
    return (
        <div
            className="flex items-center cursor-pointer hover:text-foreground transition-colors group text-xs uppercase tracking-wider text-muted-foreground font-medium"
            onClick={() => onSort(field)}
        >
            <span>{label}</span>
            <Icon className={`h-3 w-3 ml-1 ${isActive ? 'text-foreground' : 'text-muted-foreground group-hover:text-foreground'}`} />
        </div>
    );
};

// Main List Header Component
const MaintenanceListHeader = ({
    sortConfig,
    onSort
}: { 
    sortConfig: { field: keyof MaintenanceItem | 'none'; order: 'asc' | 'desc' };
    onSort: (field: keyof MaintenanceItem | 'none') => void;
}) => {
    return (
        <div className="grid grid-cols-[2fr_1fr_1fr_1fr_180px] gap-4 border-b px-6 py-3 bg-muted/50 sticky top-0 z-10">
            <SortableHeader label="Item / Description" field="itemName" sortConfig={sortConfig} onSort={onSort} />
            <SortableHeader label="Status" field="status" sortConfig={sortConfig} onSort={onSort} />
            <SortableHeader label="Priority" field="priority" sortConfig={sortConfig} onSort={onSort} />
            <SortableHeader label="Reported" field="reportedDate" sortConfig={sortConfig} onSort={onSort} />
            <div className="text-right text-xs uppercase tracking-wider text-muted-foreground font-medium">Actions</div>
        </div>
    );
};

export const MaintenanceList: React.FC<MaintenanceListProps> = ({
  items,
  searchTerm,
  setSearchTerm,
  filterCategory,
  setFilterCategory,
  filterStatus,
  setFilterStatus,
  filterPriority,
  setFilterPriority,
  onViewDetails,
  onStartMaintenance,
  onCompleteMaintenance,
  onResetFilters,
  sortConfig,
  onSort
}) => {
  return (
    <Card className="overflow-hidden border-border shadow-none bg-card rounded-none">
      <CardHeader className="pb-0 pt-6 px-6 border-b">
        <CardTitle className="text-xl font-light tracking-tight mb-1">Maintenance Requests</CardTitle>
        <CardDescription className="text-sm text-muted-foreground mb-5">
          View and manage equipment maintenance requests
        </CardDescription>
        {/* Filter Bar */}
        <div className="py-4 px-0 flex flex-col md:flex-row gap-3">
          <div className="relative flex-grow">
            <Input
              placeholder="Search by name, serial number, or description"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10 h-9 rounded-none" // Use rounded-none for consistency
            />
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          </div>
          <div className="w-full md:w-[150px]">
            <Select value={filterCategory} onValueChange={setFilterCategory}>
              <SelectTrigger className="h-9 rounded-none text-xs">
                <SelectValue placeholder="Category" />
              </SelectTrigger>
              <SelectContent className="rounded-none">
                <SelectItem value="all">All Categories</SelectItem>
                <SelectItem value="weapon">Weapons</SelectItem>
                <SelectItem value="vehicle">Vehicles</SelectItem>
                <SelectItem value="communication">Comms</SelectItem>
                <SelectItem value="optics">Optics</SelectItem>
                <SelectItem value="other">Other</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="w-full md:w-[150px]">
            <Select value={filterStatus} onValueChange={setFilterStatus}>
              <SelectTrigger className="h-9 rounded-none text-xs">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent className="rounded-none">
                <SelectItem value="all">All Status</SelectItem>
                <SelectItem value="scheduled">Scheduled</SelectItem>
                <SelectItem value="in-progress">In Progress</SelectItem>
                <SelectItem value="completed">Completed</SelectItem>
                <SelectItem value="cancelled">Cancelled</SelectItem>
                {/* Add refined statuses here if adopted, e.g.: */}
                {/* <SelectItem value="deadline-maintenance">Deadline - Maint</SelectItem> */}
                {/* <SelectItem value="deadline-supply">Deadline - Supply</SelectItem> */}
              </SelectContent>
            </Select>
          </div>
          <div className="w-full md:w-[150px]">
            <Select value={filterPriority} onValueChange={setFilterPriority}>
              <SelectTrigger className="h-9 rounded-none text-xs">
                <SelectValue placeholder="Priority" />
              </SelectTrigger>
              <SelectContent className="rounded-none">
                <SelectItem value="all">All Priorities</SelectItem>
                <SelectItem value="low">Low</SelectItem>
                <SelectItem value="medium">Medium</SelectItem>
                <SelectItem value="high">High</SelectItem>
                <SelectItem value="critical">Critical</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <Button
            onClick={onResetFilters}
            variant="ghost"
            size="sm"
            className="text-muted-foreground h-9 px-3 rounded-none hover:bg-muted whitespace-nowrap"
          >
            <RefreshCw className="h-4 w-4 mr-1" />
            <span className="text-xs uppercase tracking-wider">Clear</span>
          </Button>
        </div>
      </CardHeader>

      {/* Maintenance Items List */}
      <CardContent className="p-0">
        <div className="rounded-none">
          {items.length === 0 ? (
            <div className="py-10 px-6 text-center text-muted-foreground">
              <div className="inline-flex h-16 w-16 items-center justify-center rounded-full bg-muted mb-4">
                 <Wrench className="h-8 w-8 text-muted-foreground/70" />
              </div>
              <h3 className="text-lg font-medium mb-1">No maintenance requests found</h3>
              <p className="text-sm">Try adjusting your filters or search terms.</p>
              {/* Consider adding a clear filters button here too */}
            </div>
          ) : (
            <>
              <MaintenanceListHeader sortConfig={sortConfig} onSort={onSort} />
              <div className="divide-y divide-border px-0">
                {items.map((item) => (
                  <MaintenanceItemRow
                    key={item.id}
                    item={item}
                    onViewDetails={onViewDetails}
                    onStartMaintenance={onStartMaintenance}
                    onCompleteMaintenance={onCompleteMaintenance}
                  />
                ))}
              </div>
            </>
          )}
        </div>
      </CardContent>
      {/* Add Pagination if needed */}
      {/* <CardFooter> ... </CardFooter> */}
    </Card>
  );
};
