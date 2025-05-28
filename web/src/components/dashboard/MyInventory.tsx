import { useState } from "react";
import { inventory } from "@/lib/mockData";
import InventoryItem from "../common/InventoryItem";
import { Search } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useLocation } from "wouter";

const MyInventory: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState("");
  const [, navigate] = useLocation();
  
  const filteredInventory = inventory.filter(item => 
    item.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    item.serialNumber.toLowerCase().includes(searchTerm.toLowerCase())
  ).slice(0, 3); // Only show 3 items on dashboard
  
  return (
    <Card className="overflow-hidden border-border shadow-none bg-card">
      <div className="p-4 flex justify-between items-baseline">
        <div>
          <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
            INVENTORY PREVIEW
          </div>
          <div className="text-lg font-normal">
            Recent items
          </div>
        </div>
        
        <Button 
          variant="ghost" 
          className="text-xs uppercase tracking-wider text-blue-600 dark:text-blue-400 hover:bg-transparent hover:text-blue-800 dark:hover:text-blue-300"
          onClick={() => navigate("/property-book")}
        >
          VIEW ALL
        </Button>
      </div>
      
      <CardContent className="p-0">
        <div className="px-4 pb-3">
          <div className="relative">
            <Search className="absolute left-2 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input 
              placeholder="Search inventory" 
              className="w-full pl-8 bg-background border-border h-9 rounded-none"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>
        
        <div className="divide-y divide-border px-4 pb-2">
          {filteredInventory.length === 0 ? (
            <div className="p-2 text-center text-muted-foreground">
              No items found
            </div>
          ) : (
            filteredInventory.map((item) => (
              <InventoryItem key={item.id} item={item} />
            ))
          )}
        </div>
      </CardContent>
    </Card>
  );
};

export default MyInventory;
