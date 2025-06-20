import { useToast } from "@/hooks/use-toast";
import { Property as PropertyType } from "@/types";
import { Package, ArrowRightLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

interface PropertyProps {
  item: PropertyType;
}

const Property: React.FC<PropertyProps> = ({ item }) => {
  const { toast } = useToast();
  
  const handleTransferRequest = () => {
    toast({
      title: "Transfer Initiated",
      description: `Transfer request initiated for ${item.name}`,
    });
  };
  
  // Function to get badge styling based on status
  const getStatusBadgeClass = (status: PropertyType['status']) => {
    switch (status) {
      case 'Operational':
        return "bg-green-50 text-green-600 border border-green-200";
      case 'Deadline - Maintenance':
      case 'Deadline - Supply':
        return "bg-amber-50 text-amber-600 border border-amber-200";
      case 'Lost':
      case 'Non-Operational':
      case 'Damaged':
      case 'In Repair':
        return "bg-red-50 text-red-600 border border-red-200";
      default:
        return "bg-gray-50 text-gray-600 border border-gray-200";
    }
  };
  
  return (
    <div className="py-3 hover:bg-gray-50 flex items-center justify-between">
      <div className="flex items-center">
        <div className="h-8 w-8 bg-purple-50 rounded-full flex items-center justify-center text-purple-500">
          <Package className="h-4 w-4" />
        </div>
        <div className="ml-3">
          <div className="flex items-center gap-2">
            <h4 className="font-medium text-sm text-gray-900">{item.name}</h4>
            <Badge
              variant="outline"
              className={`text-[10px] uppercase tracking-wider rounded-none ${getStatusBadgeClass(item.status)}`}
            >
              {item.status}
            </Badge>
          </div>
          <p className="text-xs text-gray-500">SN: {item.serialNumber}</p>
        </div>
      </div>
      <Button
        size="icon"
        variant="ghost"
        className="h-8 w-8 text-gray-400 hover:text-purple-600 hover:bg-purple-50"
        onClick={handleTransferRequest}
      >
        <ArrowRightLeft className="h-4 w-4" />
      </Button>
    </div>
  );
};

export default Property;