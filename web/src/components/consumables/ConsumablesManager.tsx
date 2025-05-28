import { useState, useEffect, useMemo } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { format } from 'date-fns';
import { ConsumableItem } from '@/types';
import { 
  getConsumablesFromDB, 
  saveConsumablesToDB, 
  deleteConsumableFromDB,
  updateConsumableQuantity,
  addConsumptionHistoryEntryToDB,
  getConsumptionHistoryByItemFromDB,
  ConsumptionHistoryEntry
} from '@/lib/idb';
import { consumableCategories } from '@/lib/consumablesData';

// UI Components
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Progress } from "@/components/ui/progress";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { useToast } from "@/hooks/use-toast";

// Icons
import { Plus, Search, Filter, Loader2, Edit, X, Trash2, RotateCcw, Archive, Truck, Package, ShoppingCart, AlertTriangle, History } from 'lucide-react';

interface ConsumableFormData {
  id?: string;
  name: string;
  nsn: string;
  category: string;
  unit: string;
  currentQuantity: number;
  minimumQuantity: number;
  location: string;
  expirationDate?: string;
  notes?: string;
}

interface ConsumptionFormData {
  quantity: number;
  issuedTo: string;
  issuedBy: string;
  notes: string;
}

const ConsumablesManager = () => {
  // State
  const [consumables, setConsumables] = useState<ConsumableItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [quantityFilter, setQuantityFilter] = useState('all'); // 'all', 'low', 'ok'
  
  // Modal state
  const [addModalOpen, setAddModalOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<ConsumableItem | null>(null);
  const [formData, setFormData] = useState<ConsumableFormData>({
    name: '',
    nsn: '',
    category: '',
    unit: '',
    currentQuantity: 0,
    minimumQuantity: 0,
    location: '',
  });
  
  // Consumption modal state
  const [consumeModalOpen, setConsumeModalOpen] = useState(false);
  const [consumingItem, setConsumingItem] = useState<ConsumableItem | null>(null);
  const [consumptionData, setConsumptionData] = useState<ConsumptionFormData>({
    quantity: 1,
    issuedTo: '',
    issuedBy: '',
    notes: '',
  });
  
  // Restock modal state
  const [restockModalOpen, setRestockModalOpen] = useState(false);
  const [restockingItem, setRestockingItem] = useState<ConsumableItem | null>(null);
  const [restockQuantity, setRestockQuantity] = useState<number>(0);
  
  // History modal state
  const [historyModalOpen, setHistoryModalOpen] = useState(false);
  const [historyItem, setHistoryItem] = useState<ConsumableItem | null>(null);
  const [consumptionHistory, setConsumptionHistory] = useState<ConsumptionHistoryEntry[]>([]);
  
  const { toast } = useToast();

  // Load consumables from IndexedDB
  useEffect(() => {
    const loadConsumables = async () => {
      try {
        setLoading(true);
        const data = await getConsumablesFromDB();
        setConsumables(data);
      } catch (error) {
        console.error('Error loading consumables:', error);
        toast({
          title: 'Error',
          description: 'Failed to load consumables.',
          variant: 'destructive',
        });
      } finally {
        setLoading(false);
      }
    };

    loadConsumables();
  }, [toast]);

  // Filtered consumables
  const filteredConsumables = useMemo(() => {
    return consumables
      .filter(item => 
        item.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        item.nsn?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        item.location?.toLowerCase().includes(searchTerm.toLowerCase())
      )
      .filter(item => 
        categoryFilter === 'all' || item.category === categoryFilter
      )
      .filter(item => {
        if (quantityFilter === 'all') return true;
        if (quantityFilter === 'low') return item.currentQuantity <= item.minimumQuantity;
        if (quantityFilter === 'ok') return item.currentQuantity > item.minimumQuantity;
        return true;
      });
  }, [consumables, searchTerm, categoryFilter, quantityFilter]);

  // Stats for dashboard
  const consumableStats = useMemo(() => {
    const totalItems = consumables.length;
    const lowStockItems = consumables.filter(item => item.currentQuantity <= item.minimumQuantity);
    const lowStockCount = lowStockItems.length;
    const lowStockPercentage = totalItems > 0 ? Math.round((lowStockCount / totalItems) * 100) : 0;
    
    // Get a breakdown by category
    const categoryBreakdown = consumableCategories.map(category => {
      const count = consumables.filter(item => item.category === category.name).length;
      return { ...category, count };
    });
    
    return {
      totalItems,
      lowStockCount,
      lowStockPercentage,
      categoryBreakdown
    };
  }, [consumables]);

  // Form handlers
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    
    // Handle numeric inputs
    if (name === 'currentQuantity' || name === 'minimumQuantity') {
      setFormData({
        ...formData,
        [name]: parseInt(value) || 0
      });
    } else {
      setFormData({
        ...formData,
        [name]: value
      });
    }
  };

  const resetForm = () => {
    setFormData({
      name: '',
      nsn: '',
      category: '',
      unit: '',
      currentQuantity: 0,
      minimumQuantity: 0,
      location: '',
    });
  };

  // Add new consumable
  const handleAddConsumable = async () => {
    try {
      const newItem: ConsumableItem = {
        ...formData,
        id: uuidv4(),
        lastRestockDate: format(new Date(), 'yyyy-MM-dd')
      };
      
      await saveConsumablesToDB([newItem]);
      
      setConsumables([...consumables, newItem]);
      setAddModalOpen(false);
      resetForm();
      
      toast({
        title: 'Success',
        description: `${newItem.name} added to consumables.`,
      });
    } catch (error) {
      console.error('Error adding consumable:', error);
      toast({
        title: 'Error',
        description: 'Failed to add consumable.',
        variant: 'destructive',
      });
    }
  };

  // Edit consumable
  const handleEditClick = (item: ConsumableItem) => {
    setEditingItem(item);
    setFormData({
      id: item.id,
      name: item.name,
      nsn: item.nsn || '',
      category: item.category,
      unit: item.unit,
      currentQuantity: item.currentQuantity,
      minimumQuantity: item.minimumQuantity,
      location: item.location || '',
      expirationDate: item.expirationDate,
      notes: item.notes
    });
  };

  const handleSaveEdit = async () => {
    if (!editingItem) return;
    
    try {
      const updatedItem: ConsumableItem = {
        ...editingItem,
        ...formData,
      };
      
      await saveConsumablesToDB([updatedItem]);
      
      setConsumables(consumables.map(item => 
        item.id === updatedItem.id ? updatedItem : item
      ));
      
      setEditingItem(null);
      resetForm();
      
      toast({
        title: 'Success',
        description: `${updatedItem.name} has been updated.`,
      });
    } catch (error) {
      console.error('Error updating consumable:', error);
      toast({
        title: 'Error',
        description: 'Failed to update consumable.',
        variant: 'destructive',
      });
    }
  };

  // Delete consumable
  const handleDeleteConsumable = async (item: ConsumableItem) => {
    if (!window.confirm(`Are you sure you want to delete ${item.name}?`)) return;
    
    try {
      await deleteConsumableFromDB(item.id);
      
      setConsumables(consumables.filter(c => c.id !== item.id));
      
      toast({
        title: 'Success',
        description: `${item.name} has been deleted.`,
      });
    } catch (error) {
      console.error('Error deleting consumable:', error);
      toast({
        title: 'Error',
        description: 'Failed to delete consumable.',
        variant: 'destructive',
      });
    }
  };

  // Consume item handlers
  const handleConsumeClick = (item: ConsumableItem) => {
    setConsumingItem(item);
    setConsumptionData({
      quantity: 1,
      issuedTo: '',
      issuedBy: '',
      notes: ''
    });
    setConsumeModalOpen(true);
  };

  const handleConsumptionInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    
    if (name === 'quantity') {
      setConsumptionData({
        ...consumptionData,
        quantity: parseInt(value) || 1
      });
    } else {
      setConsumptionData({
        ...consumptionData,
        [name]: value
      });
    }
  };

  const handleCompleteConsumption = async () => {
    if (!consumingItem) return;
    
    try {
      // Check if quantity is valid
      if (consumptionData.quantity <= 0) {
        toast({
          title: 'Invalid quantity',
          description: 'Please enter a positive quantity.',
          variant: 'destructive',
        });
        return;
      }
      
      // Check if there's enough quantity
      if (consumptionData.quantity > consumingItem.currentQuantity) {
        toast({
          title: 'Insufficient quantity',
          description: `Only ${consumingItem.currentQuantity} available.`,
          variant: 'destructive',
        });
        return;
      }
      
      // Update the item quantity
      const newQuantity = consumingItem.currentQuantity - consumptionData.quantity;
      const updatedItem = await updateConsumableQuantity(consumingItem.id, newQuantity);
      
      // Record consumption history
      const historyEntry: ConsumptionHistoryEntry = {
        id: uuidv4(),
        itemId: consumingItem.id,
        quantity: consumptionData.quantity,
        date: format(new Date(), 'yyyy-MM-dd'),
        issuedTo: consumptionData.issuedTo,
        issuedBy: consumptionData.issuedBy,
        notes: consumptionData.notes
      };
      
      await addConsumptionHistoryEntryToDB(historyEntry);
      
      // Update local state
      setConsumables(consumables.map(item => 
        item.id === consumingItem.id ? { ...item, currentQuantity: newQuantity } : item
      ));
      
      setConsumeModalOpen(false);
      setConsumingItem(null);
      
      toast({
        title: 'Success',
        description: `Consumed ${consumptionData.quantity} ${consumingItem.unit}(s) of ${consumingItem.name}.`,
      });
      
      // Show low stock warning if necessary
      if (newQuantity <= (updatedItem?.minimumQuantity || consumingItem.minimumQuantity)) {
        toast({
          title: 'Low Stock Warning',
          description: `${consumingItem.name} is now below minimum quantity.`,
          variant: 'destructive',
        });
      }
    } catch (error) {
      console.error('Error consuming item:', error);
      toast({
        title: 'Error',
        description: 'Failed to record consumption.',
        variant: 'destructive',
      });
    }
  };

  // Restock handlers
  const handleRestockClick = (item: ConsumableItem) => {
    setRestockingItem(item);
    setRestockQuantity(0);
    setRestockModalOpen(true);
  };

  const handleCompleteRestock = async () => {
    if (!restockingItem) return;
    
    try {
      // Check if quantity is valid
      if (restockQuantity <= 0) {
        toast({
          title: 'Invalid quantity',
          description: 'Please enter a positive quantity.',
          variant: 'destructive',
        });
        return;
      }
      
      // Update the item quantity
      const newQuantity = restockingItem.currentQuantity + restockQuantity;
      const updatedItem = {
        ...restockingItem,
        currentQuantity: newQuantity,
        lastRestockDate: format(new Date(), 'yyyy-MM-dd')
      };
      
      await saveConsumablesToDB([updatedItem]);
      
      // Update local state
      setConsumables(consumables.map(item => 
        item.id === restockingItem.id ? updatedItem : item
      ));
      
      setRestockModalOpen(false);
      setRestockingItem(null);
      
      toast({
        title: 'Success',
        description: `Restocked ${restockQuantity} ${restockingItem.unit}(s) of ${restockingItem.name}.`,
      });
    } catch (error) {
      console.error('Error restocking item:', error);
      toast({
        title: 'Error',
        description: 'Failed to restock item.',
        variant: 'destructive',
      });
    }
  };

  // History handlers
  const handleHistoryClick = async (item: ConsumableItem) => {
    try {
      setHistoryItem(item);
      
      // Load consumption history
      const history = await getConsumptionHistoryByItemFromDB(item.id);
      setConsumptionHistory(history.sort((a, b) => 
        new Date(b.date).getTime() - new Date(a.date).getTime()
      ));
      
      setHistoryModalOpen(true);
    } catch (error) {
      console.error('Error loading consumption history:', error);
      toast({
        title: 'Error',
        description: 'Failed to load consumption history.',
        variant: 'destructive',
      });
    }
  };

  return (
    <div className="space-y-6">
      {/* Dashboard / Summary */}
      <Card>
        <CardHeader>
          <CardTitle>Consumables Dashboard</CardTitle>
          <CardDescription>Overview of consumable supplies inventory</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
            <Card className="bg-muted/20">
              <CardContent className="p-4">
                <div className="flex justify-between items-center">
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Total Items</p>
                    <h3 className="text-2xl font-bold">{consumableStats.totalItems}</h3>
                  </div>
                  <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center">
                    <Package className="h-5 w-5 text-primary" />
                  </div>
                </div>
              </CardContent>
            </Card>
            
            <Card className="bg-muted/20">
              <CardContent className="p-4">
                <div className="flex justify-between items-center">
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Low Stock Items</p>
                    <h3 className="text-2xl font-bold">{consumableStats.lowStockCount}</h3>
                  </div>
                  <div className="h-10 w-10 rounded-full bg-amber-100 flex items-center justify-center">
                    <AlertTriangle className="h-5 w-5 text-amber-600" />
                  </div>
                </div>
                <Progress 
                  value={consumableStats.lowStockPercentage} 
                  className={`h-1 mt-2 ${consumableStats.lowStockPercentage > 20 ? "bg-amber-500" : "bg-green-500"}`}
                />
              </CardContent>
            </Card>
            
            <Card className="bg-muted/20">
              <CardContent className="p-4">
                <div className="flex justify-between items-center">
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Categories</p>
                    <h3 className="text-2xl font-bold">{consumableCategories.length}</h3>
                  </div>
                  <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center">
                    <Archive className="h-5 w-5 text-primary" />
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
          
          {/* Low stock alerts */}
          {consumableStats.lowStockCount > 0 && (
            <Alert 
              variant="destructive" 
              className="mb-4 bg-amber-50 dark:bg-amber-950/10 border-amber-300 dark:border-amber-800"
            >
              <AlertTriangle className="h-4 w-4 text-amber-600 dark:text-amber-500" />
              <AlertTitle className="text-amber-800 dark:text-amber-500">
                Low Stock Warning
              </AlertTitle>
              <AlertDescription className="text-amber-800 dark:text-amber-500">
                {consumableStats.lowStockCount} items are below minimum quantity and need to be restocked.
              </AlertDescription>
            </Alert>
          )}
        </CardContent>
      </Card>

      {/* Main consumables management card */}
      <Card>
        <CardHeader>
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div>
              <CardTitle>Consumables Management</CardTitle>
              <CardDescription>Manage inventory of consumable items</CardDescription>
            </div>
            <Button onClick={() => {
              resetForm();
              setAddModalOpen(true);
            }}>
              <Plus className="h-4 w-4 mr-2" />
              Add Consumable
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          {/* Search and filters */}
          <div className="flex flex-col md:flex-row gap-4 mb-6">
            <div className="relative flex-1">
              <Input
                placeholder="Search by name, NSN, or location"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-10"
              />
              <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
            </div>
            
            <Select value={categoryFilter} onValueChange={setCategoryFilter}>
              <SelectTrigger className="w-full md:w-[180px]">
                <SelectValue placeholder="Category" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Categories</SelectItem>
                {consumableCategories.map(category => (
                  <SelectItem key={category.id} value={category.name}>
                    {category.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            
            <Select value={quantityFilter} onValueChange={setQuantityFilter}>
              <SelectTrigger className="w-full md:w-[150px]">
                <SelectValue placeholder="Stock Level" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Levels</SelectItem>
                <SelectItem value="low">Low Stock</SelectItem>
                <SelectItem value="ok">Adequate Stock</SelectItem>
              </SelectContent>
            </Select>
          </div>
          
          {/* Table */}
          {loading ? (
            <div className="flex justify-center items-center py-8">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          ) : filteredConsumables.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              <Package className="h-12 w-12 mx-auto mb-4 opacity-20" />
              <p>No consumable items found.</p>
              <p className="text-sm mt-1">Try adjusting your filters or add a new consumable.</p>
            </div>
          ) : (
            <div className="border rounded-md">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Category</TableHead>
                    <TableHead className="hidden md:table-cell">Location</TableHead>
                    <TableHead className="text-right">Quantity</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredConsumables.map(item => (
                    <TableRow key={item.id}>
                      <TableCell>
                        <div className="font-medium">{item.name}</div>
                        <div className="text-xs text-muted-foreground mt-1">{item.nsn ? `NSN: ${item.nsn}` : ''}</div>
                      </TableCell>
                      <TableCell>{item.category}</TableCell>
                      <TableCell className="hidden md:table-cell">{item.location || '-'}</TableCell>
                      <TableCell className="text-right">
                        <div className="font-medium">{item.currentQuantity} {item.unit}</div>
                        <div className="text-xs text-muted-foreground mt-1">Min: {item.minimumQuantity}</div>
                      </TableCell>
                      <TableCell>
                        {item.currentQuantity <= 0 ? (
                          <Badge variant="destructive">Out of Stock</Badge>
                        ) : item.currentQuantity <= item.minimumQuantity ? (
                          <Badge 
                            variant="outline" 
                            className="text-amber-600 border-amber-400 dark:text-amber-400 dark:border-amber-600"
                          >
                            Low Stock
                          </Badge>
                        ) : (
                          <Badge 
                            variant="outline" 
                            className="text-green-600 border-green-400 dark:text-green-400 dark:border-green-600"
                          >
                            In Stock
                          </Badge>
                        )}
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex items-center justify-end space-x-1">
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => handleConsumeClick(item)}
                            disabled={item.currentQuantity <= 0}
                          >
                            <ShoppingCart className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => handleRestockClick(item)}
                          >
                            <Truck className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => handleHistoryClick(item)}
                          >
                            <History className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => handleEditClick(item)}
                          >
                            <Edit className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => handleDeleteConsumable(item)}
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
        <CardFooter className="justify-between border-t px-6 py-3">
          <div className="text-sm text-muted-foreground">
            Showing {filteredConsumables.length} of {consumables.length} items
          </div>
        </CardFooter>
      </Card>

      {/* Add/Edit Consumable Modal */}
      <Dialog open={addModalOpen || !!editingItem} onOpenChange={(open) => {
        if (!open) {
          setAddModalOpen(false);
          setEditingItem(null);
          resetForm();
        }
      }}>
        <DialogContent className="sm:max-w-[600px]">
          <DialogHeader>
            <DialogTitle>
              {editingItem ? `Edit ${editingItem.name}` : 'Add New Consumable'}
            </DialogTitle>
            <DialogDescription>
              {editingItem 
                ? 'Update the consumable item details below.'
                : 'Enter the details for the new consumable item.'}
            </DialogDescription>
          </DialogHeader>
          
          <div className="grid gap-4 py-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="name">Item Name</Label>
                <Input
                  id="name"
                  name="name"
                  value={formData.name}
                  onChange={handleInputChange}
                  placeholder="e.g., AA Batteries"
                />
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="nsn">NSN (Optional)</Label>
                <Input
                  id="nsn"
                  name="nsn"
                  value={formData.nsn}
                  onChange={handleInputChange}
                  placeholder="e.g., 6135-01-351-1131"
                />
              </div>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="category">Category</Label>
                <Select
                  value={formData.category}
                  onValueChange={(value) => setFormData({...formData, category: value})}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select a category" />
                  </SelectTrigger>
                  <SelectContent>
                    {consumableCategories.map(category => (
                      <SelectItem key={category.id} value={category.name}>
                        {category.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="unit">Unit of Measure</Label>
                <Select
                  value={formData.unit}
                  onValueChange={(value) => setFormData({...formData, unit: value})}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select a unit" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="each">Each</SelectItem>
                    <SelectItem value="box">Box</SelectItem>
                    <SelectItem value="pack">Pack</SelectItem>
                    <SelectItem value="roll">Roll</SelectItem>
                    <SelectItem value="pair">Pair</SelectItem>
                    <SelectItem value="set">Set</SelectItem>
                    <SelectItem value="bag">Bag</SelectItem>
                    <SelectItem value="can">Can</SelectItem>
                    <SelectItem value="bottle">Bottle</SelectItem>
                    <SelectItem value="gallon">Gallon</SelectItem>
                    <SelectItem value="quart">Quart</SelectItem>
                    <SelectItem value="ounce">Ounce</SelectItem>
                    <SelectItem value="pound">Pound</SelectItem>
                    <SelectItem value="ream">Ream</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="currentQuantity">Current Quantity</Label>
                <Input
                  id="currentQuantity"
                  name="currentQuantity"
                  type="number"
                  min="0"
                  value={formData.currentQuantity}
                  onChange={handleInputChange}
                />
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="minimumQuantity">Minimum Quantity</Label>
                <Input
                  id="minimumQuantity"
                  name="minimumQuantity"
                  type="number"
                  min="0"
                  value={formData.minimumQuantity}
                  onChange={handleInputChange}
                />
              </div>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="location">Storage Location</Label>
                <Input
                  id="location"
                  name="location"
                  value={formData.location}
                  onChange={handleInputChange}
                  placeholder="e.g., Supply Room B3"
                />
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="expirationDate">Expiration Date (Optional)</Label>
                <Input
                  id="expirationDate"
                  name="expirationDate"
                  type="date"
                  value={formData.expirationDate || ''}
                  onChange={handleInputChange}
                />
              </div>
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="notes">Notes (Optional)</Label>
              <Textarea
                id="notes"
                name="notes"
                value={formData.notes || ''}
                onChange={handleInputChange}
                placeholder="Additional information about this item"
                rows={3}
              />
            </div>
          </div>
          
          <DialogFooter>
            <Button variant="outline" onClick={() => {
              setAddModalOpen(false);
              setEditingItem(null);
              resetForm();
            }}>
              Cancel
            </Button>
            <Button onClick={editingItem ? handleSaveEdit : handleAddConsumable}>
              {editingItem ? 'Save Changes' : 'Add Consumable'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Consume Item Modal */}
      <Dialog open={consumeModalOpen} onOpenChange={setConsumeModalOpen}>
        <DialogContent className="sm:max-w-[500px]">
          <DialogHeader>
            <DialogTitle>Consume Item</DialogTitle>
            <DialogDescription>
              Record consumption of {consumingItem?.name}
            </DialogDescription>
          </DialogHeader>
          
          {consumingItem && (
            <div className="grid gap-4 py-4">
              <div className="bg-muted/30 p-3 rounded-md">
                <div className="flex justify-between mb-1">
                  <span className="font-medium">{consumingItem.name}</span>
                  <Badge>
                    {consumingItem.currentQuantity} {consumingItem.unit}(s) available
                  </Badge>
                </div>
                <div className="text-sm text-muted-foreground">
                  Location: {consumingItem.location || 'Not specified'}
                </div>
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="quantity">Quantity to Consume</Label>
                <Input
                  id="quantity"
                  name="quantity"
                  type="number"
                  min="1"
                  max={consumingItem.currentQuantity}
                  value={consumptionData.quantity}
                  onChange={handleConsumptionInputChange}
                />
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="issuedTo">Issued To</Label>
                  <Input
                    id="issuedTo"
                    name="issuedTo"
                    value={consumptionData.issuedTo}
                    onChange={handleConsumptionInputChange}
                    placeholder="Person or unit receiving"
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="issuedBy">Issued By</Label>
                  <Input
                    id="issuedBy"
                    name="issuedBy"
                    value={consumptionData.issuedBy}
                    onChange={handleConsumptionInputChange}
                    placeholder="Person issuing items"
                  />
                </div>
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="notes">Notes (Optional)</Label>
                <Textarea
                  id="notes"
                  name="notes"
                  value={consumptionData.notes}
                  onChange={handleConsumptionInputChange}
                  placeholder="Purpose or additional details"
                  rows={3}
                />
              </div>
            </div>
          )}
          
          <DialogFooter>
            <Button variant="outline" onClick={() => setConsumeModalOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleCompleteConsumption}>
              Confirm Consumption
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Restock Item Modal */}
      <Dialog open={restockModalOpen} onOpenChange={setRestockModalOpen}>
        <DialogContent className="sm:max-w-[500px]">
          <DialogHeader>
            <DialogTitle>Restock Item</DialogTitle>
            <DialogDescription>
              Add inventory to {restockingItem?.name}
            </DialogDescription>
          </DialogHeader>
          
          {restockingItem && (
            <div className="grid gap-4 py-4">
              <div className="bg-muted/30 p-3 rounded-md">
                <div className="flex justify-between mb-1">
                  <span className="font-medium">{restockingItem.name}</span>
                  <Badge>
                    Current: {restockingItem.currentQuantity} {restockingItem.unit}(s)
                  </Badge>
                </div>
                <div className="text-sm text-muted-foreground">
                  Location: {restockingItem.location || 'Not specified'}
                </div>
                <div className="text-sm text-muted-foreground">
                  Last restocked: {restockingItem.lastRestockDate || 'Unknown'}
                </div>
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="restockQuantity">Quantity to Add</Label>
                <Input
                  id="restockQuantity"
                  name="restockQuantity"
                  type="number"
                  min="1"
                  value={restockQuantity}
                  onChange={(e) => setRestockQuantity(parseInt(e.target.value) || 0)}
                />
              </div>
              
              <div className="bg-muted/30 p-3 rounded-md">
                <div className="flex justify-between items-center">
                  <span className="font-medium">New Total:</span>
                  <span className="font-medium">
                    {restockingItem.currentQuantity + restockQuantity} {restockingItem.unit}(s)
                  </span>
                </div>
              </div>
            </div>
          )}
          
          <DialogFooter>
            <Button variant="outline" onClick={() => setRestockModalOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleCompleteRestock}>
              Confirm Restock
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* History Modal */}
      <Dialog open={historyModalOpen} onOpenChange={setHistoryModalOpen}>
        <DialogContent className="sm:max-w-[600px]">
          <DialogHeader>
            <DialogTitle>Consumption History</DialogTitle>
            <DialogDescription>
              History for {historyItem?.name}
            </DialogDescription>
          </DialogHeader>
          
          {historyItem && (
            <div className="py-4">
              {consumptionHistory.length === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  <History className="h-12 w-12 mx-auto mb-4 opacity-20" />
                  <p>No consumption history found.</p>
                </div>
              ) : (
                <div className="max-h-[60vh] overflow-y-auto">
                  <div className="space-y-4">
                    {consumptionHistory.map(entry => (
                      <div key={entry.id} className="border rounded-md p-3">
                        <div className="flex justify-between mb-2">
                          <Badge variant="outline">
                            {entry.quantity} {historyItem.unit}(s)
                          </Badge>
                          <span className="text-sm text-muted-foreground">
                            {entry.date}
                          </span>
                        </div>
                        
                        <div className="text-sm grid grid-cols-1 md:grid-cols-2 gap-1">
                          {entry.issuedTo && (
                            <div><span className="font-medium">Issued To:</span> {entry.issuedTo}</div>
                          )}
                          {entry.issuedBy && (
                            <div><span className="font-medium">Issued By:</span> {entry.issuedBy}</div>
                          )}
                        </div>
                        
                        {entry.notes && (
                          <div className="mt-2 text-sm">
                            <span className="font-medium">Notes:</span>
                            <p className="text-muted-foreground mt-1">{entry.notes}</p>
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
          
          <DialogFooter>
            <Button onClick={() => setHistoryModalOpen(false)}>
              Close
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default ConsumablesManager; 