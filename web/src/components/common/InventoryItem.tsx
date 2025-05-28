import { useToast } from "@/hooks/use-toast";
import { InventoryItem as InventoryItemType } from "@/types";
import { Package, ArrowRightLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

interface InventoryItemProps {
  item: InventoryItemType;
}

const InventoryItem: React.FC<InventoryItemProps> = ({ item }) => {
  const { toast } = useToast();

  const handleTransferRequest = () => {
    toast({
      title: "Transfer Initiated",
      description: `Transfer request initiated for ${item.name}`,
    });
  };

  return (
    <div className="py-3 hover:bg-gray-50 dark:hover:bg-white/5 flex items-center justify-between">
      <div className="flex items-center">
        <div className="h-8 w-8 bg-purple-50 dark:bg-purple-500/10 rounded-full flex items-center justify-center text-purple-500">
          <Package className="h-4 w-4" />
        </div>
        <div className="ml-3">
          <div className="flex items-center gap-2">
            <h4 className="font-medium text-sm text-gray-900 dark:text-gray-100">{item.name}</h4>
            <Badge 
              variant="outline" 
              className={`text-[10px] uppercase tracking-wider rounded-none ${
                item.status === "active" 
                  ? "bg-green-50 text-green-600 dark:bg-green-900/30 dark:text-green-500 border border-green-200 dark:border-green-700/50" 
                  : item.status === "pending" 
                  ? "bg-amber-50 text-amber-600 dark:bg-amber-900/30 dark:text-amber-500 border border-amber-200 dark:border-amber-700/50"
                  : "bg-blue-50 text-blue-600 dark:bg-blue-900/30 dark:text-blue-500 border border-blue-200 dark:border-blue-700/50"
              }`}
            >
              {item.status}
            </Badge>
          </div>
          <p className="text-xs text-gray-500 dark:text-gray-400">SN: {item.serialNumber}</p>
        </div>
      </div>
      <Button 
        size="icon"
        variant="ghost"
        className="h-8 w-8 text-gray-400 hover:text-purple-600 hover:bg-purple-50 dark:hover:bg-purple-900/20 dark:text-gray-500 dark:hover:text-purple-400"
        onClick={handleTransferRequest}
      >
        <ArrowRightLeft className="h-4 w-4" />
      </Button>
    </div>
  );
};

export default InventoryItem;
