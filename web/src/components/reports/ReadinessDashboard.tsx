import React, { useState, useEffect, useMemo } from 'react';
import { getInventoryItemsFromDB } from '@/lib/idb';
import { InventoryItem } from '@/types';
import { ReadinessReport, ReadinessCategory } from '@/types/reporting';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Skeleton } from '@/components/ui/skeleton';
import { Button } from '@/components/ui/button';
import { AlertCircle, CheckCircle, Wrench } from 'lucide-react';

// Helper function to categorize items (can be moved to utils later)
const getItemCategory = (item: InventoryItem): string => {
  const nameLC = item.name.toLowerCase();
  if (nameLC.includes("helmet") || nameLC.includes("vest") || nameLC.includes("boots")) return "Protective";
  if (nameLC.includes("knife") || nameLC.includes("carbine") || nameLC.includes("m4") || nameLC.includes("pistol")) return "Weapon";
  if (nameLC.includes("radio") || nameLC.includes("comm")) return "Communication";
  if (nameLC.includes("goggles") || nameLC.includes("optic") || nameLC.includes("peq")) return "Optics";
  if (nameLC.includes("medical") || nameLC.includes("ifak")) return "Medical";
  if (nameLC.includes("backpack") || nameLC.includes("pack") || nameLC.includes("rucksack") || nameLC.includes("molle")) return "Gear";
  if (nameLC.includes("vehicle") || nameLC.includes("hmmwv") || nameLC.includes("jltv")) return "Vehicle";
  return "Other";
};

const ReadinessDashboard: React.FC = () => {
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadData = async () => {
      setIsLoading(true);
      setError(null);
      try {
        const items = await getInventoryItemsFromDB();
        setInventory(items);
      } catch (err) {
        console.error("Failed to load inventory for readiness report:", err);
        setError("Failed to load inventory data.");
      } finally {
        setIsLoading(false);
      }
    };
    loadData();
  }, []);

  // Calculate Readiness Report
  const readinessReport = useMemo<ReadinessReport | null>(() => {
    if (inventory.length === 0) return null;

    const categoriesMap = new Map<string, { total: number; operational: number }>();
    let totalOperational = 0;
    const itemsNeedingAttention: InventoryItem[] = [];

    inventory.forEach(item => {
      const categoryName = getItemCategory(item);
      const category = categoriesMap.get(categoryName) || { total: 0, operational: 0 };
      
      category.total += 1;
      // Define operational status (e.g., 'active' means operational)
      // You might refine this based on maintenance status, components missing etc. later
      const isOperational = item.status === 'active'; 
      
      if (isOperational) {
        category.operational += 1;
        totalOperational += 1;
      } else {
         itemsNeedingAttention.push(item);
      }
      
      categoriesMap.set(categoryName, category);
    });

    const reportCategories: ReadinessCategory[] = [];
    categoriesMap.forEach((stats, name) => {
       const operationalPercentage = stats.total > 0 ? Math.round((stats.operational / stats.total) * 100) : 0;
       reportCategories.push({
         name,
         totalItems: stats.total,
         fullyOperational: stats.operational, // Simplified: assume active = fully op
         partiallyOperational: 0, // Placeholder
         nonOperational: stats.total - stats.operational, // Simplified
         operationalPercentage,
       });
    });

    const overallPercentage = inventory.length > 0 ? Math.round((totalOperational / inventory.length) * 100) : 0;

    return {
      generatedAt: new Date().toISOString(),
      overallPercentage,
      categories: reportCategories.sort((a, b) => a.name.localeCompare(b.name)),
      itemsNeedingAttention,
    };
  }, [inventory]);

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <Skeleton className="h-6 w-3/4" />
          <Skeleton className="h-4 w-1/2 mt-1" />
        </CardHeader>
        <CardContent className="space-y-4">
          <Skeleton className="h-8 w-full" />
          <Skeleton className="h-20 w-full" />
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return <div className="p-4 text-center text-red-600">Error: {error}</div>;
  }

  if (!readinessReport) {
     return <div className="p-4 text-center text-muted-foreground">No inventory data found to generate report.</div>;
  }

  return (
    <div className="space-y-6">
       <Card>
         <CardHeader>
            <CardTitle>Overall Readiness</CardTitle>
             <CardDescription>
               Calculated based on current item statuses at {new Date(readinessReport.generatedAt).toLocaleString()}.
             </CardDescription>
         </CardHeader>
         <CardContent className="flex items-center justify-center p-6">
            {/* Basic Percentage Display - Consider adding a gauge chart later */}
            <div className="text-6xl font-bold text-green-600">
               {readinessReport.overallPercentage}%
            </div>
         </CardContent>
       </Card>

       <Card>
         <CardHeader>
            <CardTitle>Readiness by Category</CardTitle>
         </CardHeader>
         <CardContent>
           <Table>
             <TableHeader>
               <TableRow>
                 <TableHead>Category</TableHead>
                 <TableHead className="text-right">Total Items</TableHead>
                 <TableHead className="text-right">Operational</TableHead>
                 <TableHead className="text-right">Non-Operational</TableHead>
                 <TableHead className="text-right">Readiness (%)</TableHead>
               </TableRow>
             </TableHeader>
             <TableBody>
               {readinessReport.categories.map(cat => (
                 <TableRow key={cat.name}>
                   <TableCell className="font-medium">{cat.name}</TableCell>
                   <TableCell className="text-right">{cat.totalItems}</TableCell>
                   <TableCell className="text-right text-green-600">{cat.fullyOperational}</TableCell>
                   <TableCell className="text-right text-red-600">{cat.nonOperational}</TableCell>
                   <TableCell className="text-right font-semibold">{cat.operationalPercentage}%</TableCell>
                 </TableRow>
               ))}
             </TableBody>
           </Table>
         </CardContent>
       </Card>
       
       {readinessReport.itemsNeedingAttention.length > 0 && (
         <Card>
           <CardHeader>
              <CardTitle className="text-destructive">Items Needing Attention</CardTitle>
              <CardDescription>Items currently marked as non-operational (Pending, Transferred, etc.).</CardDescription>
           </CardHeader>
           <CardContent>
             <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Serial Number</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Actions</TableHead> 
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {readinessReport.itemsNeedingAttention.map(item => (
                     <TableRow key={item.id}>
                        <TableCell className="font-medium">{item.name}</TableCell>
                        <TableCell className="font-mono text-xs">{item.serialNumber}</TableCell>
                        <TableCell>
                           <span className={`px-2 py-0.5 text-xs rounded ${item.status === 'pending' ? 'bg-amber-100 text-amber-800' : 'bg-blue-100 text-blue-800'}`}>
                              {item.status}
                           </span>
                        </TableCell>
                        <TableCell className="text-right">
                           {/* Add link to item page? */}
                           <Button variant="ghost" size="sm" onClick={() => { /* Navigate to item? */ }}>View</Button>
                        </TableCell>
                     </TableRow>
                  ))}
                </TableBody>
             </Table>
           </CardContent>
         </Card>
       )}
    </div>
  );
};

export default ReadinessDashboard; 