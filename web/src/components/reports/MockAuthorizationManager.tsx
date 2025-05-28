import React, { useState, useEffect, useCallback } from 'react';
import { AuthorizationData } from '@/types/reporting';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Textarea } from '@/components/ui/textarea';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useToast } from "@/hooks/use-toast";
import { Skeleton } from "@/components/ui/skeleton";

const LOCAL_STORAGE_KEY = 'handreceipt_mock_auth_data';

// Default mock data if nothing in localStorage
const defaultMockAuthData: AuthorizationData = {
  documentId: "MTOE 12345-ABC",
  documentDate: "2024-01-01",
  unitUIC: "WABCDE",
  lineItems: [
    { id: 'ACH-NSN', name: 'ACH Helmet', requiredQuantity: 150, category: 'Protective' },
    { id: 'MOLLE-NSN', name: 'MOLLE II Rucksack', requiredQuantity: 150, category: 'Gear' },
    { id: 'IFAK-NSN', name: 'IFAK', requiredQuantity: 160, category: 'Medical' },
    { id: 'IOTV-NSN', name: 'IOTV', requiredQuantity: 150, category: 'Protective' },
    { id: 'M4-NSN', name: 'M4 Carbine', requiredQuantity: 140, category: 'Weapon' },
    { id: 'PEQ15-NSN', name: 'PEQ-15', requiredQuantity: 140, category: 'Optics' },
  ],
};

// Helper to get data (could be moved to idb.ts or a dedicated store later)
export const getStoredAuthData = (): AuthorizationData => {
   try {
     const storedData = localStorage.getItem(LOCAL_STORAGE_KEY);
     return storedData ? JSON.parse(storedData) : defaultMockAuthData;
   } catch (error) {
     console.error("Failed to load auth data from localStorage:", error);
     localStorage.removeItem(LOCAL_STORAGE_KEY); // Clear corrupted data
     return defaultMockAuthData;
   }
}

const MockAuthorizationManager: React.FC = () => {
  const [authData, setAuthData] = useState<AuthorizationData>(defaultMockAuthData);
  const [jsonInput, setJsonInput] = useState<string>('');
  const [isLoading, setIsLoading] = useState(true);
  const { toast } = useToast();

  // Load data on mount
  useEffect(() => {
    const data = getStoredAuthData();
    setAuthData(data);
    setJsonInput(JSON.stringify(data, null, 2)); // Prettify JSON for display
    setIsLoading(false);
  }, []);

  const handleJsonInputChange = (event: React.ChangeEvent<HTMLTextAreaElement>) => {
    setJsonInput(event.target.value);
  };

  const handleSaveChanges = () => {
    try {
      const parsedData: AuthorizationData = JSON.parse(jsonInput);
      // Basic validation (check for required top-level fields)
      if (!parsedData.documentId || !parsedData.documentDate || !parsedData.unitUIC || !Array.isArray(parsedData.lineItems)) {
         throw new Error("Invalid JSON structure. Missing required fields.");
      }
      // TODO: Add more detailed validation for lineItems if needed
      
      localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(parsedData));
      setAuthData(parsedData);
      toast({ title: "Success", description: "Mock authorization data saved successfully." });
    } catch (error) {
      console.error("Failed to parse or save JSON:", error);
      let message = "Failed to save data.";
      if (error instanceof Error) {
         message = error.message;
      }
      toast({ title: "Error Saving Data", description: message, variant: "destructive" });
    }
  };

  if (isLoading) {
     return <Skeleton className="h-60 w-full" />;
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Manage Mock Authorization Data (MTOE/TDA)</CardTitle>
        <CardDescription>
          View or update the mock authorization data used for shortage calculations. Edit the JSON directly and save.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
         <div className="grid grid-cols-3 gap-4 text-sm">
            <div><span className="font-medium">Document ID:</span> {authData.documentId}</div>
            <div><span className="font-medium">Date:</span> {authData.documentDate}</div>
            <div><span className="font-medium">Unit UIC:</span> {authData.unitUIC}</div>
         </div>
         <div>
           <label htmlFor="auth-json" className="block text-sm font-medium mb-1">Authorization Data JSON:</label>
           <Textarea
             id="auth-json"
             value={jsonInput}
             onChange={handleJsonInputChange}
             rows={15}
             className="font-mono text-xs bg-muted/40 dark:bg-black"
             placeholder="Enter or paste AuthorizationData JSON here..."
           />
         </div>
         <Button 
           variant="blue"
           size="sm"
           className="h-9 px-3 flex items-center gap-1.5 text-xs uppercase tracking-wider"
           onClick={handleSaveChanges}
         >
           SAVE CHANGES
         </Button>
      </CardContent>
    </Card>
  );
};

export default MockAuthorizationManager; 