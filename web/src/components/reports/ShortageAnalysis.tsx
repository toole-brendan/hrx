import React, { useState, useEffect, useMemo } from 'react';
import { getInventoryItemsFromDB } from '@/lib/idb';
import { InventoryItem } from '@/types';
import { AuthorizationData, AuthorizationLineItem, ShortageReport, ShortageItem } from '@/types/reporting';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Skeleton } from '@/components/ui/skeleton';
import { Button } from '@/components/ui/button';
import { AlertTriangle, CheckCircle } from 'lucide-react';
// Import the shared function to get auth data
import { getStoredAuthData } from './MockAuthorizationManager';

const ShortageAnalysis: React.FC = () => {
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  const [authData, setAuthData] = useState<AuthorizationData | null>(null);
  const [isLoadingInventory, setIsLoadingInventory] = useState(true);
  const [isLoadingAuth, setIsLoadingAuth] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Load Inventory
  useEffect(() => {
    const loadInventory = async () => {
      setIsLoadingInventory(true);
      setError(null);
      try {
        const items = await getInventoryItemsFromDB();
        setInventory(items);
      } catch (err) { 
        console.error("Failed to load inventory for shortage report:", err);
        setError(prev => prev ? `${prev} & Inventory` : "Failed to load Inventory data.");
       } finally {
        setIsLoadingInventory(false);
      }
    };
    loadInventory();
  }, []);

  // Load Authorization Data using the imported function
  useEffect(() => {
      setIsLoadingAuth(true);
      try {
         // Use the imported helper function
         const data = getStoredAuthData();
         setAuthData(data);
      } catch(err) {
         console.error("Failed to load authorization data:", err);
         setError(prev => prev ? `${prev} & Authorization` : "Failed to load Authorization data.");
      } finally {
          setIsLoadingAuth(false);
      }
  }, []); // Re-run if needed based on updates from the manager? For now, runs once.

  // Calculate Shortage Report
  const shortageReport = useMemo<ShortageReport | null>(() => {
    if (!authData || inventory.length === 0) return null;

    const onHandCounts = new Map<string, number>();
    inventory.forEach(item => {
       // Basic matching logic: Use name similarity for mock data (NSN would be better)
       // This is highly dependent on how inventory items map to auth line items
       const itemNameLower = item.name.toLowerCase();
       const matchedAuthItem = authData.lineItems.find(line => line.name.toLowerCase().includes(itemNameLower));
       
       if (matchedAuthItem) {
          // Aggregate counts based on the matched Auth Item ID (e.g., NSN)
          const currentCount = onHandCounts.get(matchedAuthItem.id) || 0;
          // Assuming each inventory item represents quantity 1 for simplicity
          onHandCounts.set(matchedAuthItem.id, currentCount + 1); 
       }
    });

    const shortages: ShortageItem[] = [];
    authData.lineItems.forEach(lineItem => {
      const onHand = onHandCounts.get(lineItem.id) || 0;
      const shortage = lineItem.requiredQuantity - onHand;
      if (shortage > 0) {
        shortages.push({
          authItemId: lineItem.id,
          name: lineItem.name,
          requiredQuantity: lineItem.requiredQuantity,
          onHandQuantity: onHand,
          shortageQuantity: shortage,
        });
      }
    });

    return {
      generatedAt: new Date().toISOString(),
      authorizationDocId: authData.documentId,
      shortages: shortages.sort((a, b) => b.shortageQuantity - a.shortageQuantity), // Sort by most severe shortage
      totalShortages: shortages.reduce((sum, item) => sum + item.shortageQuantity, 0),
    };
  }, [inventory, authData]);

  const isLoading = isLoadingInventory || isLoadingAuth;

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <Skeleton className="h-6 w-3/4" />
          <Skeleton className="h-4 w-1/2 mt-1" />
        </CardHeader>
        <CardContent>
          <Skeleton className="h-40 w-full" />
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return <div className="p-4 text-center text-red-600">Error: {error}</div>;
  }

  if (!shortageReport) {
     return <div className="p-4 text-center text-muted-foreground">Could not generate shortage report. Check inventory and authorization data.</div>;
  }

  return (
    <div className="space-y-6">
       {/* TODO: Add UI for managing/selecting Auth Data later */} 
       
       <Card>
         <CardHeader>
            <CardTitle>Shortage Analysis</CardTitle>
             <CardDescription>
               Comparison between on-hand inventory and authorization document ({shortageReport.authorizationDocId}) as of {new Date(shortageReport.generatedAt).toLocaleString()}.
             </CardDescription>
         </CardHeader>
         <CardContent>
           {shortageReport.shortages.length === 0 ? (
             <div className="p-6 text-center text-green-600">
                <CheckCircle className="h-10 w-10 mx-auto mb-2" />
                <p className="font-medium">No shortages identified based on current data.</p>
             </div>
           ) : (
             <> 
               <div className="mb-4 p-4 border border-amber-200 dark:border-amber-900 bg-amber-50 dark:bg-amber-900/20 rounded-md text-amber-700 dark:text-amber-300">
                  <AlertTriangle className="h-5 w-5 inline-block mr-2"/>
                  Identified <span className="font-bold">{shortageReport.totalShortages}</span> total unit shortages across <span className="font-bold">{shortageReport.shortages.length}</span> line items.
               </div>
               <Table>
                 <TableHeader>
                   <TableRow>
                     <TableHead>Item Name</TableHead>
                     <TableHead>Auth ID / NSN</TableHead>
                     <TableHead className="text-right">Required</TableHead>
                     <TableHead className="text-right">On Hand</TableHead>
                     <TableHead className="text-right text-destructive">Shortage</TableHead>
                   </TableRow>
                 </TableHeader>
                 <TableBody>
                   {shortageReport.shortages.map(item => (
                     <TableRow key={item.authItemId}>
                       <TableCell className="font-medium">{item.name}</TableCell>
                       <TableCell className="font-mono text-xs">{item.authItemId}</TableCell>
                       <TableCell className="text-right">{item.requiredQuantity}</TableCell>
                       <TableCell className="text-right">{item.onHandQuantity}</TableCell>
                       <TableCell className="text-right font-bold text-destructive">{item.shortageQuantity}</TableCell>
                     </TableRow>
                   ))}
                 </TableBody>
               </Table>
             </>
           )}
         </CardContent>
       </Card>
    </div>
  );
};

export default ShortageAnalysis; 