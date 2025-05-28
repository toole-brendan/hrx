import { useState, useEffect, useReducer, useCallback } from "react";
import { format, subDays, addDays, isValid } from "date-fns";
import { 
  Card, 
  CardContent, 
  CardHeader, 
  CardTitle, 
  CardDescription, 
  CardFooter 
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { useToast } from "@/hooks/use-toast";
import { Progress } from "@/components/ui/progress";
import { PageHeader } from "@/components/ui/page-header";
import { PageWrapper } from "@/components/ui/page-wrapper";
import { Separator } from "@/components/ui/separator";
import { useIsMobile } from "@/hooks/use-mobile";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Calendar as CalendarComponent } from "@/components/ui/calendar";
import { motion, AnimatePresence } from "framer-motion";
// import { BarChart, PieChart } from "@/components/charts";

import { 
  Search, 
  Filter, 
  Wrench, 
  AlertTriangle, 
  Clock, 
  CheckCircle, 
  XCircle, 
  Calendar, 
  ClipboardList, 
  Truck, 
  Package,
  Plus,
  FileText,
  History,
  Send, 
  ArrowRight,
  HelpCircle,
  CalendarClock,
  Info,
  Activity,
  BarChart3,
  User, 
  Tag,
  ChevronRight,
  Hammer,
  MessageSquare,
  Bell,
  ListChecks,
  MailQuestion,
  Settings,
  PlusCircle as CirclePlus,
  QrCode,
  Paperclip,
  Camera as CameraIcon,
  Upload as UploadIcon,
  CalendarIcon,
  XIcon,
  LinkIcon,
  AlertCircle,
  RefreshCw
} from "lucide-react";

import { maintenanceItems, maintenanceLogs, maintenanceStats, maintenanceBulletins, MaintenanceItem, MaintenanceLog, MaintenanceBulletin } from "@/lib/maintenanceData";
import { maintenanceReducer, initialState } from "@/lib/maintenanceReducer";
import { 
  getMaintenanceItemsFromDB, 
  getMaintenanceLogsFromDB, 
  getMaintenanceBulletinsFromDB, 
  getMaintenanceStatsFromDB,
  initializeMaintenanceDataIfEmpty,
  updateMaintenanceItemStatusInDB,
  addMaintenanceItemToDB,
  addMaintenanceBulletinToDB,
  getMaintenanceItemByIdFromDB,
  getMaintenanceLogsByItemIdFromDB,
  addMaintenanceLogToDB
} from "@/lib/maintenanceIdb";
import { getInventoryItemsFromDB } from "@/lib/idb";
import { InventoryItem } from "@/types";
import CalibrationManager from "@/components/maintenance/CalibrationManager";
import { v4 as uuidv4 } from 'uuid';
import { Label } from "@/components/ui/label";
import { MaintenanceStatusBadge, MaintenancePriorityBadge } from '@/components/maintenance/MaintenanceBadges';
import { Play, Radio, Sword } from '@/components/ui/custom-icons';
import { MaintenanceItemRow } from '@/components/maintenance/MaintenanceItemRow';
import { MaintenanceList } from '@/components/maintenance/MaintenanceList';
import { MaintenanceDashboard } from '@/components/maintenance/MaintenanceDashboard';
import { MaintenanceBulletinBoard } from '@/components/maintenance/MaintenanceBulletinBoard';
import { openDB } from 'idb';

interface MaintenanceProps {
  id?: string;
}

const Maintenance: React.FC<MaintenanceProps> = ({ id }) => {
  // Use the maintenance reducer
  const [state, dispatch] = useReducer(maintenanceReducer, initialState);
  
  // UI state not in reducer
  const [selectedItem, setSelectedItem] = useState<MaintenanceItem | null>(null);
  const [itemLogs, setItemLogs] = useState<MaintenanceLog[]>([]);
  const [detailsModalOpen, setDetailsModalOpen] = useState(false);
  const [newRequestModalOpen, setNewRequestModalOpen] = useState(false);
  const [addBulletinModalOpen, setAddBulletinModalOpen] = useState(false);
  const [showCalibrationManager, setShowCalibrationManager] = useState(false);
  const [inventoryItems, setInventoryItems] = useState<InventoryItem[]>([]);
  const [selectedInventoryItem, setSelectedInventoryItem] = useState<InventoryItem | null>(null);
  const [isLoadingLogs, setIsLoadingLogs] = useState(false);
  const [isSavingStatus, setIsSavingStatus] = useState(false);
  const [modalInventorySearchTerm, setModalInventorySearchTerm] = useState("");
  
  const isMobile = useIsMobile();
  const { toast } = useToast();

  // Destructure relevant state for easier access
  const { 
    isLoading, 
    error, 
    maintenanceItems, 
    maintenanceLogs, 
    bulletins, 
    stats, 
    searchTerm, 
    filterCategory, 
    filterStatus, 
    filterPriority, 
    dateRange, 
    selectedTab,
    isSubmitting,
    sortConfig // Destructure sortConfig
  } = state; 

  // Add this function to force reinitialize data
  const forceReinitializeData = async () => {
    try {
      console.log("Clearing and re-initializing maintenance data...");
      
      // Show loading toast
      toast({
        title: "Reinitializing Data",
        description: "Please wait while we reload the maintenance data...",
        variant: "default",
      });
      
      dispatch({ type: 'SET_LOADING', payload: true });
      
      // 1. Get the IndexedDB database
      const db = await openDB('maintenance_db', 1);
      
      // 2. Clear all existing data
      const tx = db.transaction(
        ['maintenance_items', 'maintenance_logs', 'maintenance_bulletins', 'maintenance_stats'],
        'readwrite'
      );
      await tx.objectStore('maintenance_items').clear();
      await tx.objectStore('maintenance_logs').clear();
      await tx.objectStore('maintenance_bulletins').clear();
      await tx.objectStore('maintenance_stats').clear();
      await tx.done;
      
      // 3. Re-initialize with mock data
      await initializeMaintenanceDataIfEmpty(
        maintenanceItems, 
        maintenanceLogs,
        maintenanceBulletins,
        maintenanceStats
      );
      
      // 4. Reload all data
      const items = await getMaintenanceItemsFromDB();
      const logs = await getMaintenanceLogsFromDB();
      const bulletins = await getMaintenanceBulletinsFromDB();
      const statsData = await getMaintenanceStatsFromDB();
      
      console.log("Loaded items:", items.length);
      console.log("Loaded stats:", statsData);
      
      // 5. Update state
      dispatch({ type: 'SET_MAINTENANCE_ITEMS', payload: items });
      dispatch({ type: 'SET_MAINTENANCE_LOGS', payload: logs });
      dispatch({ type: 'SET_BULLETINS', payload: bulletins });
      dispatch({ type: 'SET_STATS', payload: statsData });
      dispatch({ type: 'SET_LOADING', payload: false });
      
      // Success toast
      toast({
        title: "Data Reinitialized",
        description: `Successfully loaded ${items.length} maintenance items and statistics.`,
        variant: "default",
      });
    } catch (err) {
      console.error("Failed to reinitialize data:", err);
      dispatch({ type: 'SET_LOADING', payload: false });
      
      // Error toast
      toast({
        title: "Error",
        description: "Failed to reinitialize data. Check console for details.",
        variant: "destructive",
      });
    }
  };

  // Load data from IndexedDB and initialize if needed
  useEffect(() => {
    const loadData = async () => {
      console.log("[Maintenance] Starting data load..."); // Log start
      dispatch({ type: 'SET_LOADING', payload: true });
      dispatch({ type: 'SET_ERROR', payload: null });
      
      try {
        // Initialize the database with mock data if empty
        await initializeMaintenanceDataIfEmpty(
          maintenanceItems,
          maintenanceLogs,
          maintenanceBulletins,
          maintenanceStats
        );
        console.log("[Maintenance] DB initialization check complete."); // Log init check
        
        // Load all data
        const items = await getMaintenanceItemsFromDB();
        console.log("[Maintenance] Loaded items:", items); // Log loaded items
        const logs = await getMaintenanceLogsFromDB();
        const bulletins = await getMaintenanceBulletinsFromDB();
        const statsData = await getMaintenanceStatsFromDB();
        console.log("[Maintenance] Loaded stats:", statsData); // Log loaded stats
        
        // Load inventory items for reference
        const inventory = await getInventoryItemsFromDB();
        setInventoryItems(inventory);
        
        // Update state
        dispatch({ type: 'SET_MAINTENANCE_ITEMS', payload: items });
        dispatch({ type: 'SET_MAINTENANCE_LOGS', payload: logs });
        dispatch({ type: 'SET_BULLETINS', payload: bulletins });
        dispatch({ type: 'SET_STATS', payload: statsData }); // Use fetched stats data
        
        console.log(`[Maintenance] Dispatched data to reducer. Items: ${items.length}`);
      } catch (err) {
        console.error("[Maintenance] Failed to load maintenance data:", err);
        dispatch({ type: 'SET_ERROR', payload: "Failed to load maintenance data" });
      } finally {
        dispatch({ type: 'SET_LOADING', payload: false });
        console.log("[Maintenance] Data load finished."); // Log end
      }
    };
    
    loadData();
  }, []); // Keep dependency array empty for initial load

  // Watch for ID prop changes to load specific items
  useEffect(() => {
    if (!state.isLoading && id) {
      const fetchItemDetails = async () => {
        try {
          const item = await getMaintenanceItemByIdFromDB(id);
          if (item) {
            setSelectedItem(item);
            setDetailsModalOpen(true);
            
            // Load logs for this item
            const logs = await getMaintenanceLogsByItemIdFromDB(id);
            setItemLogs(logs);
          }
        } catch (err) {
          console.error(`Failed to load maintenance item ${id}:`, err);
          toast({
            title: "Error",
            description: `Failed to load item details for ID: ${id}`,
            variant: "destructive",
          });
        }
      };
      
      fetchItemDetails();
    }
  }, [id, state.isLoading, toast]);

  // Filter AND sort maintenance items for current user
  const getFilteredAndSortedRequests = useCallback(() => {
    const currentUser = "CPT Rodriguez"; // Mock current user
    
    // Filtering logic
    const filtered = maintenanceItems.filter(item => {
      // Filter by user - show all items
      const isUserItem = true; // Show all items regardless of user assignment
      
      // Filter by search term
      const matchesSearch = 
        !searchTerm || 
        item.itemName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        item.serialNumber.toLowerCase().includes(searchTerm.toLowerCase()) ||
        item.description.toLowerCase().includes(searchTerm.toLowerCase());
      
      // Filter by category
      const matchesCategory = filterCategory === "all" || item.category === filterCategory;
      
      // Filter by status
      const matchesStatus = filterStatus === "all" || item.status === filterStatus;
      
      // Filter by priority
      const matchesPriority = filterPriority === "all" || item.priority === filterPriority;
      
      // Filter by date range
      let matchesDateRange = true;
      if (dateRange.from && isValid(dateRange.from)) {
        const reportedDate = new Date(item.reportedDate);
        matchesDateRange = reportedDate >= dateRange.from;
        
        if (dateRange.to && isValid(dateRange.to)) {
          matchesDateRange = matchesDateRange && reportedDate <= dateRange.to;
        }
      }
      
      return isUserItem && matchesSearch && matchesCategory && matchesStatus && matchesPriority && matchesDateRange;
    });

    // Sorting logic
    const sorted = [...filtered].sort((a, b) => {
      const field = sortConfig.field;
      if (field === 'none') return 0;

      let comparison = 0;
      const valueA = a[field];
      const valueB = b[field];

      // Handle different data types
      if (typeof valueA === 'string' && typeof valueB === 'string') {
        // General string comparison (covers itemName, serialNumber, category, etc.)
        comparison = valueA.localeCompare(valueB);
      } else if ((field === 'reportedDate' || field === 'scheduledDate' || field === 'completedDate') && 
                 typeof valueA === 'string' && typeof valueB === 'string' && valueA && valueB) {
        // Specific Date comparison - Ensure they are non-empty strings before creating Date
        try {
            const dateA = new Date(valueA).getTime();
            const dateB = new Date(valueB).getTime();
            // Check if dates are valid
            if (!isNaN(dateA) && !isNaN(dateB)) {
                 comparison = dateA - dateB;
            } else {
                 // Handle invalid date strings if necessary, e.g., treat as equal or push to end
                 comparison = 0; 
            }
        } catch (e) {
             console.error("Error comparing dates:", valueA, valueB, e);
             comparison = 0; // Fallback if Date constructor throws
        }
      } else if (typeof valueA === 'number' && typeof valueB === 'number') {
        comparison = valueA - valueB;
      } 
      // Add other type comparisons if needed (e.g., priority levels)
      else if (field === 'priority') {
          const priorityOrder = { critical: 4, high: 3, medium: 2, low: 1 };
          const priorityA = priorityOrder[a.priority] || 0;
          const priorityB = priorityOrder[b.priority] || 0;
          comparison = priorityA - priorityB;
      }

      return sortConfig.order === 'asc' ? comparison : -comparison;
    });

    return sorted;

  }, [
    maintenanceItems,
    searchTerm,
    filterCategory,
    filterStatus,
    filterPriority,
    dateRange,
    sortConfig // Add sortConfig dependency
  ]);

  // Get maintenance logs for a specific item
  const getItemMaintenanceLogs = useCallback(async (maintenanceId: string) => {
    setIsLoadingLogs(true);
    try {
      const logs = await getMaintenanceLogsByItemIdFromDB(maintenanceId);
      setItemLogs(logs);
    } catch (err) {
      console.error("Failed to load maintenance logs:", err);
      toast({
        title: "Error",
        description: "Failed to load maintenance history",
        variant: "destructive",
      });
    } finally {
      setIsLoadingLogs(false);
    }
  }, [toast]);

  // Handler for viewing item details
  const handleViewDetails = useCallback(async (item: MaintenanceItem) => {
    setSelectedItem(item);
    setDetailsModalOpen(true);
    await getItemMaintenanceLogs(item.id);
  }, [getItemMaintenanceLogs]);

  // Handler for starting maintenance
  const handleStartMaintenance = useCallback(async (item: MaintenanceItem) => {
    setIsSavingStatus(true);
    try {
      const result = await updateMaintenanceItemStatusInDB(
        item.id, 
        'in-progress',
        "CPT Rodriguez" // Mock current user
      );
      
      // Update local state
      dispatch({ 
        type: 'UPDATE_MAINTENANCE_ITEM', 
        payload: result.item 
      });
      
      // Update stats if we have them
      if (state.stats) {
        dispatch({
          type: 'SET_STATS',
          payload: await getMaintenanceStatsFromDB()
        });
      }
      
      // Refresh logs if viewing details
      if (selectedItem && selectedItem.id === item.id) {
        await getItemMaintenanceLogs(item.id);
      }
      
      // Show toast
      toast({
        title: "Maintenance Started",
        description: `Maintenance for ${item.itemName} has been started.`,
        variant: "default",
      });
    } catch (err) {
      console.error("Failed to start maintenance:", err);
      toast({
        title: "Error",
        description: "Failed to update maintenance status",
        variant: "destructive",
      });
    } finally {
      setIsSavingStatus(false);
    }
  }, [dispatch, getItemMaintenanceLogs, selectedItem, state.stats, toast]);

  // Handler for completing maintenance
  const handleCompleteMaintenance = useCallback(async (item: MaintenanceItem) => {
    setIsSavingStatus(true);
    try {
      const result = await updateMaintenanceItemStatusInDB(
        item.id, 
        'completed',
        "CPT Rodriguez" // Mock current user
      );
      
      // Update local state
      dispatch({ 
        type: 'UPDATE_MAINTENANCE_ITEM', 
        payload: result.item 
      });
      
      // Update stats if we have them
      if (state.stats) {
        dispatch({
          type: 'SET_STATS',
          payload: await getMaintenanceStatsFromDB()
        });
      }
      
      // Refresh logs if viewing details
      if (selectedItem && selectedItem.id === item.id) {
        await getItemMaintenanceLogs(item.id);
      }
      
      // Show toast
      toast({
        title: "Maintenance Completed",
        description: `Maintenance for ${item.itemName} has been marked as complete.`,
        variant: "default",
      });
      
      // Close modal if open
      setDetailsModalOpen(false);
    } catch (err) {
      console.error("Failed to complete maintenance:", err);
      toast({
        title: "Error",
        description: "Failed to update maintenance status",
        variant: "destructive",
      });
    } finally {
      setIsSavingStatus(false);
    }
  }, [dispatch, getItemMaintenanceLogs, selectedItem, state.stats, toast]);

  // Handler for opening new maintenance request modal
  const handleNewRequestClick = useCallback(() => {
    setSelectedInventoryItem(null);
    setNewRequestModalOpen(true);
  }, []);

  // Handler for submitting new maintenance request
  const handleSubmitNewRequest = useCallback(async (formData: any) => {
    dispatch({ type: 'SET_SUBMITTING', payload: true });
    
    try {
      // Simulate network delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Create new maintenance item
      const newItem: MaintenanceItem = {
        id: `m_${uuidv4()}`,
        itemId: selectedInventoryItem?.id || formData.itemId || '',
        itemName: formData.itemName,
        serialNumber: formData.serialNumber,
        category: formData.category,
        maintenanceType: formData.maintenanceType,
        status: 'scheduled',
        priority: formData.priority,
        description: formData.description,
        reportedBy: "CPT Rodriguez", // Mock current user
        reportedDate: new Date().toISOString().split('T')[0],
        scheduledDate: formData.scheduledDate || undefined,
        notes: ''
      };
      
      // Add to IndexedDB
      const savedItem = await addMaintenanceItemToDB(newItem);
      
      // Add to local state
      dispatch({ type: 'ADD_MAINTENANCE_ITEM', payload: savedItem });
      
      // Close modal
      setNewRequestModalOpen(false);
      
      // Show toast
      toast({
        title: "Request Submitted",
        description: "Your maintenance request has been submitted successfully.",
        variant: "default",
      });
      
      // Reset selected inventory item
      setSelectedInventoryItem(null);
    } catch (err) {
      console.error("Failed to submit maintenance request:", err);
      toast({
        title: "Error",
        description: "Failed to submit maintenance request",
        variant: "destructive",
      });
    } finally {
      dispatch({ type: 'SET_SUBMITTING', payload: false });
    }
  }, [dispatch, selectedInventoryItem, toast]);

  // Handler for adding a new bulletin
  const handleAddBulletinClick = useCallback(() => {
    setAddBulletinModalOpen(true);
  }, []);

  // Handler for submitting a new bulletin
  const handleSubmitBulletin = useCallback(async (formData: any) => {
    dispatch({ type: 'SET_SUBMITTING', payload: true });
    
    try {
      // Simulate network delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Create new bulletin
      const newBulletin: MaintenanceBulletin = {
        id: `b_${uuidv4()}`,
        title: formData.title,
        message: formData.message,
        category: formData.category,
        postedBy: "CPT Rodriguez", // Mock current user
        postedDate: new Date().toISOString().split('T')[0],
        resolved: false,
        affectedItems: formData.affectedItems ? formData.affectedItems.split(',').map((s: string) => s.trim()) : undefined
      };
      
      // Add to IndexedDB
      const savedBulletin = await addMaintenanceBulletinToDB(newBulletin);
      
      // Add to local state
      dispatch({ type: 'ADD_BULLETIN', payload: savedBulletin });
      
      // Close modal
      setAddBulletinModalOpen(false);
      
      // Show toast
      toast({
        title: "Bulletin Posted",
        description: "Your maintenance bulletin has been posted successfully.",
        variant: "default",
      });
    } catch (err) {
      console.error("Failed to submit bulletin:", err);
      toast({
        title: "Error",
        description: "Failed to post maintenance bulletin",
        variant: "destructive",
      });
    } finally {
      dispatch({ type: 'SET_SUBMITTING', payload: false });
    }
  }, [dispatch, toast]);

  // Handler for resetting filters
  const handleResetFilters = useCallback(() => {
    dispatch({ type: 'RESET_FILTERS' });
  }, [dispatch]);

  // Handler for sorting
  const handleSort = useCallback((field: keyof MaintenanceItem | 'none') => {
    dispatch({ type: 'SET_SORT_CONFIG', payload: field });
  }, [dispatch]);

  // Handler for dashboard stat clicks
  const handleStatClick = useCallback((filterType: 'status', value: string) => {
    if (filterType === 'status') {
      dispatch({ type: 'SET_FILTER_STATUS', payload: value });
      dispatch({ type: 'SET_SELECTED_TAB', payload: 'my-requests' }); // Switch to the list view
    }
    // Add other filter types here if needed later
  }, [dispatch]);

  // Log state just before rendering
  // console.log("[Maintenance] Rendering with state:", state);
  // Log the items array being generated for the list
  const itemsForList = getFilteredAndSortedRequests();
  // console.log("[Maintenance] Items passed to MaintenanceList:", itemsForList);

  // Page actions
  const actions = (
    <div className="flex gap-2">
        <Button 
          onClick={handleNewRequestClick} 
          size="sm"
          variant="blue"
          className="h-9 px-3 flex items-center gap-1.5"
          disabled={state.isSubmitting}
        >
            <Plus className="h-4 w-4" />
            <span className="text-xs uppercase tracking-wider">New Maintenance Request</span>
        </Button>
        <Button 
            onClick={() => setShowCalibrationManager(!showCalibrationManager)}
            variant="blue"
            size="sm"
            className={`h-9 px-3 flex items-center gap-1.5 ${showCalibrationManager ? 'bg-secondary hover:bg-secondary/80 text-secondary-foreground' : ''}`}
        >
            <Calendar className="h-4 w-4" />
            <span className="text-xs uppercase tracking-wider">{showCalibrationManager ? "Hide Calibration" : "Show Calibration"}</span>
        </Button>
    </div>
  );

  return (
    <PageWrapper withPadding={true}>
      {/* Header section with 8VC style formatting */}
      <div className="pt-16 pb-10">
        {/* Category label - Small all-caps category label */}
        <div className="text-xs uppercase tracking-wider font-medium mb-1 text-muted-foreground">
          MAINTENANCE
        </div>
        
        {/* Main title - following 8VC typography */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between space-y-4 sm:space-y-0">
          <div>
            <h1 className="text-3xl font-light tracking-tight mb-1">Equipment Maintenance</h1>
            <p className="text-sm text-muted-foreground">Submit, track, and manage maintenance requests for your equipment</p>
          </div>
          {actions}
        </div>
      </div>

      {/* Conditionally render the main Tabs OR the Calibration Manager */}
      {!showCalibrationManager ? (
          <Tabs value={state.selectedTab} onValueChange={(value: any) => dispatch({ type: 'SET_SELECTED_TAB', payload: value as 'my-requests' | 'dashboard' | 'bulletins' })} className="w-full">
             <TabsList className="grid grid-cols-3 w-full rounded-none h-10 mb-6 border border-border">
               <TabsTrigger value="my-requests" className="text-xs uppercase tracking-wider rounded-none">My Requests</TabsTrigger>
               <TabsTrigger value="dashboard" className="text-xs uppercase tracking-wider rounded-none">Dashboard</TabsTrigger>
               <TabsTrigger value="bulletins" className="text-xs uppercase tracking-wider rounded-none">Bulletins</TabsTrigger>
             </TabsList>
             <TabsContent value="my-requests">
               <MaintenanceList
                 items={itemsForList}
                 searchTerm={searchTerm}
                 setSearchTerm={(term) => dispatch({ type: 'SET_SEARCH_TERM', payload: term })}
                 filterCategory={filterCategory}
                 setFilterCategory={(category) => dispatch({ type: 'SET_FILTER_CATEGORY', payload: category })}
                 filterStatus={filterStatus}
                 setFilterStatus={(status) => dispatch({ type: 'SET_FILTER_STATUS', payload: status })}
                 filterPriority={filterPriority}
                 setFilterPriority={(priority) => dispatch({ type: 'SET_FILTER_PRIORITY', payload: priority })}
                 onViewDetails={handleViewDetails}
                 onStartMaintenance={handleStartMaintenance}
                 onCompleteMaintenance={handleCompleteMaintenance}
                 onResetFilters={handleResetFilters}
                 sortConfig={sortConfig}
                 onSort={handleSort}
               />
             </TabsContent>
             <TabsContent value="dashboard">
               <MaintenanceDashboard 
                 stats={stats}
                 onStatClick={handleStatClick}
               />
             </TabsContent>
             <TabsContent value="bulletins">
               <MaintenanceBulletinBoard bulletins={state.bulletins} onAddBulletin={handleAddBulletinClick} />
             </TabsContent>
          </Tabs>
      ) : (
          // Render the Calibration Manager when toggled
         <div className="mt-6"> 
           <CalibrationManager />
         </div>
      )}
      
      {/* Maintenance Details Modal */}
      {selectedItem && (
        <Dialog open={detailsModalOpen} onOpenChange={setDetailsModalOpen}>
          <DialogContent className="max-w-3xl max-h-[85vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle className="text-xl flex items-center">
                <Wrench className="mr-2 h-5 w-5" />
                Maintenance Request Details
              </DialogTitle>
              <DialogDescription>
                Tracking information for maintenance request #{selectedItem.id.substring(1)}
              </DialogDescription>
            </DialogHeader>
            
            {/* Status badges at the top */}
            <div className="flex flex-wrap gap-2 mb-4">
              <MaintenanceStatusBadge status={selectedItem.status} size="lg" />
              <MaintenancePriorityBadge priority={selectedItem.priority} size="lg" />
              {selectedItem.maintenanceType && (
                <Badge variant="outline" className="text-sm px-3 py-1 capitalize">
                  {selectedItem.maintenanceType} Maintenance
                </Badge>
              )}
            </div>

            <div className="space-y-6">
              {/* Progress indicator for in-progress items */}
              {selectedItem.status === 'in-progress' && (
                <div className="bg-blue-50 dark:bg-blue-900/10 p-4 rounded-lg">
                  <div className="flex justify-between mb-2">
                    <h3 className="font-medium text-blue-800 dark:text-blue-400">Current Progress</h3>
                    <span className="text-blue-800 dark:text-blue-400">60%</span>
                  </div>
                  <Progress value={60} className="h-2 mb-2" />
                  <p className="text-sm text-blue-700 dark:text-blue-300">
                    <Clock className="inline h-3 w-3 mr-1" /> 
                    Estimated completion: {selectedItem.estimatedCompletionTime || "Unknown"}
                  </p>
                </div>
              )}
              
              {/* Item Information */}
              <div className="border rounded-md p-4">
                <h3 className="text-lg font-medium mb-3 flex items-center">
                  <Tag className="mr-2 h-4 w-4" />
                  Equipment Information
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div>
                    <p className="text-sm text-muted-foreground">Item Name</p>
                    <p className="font-medium">{selectedItem.itemName}</p>
                  </div>
                  <div>
                    <p className="text-sm text-muted-foreground">Serial Number</p>
                    <p className="font-medium">{selectedItem.serialNumber}</p>
                  </div>
                  <div>
                    <p className="text-sm text-muted-foreground">Category</p>
                    <p className="font-medium capitalize">{selectedItem.category}</p>
                  </div>
                </div>
              </div>
              
              {/* Issue Description */}
              <div className="border rounded-md p-4">
                <h3 className="text-lg font-medium mb-3 flex items-center">
                  <MailQuestion className="mr-2 h-4 w-4" />
                  Reported Issue
                </h3>
                <p className="mb-3">{selectedItem.description}</p>
                <div className="flex flex-col md:flex-row md:items-center gap-3 text-sm text-muted-foreground">
                  <span>Reported by: <span className="font-medium">{selectedItem.reportedBy}</span></span>
                  <span className="hidden md:inline">•</span>
                  <span>Date: <span className="font-medium">{selectedItem.reportedDate}</span></span>
                </div>
              </div>
              
              {/* Maintenance Schedule - Enhanced Timeline */}
              <div className="border rounded-none p-4 shadow-none bg-card">
                <h3 className="text-lg font-medium mb-4 flex items-center">
                  <CalendarClock className="mr-2 h-4 w-4 text-primary" />
                  Maintenance Timeline
                </h3>
                <div className="relative pl-6 space-y-6 border-l-2 border-border ml-3">
                  {/* Step 1: Reported */}
                  <div className="absolute -left-[13px] top-1 w-6 h-6 rounded-full bg-blue-500 border-4 border-card flex items-center justify-center">
                     <FileText className="h-3 w-3 text-white" />
                  </div>
                  <div>
                      <p className="text-sm font-medium">Request Reported</p>
                      <p className="text-xs text-muted-foreground">On: {selectedItem.reportedDate ? format(new Date(selectedItem.reportedDate), 'PPP') : 'N/A'}</p>
                  </div>
                  
                  {/* Step 2: Scheduled */}
                  <div className={`absolute -left-[13px] top-[calc(33%_+_8px)] w-6 h-6 rounded-full border-4 border-card flex items-center justify-center ${selectedItem.scheduledDate ? 'bg-amber-500' : 'bg-gray-400'}`}>
                     <Calendar className="h-3 w-3 text-white" />
                  </div>
                  <div>
                      <p className="text-sm font-medium">Maintenance Scheduled</p>
                      <p className="text-xs text-muted-foreground">For: {selectedItem.scheduledDate ? format(new Date(selectedItem.scheduledDate), 'PPP') : 'Not scheduled yet'}</p>
                  </div>
                  
                   {/* Step 3: Started (Optional - Infer from logs or add explicit field later) */}
                   {/* Add logic here if a 'startedDate' or similar exists */}

                   {/* Step 4: Completed */}
                  <div className={`absolute -left-[13px] top-[calc(66%_+_16px)] w-6 h-6 rounded-full border-4 border-card flex items-center justify-center ${selectedItem.completedDate ? 'bg-green-500' : 'bg-gray-400'}`}>
                     <CheckCircle className="h-3 w-3 text-white" />
                  </div>
                  <div>
                      <p className="text-sm font-medium">Maintenance Completed</p>
                      <p className="text-xs text-muted-foreground">On: {selectedItem.completedDate ? format(new Date(selectedItem.completedDate), 'PPP') : 'Pending'}</p>
                  </div>
                </div>

                {/* Assigned Technician and Notes remain below the timeline */}
                <div className="mt-6 pt-4 border-t">
                  <p className="text-sm text-muted-foreground">Assigned Technician</p>
                  <p className="font-medium mb-3">{selectedItem.assignedTo || "Not assigned yet"}</p>
                  
                  {selectedItem.notes && (
                    <div className="bg-muted/30 p-3 rounded-md">
                      <p className="text-sm font-medium mb-1">Technician Notes:</p>
                      <p className="text-sm whitespace-pre-wrap">{selectedItem.notes}</p> {/* Use whitespace-pre-wrap */}
                    </div>
                  )}
                </div>
              </div>
              
              {/* Parts Information */}
              {selectedItem.partsRequired && selectedItem.partsRequired.length > 0 && (
                <div className="border rounded-md p-4">
                  <h3 className="text-lg font-medium mb-3 flex items-center">
                    <Hammer className="mr-2 h-4 w-4" />
                    Required Parts
                  </h3>
                  <div className="overflow-x-auto">
                    <table className="w-full min-w-[500px]">
                      <thead>
                        <tr className="border-b">
                          <th className="text-left py-2 font-medium">Part Name</th>
                          <th className="text-left py-2 font-medium">Part Number</th>
                          <th className="text-center py-2 font-medium">Quantity</th>
                          <th className="text-right py-2 font-medium">Status</th>
                        </tr>
                      </thead>
                      <tbody>
                        {selectedItem.partsRequired.map(part => (
                          <tr key={part.id} className="border-b">
                            <td className="py-2">{part.name}</td>
                            <td className="py-2">{part.partNumber}</td>
                            <td className="py-2 text-center">{part.quantity}</td>
                            <td className="py-2 text-right">
                              {part.available ? (
                                <Badge className="bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400">Available</Badge>
                              ) : (
                                <div>
                                  <Badge className="bg-amber-100 text-amber-800 dark:bg-amber-900/20 dark:text-amber-400">On Order</Badge>
                                  {part.estimatedArrival && (
                                    <p className="text-xs text-gray-500 mt-1">ETA: {part.estimatedArrival}</p>
                                  )}
                                </div>
                              )}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
              
              {/* Maintenance History */}
              <div className="border rounded-md p-4">
                <h3 className="text-lg font-medium mb-3 flex items-center">
                  <History className="mr-2 h-4 w-4" />
                  Maintenance History
                </h3>
                <div className="space-y-3">
                  {itemLogs.length === 0 ? (
                    <p className="text-muted-foreground text-sm">No history records available</p>
                  ) : (
                    itemLogs.map(log => (
                      <div key={log.id} className="flex items-start gap-3 pb-3 border-b last:border-b-0">
                        <div className="bg-primary/10 p-2 rounded-full mt-1">
                          {log.action === 'created' && <Plus className="h-4 w-4 text-primary" />}
                          {log.action === 'updated' && <FileText className="h-4 w-4 text-primary" />}
                          {log.action === 'status-change' && <Activity className="h-4 w-4 text-primary" />}
                          {log.action === 'parts-ordered' && <Truck className="h-4 w-4 text-primary" />}
                          {log.action === 'parts-received' && <Package className="h-4 w-4 text-primary" />}
                          {log.action === 'completed' && <CheckCircle className="h-4 w-4 text-primary" />}
                        </div>
                        <div className="flex-1">
                          <div className="flex flex-wrap justify-between gap-2">
                            <p className="font-medium text-sm">
                              <span className="capitalize">{log.action.replace('-', ' ')}</span>
                            </p>
                            <p className="text-xs text-gray-500">{log.timestamp}</p>
                          </div>
                          <p className="text-sm">{log.notes}</p>
                          <p className="text-xs text-muted-foreground mt-1">By: {log.performedBy}</p>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>
            
            <DialogFooter className="gap-2 flex-col sm:flex-row">
              {/* Request actions */}
              <div className="flex gap-2 flex-1 justify-start">
                {selectedItem.status === 'in-progress' && (
                  <Button variant="outline" className="text-blue-600 border-blue-600">
                    <MessageSquare className="h-4 w-4 mr-2" />
                    Send Message
                  </Button>
                )}
              </div>
              
              {/* Status change actions */}
              <div className="flex gap-2">
                <Button variant="outline" onClick={() => setDetailsModalOpen(false)}>
                  Close
                </Button>
                
                {selectedItem.status === 'scheduled' && (
                  <Button 
                    size="sm"
                    variant="blue"
                    className="h-9 px-3 flex items-center gap-1.5"
                    onClick={() => {
                      handleStartMaintenance(selectedItem);
                      setDetailsModalOpen(false);
                    }}
                  >
                    <Play className="h-4 w-4 mr-2" />
                    <span className="text-xs uppercase tracking-wider">Start</span>
                  </Button>
                )}
                
                {selectedItem.status === 'in-progress' && (
                  <Button 
                    className="bg-green-600 hover:bg-green-700"
                    onClick={() => {
                      handleCompleteMaintenance(selectedItem);
                      setDetailsModalOpen(false);
                    }}
                  >
                    <CheckCircle className="h-4 w-4 mr-2" />
                    Mark as Complete
                  </Button>
                )}
              </div>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      )}

      {/* New Maintenance Request Modal */}
      <Dialog open={newRequestModalOpen} onOpenChange={setNewRequestModalOpen}>
        <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="text-xl flex items-center">
              <CirclePlus className="mr-2 h-5 w-5" />
              New Maintenance Request
            </DialogTitle>
            <DialogDescription>
              Submit a maintenance request for your equipment
            </DialogDescription>
          </DialogHeader>
          
          <form onSubmit={(e) => {
            e.preventDefault();
            const formData = new FormData(e.currentTarget);
            const data = {
              itemName: formData.get('itemName') as string,
              serialNumber: formData.get('serialNumber') as string,
              category: formData.get('category') as string,
              maintenanceType: formData.get('maintenanceType') as string,
              priority: formData.get('priority') as string,
              description: formData.get('description') as string,
              scheduledDate: formData.get('scheduledDate') as string
            };
            handleSubmitNewRequest(data);
          }}>
            <div className="grid gap-4 py-2">
              {/* Equipment Selection Method */}
              <Tabs defaultValue="inventory" className="w-full">
                <TabsList className="grid grid-cols-2 mb-4">
                  <TabsTrigger value="inventory">
                    <LinkIcon className="h-4 w-4 mr-2" />
                    Link Inventory Item
                  </TabsTrigger>
                  <TabsTrigger value="manual">
                    <FileText className="h-4 w-4 mr-2" />
                    Manual Entry
                  </TabsTrigger>
                </TabsList>
                
                <TabsContent value="inventory">
                  <Card className="mb-4 border-border shadow-none rounded-none">
                    <CardContent className="py-4">
                      <div className="space-y-4">
                        <Label className="text-sm font-medium">Select Equipment from Inventory</Label>
                        <div className="relative">
                          <Search className="absolute left-2.5 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                          <Input 
                            placeholder="Search inventory by name or serial number..."
                            value={modalInventorySearchTerm}
                            onChange={(e) => setModalInventorySearchTerm(e.target.value)}
                            className="pl-8 w-full mb-2 h-9 rounded-none"
                          />
                        </div>
                        
                        <div className="h-[200px] overflow-y-auto border rounded-none">
                          {isLoading ? (
                            <div className="p-4 flex flex-col gap-2">
                              <Skeleton className="h-8 w-full" />
                              <Skeleton className="h-8 w-full" />
                              <Skeleton className="h-8 w-full" />
                            </div>
                          ) : (
                            () => {
                               const filteredInventory = inventoryItems.filter(item => 
                                  !modalInventorySearchTerm ||
                                  item.name.toLowerCase().includes(modalInventorySearchTerm.toLowerCase()) ||
                                  item.serialNumber.toLowerCase().includes(modalInventorySearchTerm.toLowerCase())
                               );
                               return filteredInventory.length === 0 ? (
                                <div className="p-4 text-center text-muted-foreground text-sm">
                                  No inventory items found matching "{modalInventorySearchTerm}".
                                </div>
                               ) : (
                                <div className="divide-y divide-border">
                                  {filteredInventory.map((item) => (
                                    <div 
                                      key={item.id}
                                      className={`p-3 hover:bg-muted/50 cursor-pointer ${selectedInventoryItem?.id === item.id ? 'bg-muted/50' : ''}`}
                                      onClick={() => setSelectedInventoryItem(item)}
                                    >
                                      <div className="font-medium text-sm">{item.name}</div>
                                      <div className="text-xs text-muted-foreground font-mono">SN: {item.serialNumber}</div>
                                    </div>
                                  ))}
                                </div>
                               );
                            }
                          )()}
                        </div>
                        
                        {selectedInventoryItem && (
                          <div className="bg-muted/30 p-3 border border-border rounded-md">
                            <div className="flex items-start justify-between">
                              <div>
                                <h4 className="font-medium text-sm">Selected Item</h4>
                                <p className="text-sm">{selectedInventoryItem.name}</p>
                                <p className="text-xs text-muted-foreground font-mono">SN: {selectedInventoryItem.serialNumber}</p>
                              </div>
                              <Button 
                                type="button"
                                variant="ghost" 
                                size="sm" 
                                onClick={() => setSelectedInventoryItem(null)}
                                className="h-8 w-8 p-0"
                              >
                                <XIcon className="h-4 w-4" />
                              </Button>
                            </div>
                          </div>
                        )}
                      </div>
                    </CardContent>
                  </Card>
                </TabsContent>
                
                <TabsContent value="manual">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="itemName" className="text-sm font-medium">Item Name</Label>
                      <Input id="itemName" name="itemName" placeholder="Enter item name" />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="serialNumber" className="text-sm font-medium">Serial Number</Label>
                      <Input id="serialNumber" name="serialNumber" placeholder="Enter serial number" />
                    </div>
                  </div>
                </TabsContent>
              </Tabs>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="category" className="text-sm font-medium">Category</Label>
                  <Select name="category" defaultValue="other">
                    <SelectTrigger id="category">
                      <SelectValue placeholder="Select category" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="weapon">Weapon</SelectItem>
                      <SelectItem value="vehicle">Vehicle</SelectItem>
                      <SelectItem value="communication">Communication</SelectItem>
                      <SelectItem value="optics">Optics</SelectItem>
                      <SelectItem value="other">Other</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="maintenanceType" className="text-sm font-medium">Maintenance Type</Label>
                  <Select name="maintenanceType" defaultValue="corrective">
                    <SelectTrigger id="maintenanceType">
                      <SelectValue placeholder="Select type" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="scheduled">Scheduled</SelectItem>
                      <SelectItem value="corrective">Corrective</SelectItem>
                      <SelectItem value="preventive">Preventive</SelectItem>
                      <SelectItem value="emergency">Emergency</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="priority" className="text-sm font-medium">Priority</Label>
                  <Select name="priority" defaultValue="medium">
                    <SelectTrigger id="priority">
                      <SelectValue placeholder="Select priority" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="low">Low</SelectItem>
                      <SelectItem value="medium">Medium</SelectItem>
                      <SelectItem value="high">High</SelectItem>
                      <SelectItem value="critical">Critical</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="scheduledDate" className="text-sm font-medium">Preferred Date (if any)</Label>
                  <div className="relative">
                    <Popover>
                      <PopoverTrigger asChild>
                        <Button
                          variant="outline"
                          className="w-full justify-start text-left font-normal"
                        >
                          <CalendarIcon className="mr-2 h-4 w-4" />
                          <span>Pick a date</span>
                        </Button>
                      </PopoverTrigger>
                      <PopoverContent className="w-auto p-0">
                        <CalendarComponent
                          mode="single"
                          initialFocus
                          onSelect={(date) => {
                            if (date) {
                              const input = document.getElementById('scheduledDate') as HTMLInputElement;
                              if (input) {
                                input.value = date.toISOString().split('T')[0];
                              }
                            }
                          }}
                        />
                      </PopoverContent>
                    </Popover>
                    <Input 
                      id="scheduledDate" 
                      name="scheduledDate" 
                      type="hidden"
                    />
                  </div>
                </div>
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="description" className="text-sm font-medium">Description of Issue</Label>
                <Textarea 
                  id="description"
                  name="description"
                  placeholder="Describe the maintenance needed or issue observed in detail. Include when the issue started and any troubleshooting steps already taken." 
                  className="min-h-[120px]"
                />
              </div>
              
              <div className="space-y-2">
                <Label className="text-sm font-medium flex items-center">
                  <Paperclip className="h-4 w-4 mr-2" />
                  Attachments (Optional)
                </Label>
                <div className="border-2 border-dashed rounded-md p-4 text-center">
                  <CameraIcon className="h-8 w-8 mx-auto mb-2 text-muted-foreground" />
                  <p className="text-sm text-muted-foreground mb-2">Drag & drop photos or click to browse</p>
                  <Button variant="outline" size="sm" type="button">
                    <UploadIcon className="h-4 w-4 mr-2" />
                    Upload Image
                  </Button>
                </div>
              </div>
              
              <Card className="bg-amber-50 text-amber-800 dark:bg-amber-900/10 dark:text-amber-400 border-amber-200 dark:border-amber-800">
                <CardContent className="py-3 px-4 flex items-start gap-3">
                  <AlertTriangle className="h-5 w-5 text-amber-500 mt-0.5 flex-shrink-0" />
                  <div>
                    <h4 className="font-medium text-amber-800 dark:text-amber-400">Important Notice</h4>
                    <p className="text-sm mt-1">For critical equipment affecting operational readiness, please also notify your supervisor after submitting this request.</p>
                  </div>
                </CardContent>
              </Card>
            </div>
            
            <DialogFooter className="gap-2 mt-4">
              <Button variant="outline" type="button" onClick={() => setNewRequestModalOpen(false)}>
                Cancel
              </Button>
              <Button 
                type="submit"
                variant="blue"
                className="h-9 px-3 flex items-center gap-1.5"
                disabled={state.isSubmitting}
              >
                {state.isSubmitting ? (
                  <>
                    <span className="h-4 w-4 border-t-2 border-b-2 border-white rounded-full animate-spin mr-2" />
                    <span className="text-xs uppercase tracking-wider">Processing...</span>
                  </>
                ) : (
                  <>
                    <Send className="h-4 w-4 mr-2" />
                    <span className="text-xs uppercase tracking-wider">Submit Request</span>
                  </>
                )}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
      
      {/* Post Maintenance Bulletin Modal */}
      <Dialog open={addBulletinModalOpen} onOpenChange={setAddBulletinModalOpen}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle className="text-xl flex items-center">
              <Bell className="mr-2 h-5 w-5" />
              Post Maintenance Bulletin
            </DialogTitle>
            <DialogDescription>
              Share important maintenance updates with personnel
            </DialogDescription>
          </DialogHeader>
          
          <div className="grid gap-4 py-2">
            <div className="space-y-2">
              <label className="text-sm font-medium">Bulletin Title</label>
              <Input placeholder="Enter bulletin title" />
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <label className="text-sm font-medium">Category</label>
                <Select>
                  <SelectTrigger>
                    <SelectValue placeholder="Select category" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="parts-shortage">Parts Shortage</SelectItem>
                    <SelectItem value="delay">Maintenance Delay</SelectItem>
                    <SelectItem value="update">Process Update</SelectItem>
                    <SelectItem value="facility">Facility Notice</SelectItem>
                    <SelectItem value="general">General Information</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <label className="text-sm font-medium">Priority</label>
                <Select>
                  <SelectTrigger>
                    <SelectValue placeholder="Select priority" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="low">Low</SelectItem>
                    <SelectItem value="medium">Medium</SelectItem>
                    <SelectItem value="high">High</SelectItem>
                    <SelectItem value="critical">Critical</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            
            <div className="space-y-2">
              <label className="text-sm font-medium">Message</label>
              <Textarea 
                placeholder="Provide detailed information about the maintenance update" 
                className="min-h-[120px]"
              />
            </div>
            
            <div className="space-y-2">
              <label className="text-sm font-medium">Affected Equipment (Optional)</label>
              <Input placeholder="Enter equipment types affected by this bulletin" />
              <p className="text-xs text-muted-foreground">Separate multiple items with commas</p>
            </div>
            
            <div className="space-y-2">
              <label className="text-sm font-medium">Expected Resolution Date (Optional)</label>
              <Input type="date" />
            </div>
          </div>
          
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setAddBulletinModalOpen(false)}>
              Cancel
            </Button>
            <Button 
              onClick={handleSubmitBulletin}
              className="bg-[#3B5BDB] hover:bg-[#364FC7] w-full"
            >
              <div className="flex items-center justify-center w-full">
                <Bell className="h-4 w-4 mr-2" />
                Post Bulletin
              </div>
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PageWrapper>
  );
};

export default Maintenance;