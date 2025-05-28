import React from 'react';
import { Button } from "@/components/ui/button";
import { MaintenanceItem } from "@/lib/maintenanceData";
import { MaintenanceStatusBadge, MaintenancePriorityBadge } from './MaintenanceBadges';
import { Play, Radio, Sword } from '@/components/ui/custom-icons';
import { Tag, Calendar, User, CheckCircle } from 'lucide-react';
import { format } from "date-fns";

// Props interface for the component
interface MaintenanceItemRowProps {
  item: MaintenanceItem;
  onViewDetails: (item: MaintenanceItem) => void;
  onStartMaintenance: (item: MaintenanceItem) => void;
  onCompleteMaintenance: (item: MaintenanceItem) => void;
}

export const MaintenanceItemRow: React.FC<MaintenanceItemRowProps> = ({
  item,
  onViewDetails,
  onStartMaintenance,
  onCompleteMaintenance
}) => {
  // Format date to military style (DDMMMYYYY)
  const formatMilitaryDate = (dateString: string) => {
    if (!dateString) return "N/A";
    
    try {
      const date = new Date(dateString);
      // Format as DDMMMYYYY with month in uppercase
      return format(date, 'ddMMMyyyy').toUpperCase();
    } catch (e) {
      return dateString;
    }
  };

  return (
    <div className="py-4 px-6 hover:bg-muted/30 transition-colors">
      <div className="grid grid-cols-[2fr_1fr_1fr_1fr_180px] gap-4 items-center">
        {/* Column 1: Item Name and Description */}
        <div className="flex flex-col min-w-0">
          <h4 className="font-medium truncate" title={item.itemName}>{item.itemName}</h4>
          <div className="flex items-center text-xs text-muted-foreground mt-0.5">
            <Tag className="h-3 w-3 mr-1.5 inline flex-shrink-0" />
            <span className="truncate" title={item.serialNumber}>{item.serialNumber}</span>
          </div>
          <p className="text-xs mt-1.5 text-muted-foreground line-clamp-1">{item.description}</p>
        </div>
        
        {/* Column 2: Status */}
        <div>
          <MaintenanceStatusBadge status={item.status} />
        </div>
        
        {/* Column 3: Priority */}
        <div>
          <MaintenancePriorityBadge priority={item.priority} />
        </div>
        
        {/* Column 4: Date Info */}
        <div className="flex flex-col text-xs">
          <div className="flex items-center">
            <Calendar className="h-3 w-3 mr-1.5 text-muted-foreground" />
            <span>{formatMilitaryDate(item.reportedDate)}</span>
          </div>
          <div className="flex items-center mt-1.5">
            <User className="h-3 w-3 mr-1.5 text-muted-foreground" />
            <span className="truncate" title={item.assignedTo || "Unassigned"}>{item.assignedTo || "Unassigned"}</span>
          </div>
        </div>
        
        {/* Column 5: Actions */}
        <div className="flex items-center justify-end gap-2">
          <Button
            variant="outline" 
            size="sm"
            onClick={() => onViewDetails(item)}
            className="h-8 w-[80px] rounded-none bg-transparent text-white border border-white text-xs flex items-center justify-center"
          >
            Details
          </Button>

          {item.status === 'scheduled' && (
            <Button
              size="sm"
              variant="default"
              className="h-8 w-[80px] rounded-none bg-blue-600 hover:bg-blue-700 text-white text-xs flex items-center justify-center"
              onClick={() => onStartMaintenance(item)}
            >
              Start
            </Button>
          )}

          {item.status === 'in-progress' && (
            <Button
              size="sm"
              variant="default"
              className="h-8 w-[90px] rounded-none bg-blue-600 hover:bg-blue-700 text-white text-xs flex items-center justify-center"
              onClick={() => onCompleteMaintenance(item)}
            >
              Complete
            </Button>
          )}
        </div>
      </div>
    </div>
  );
};
