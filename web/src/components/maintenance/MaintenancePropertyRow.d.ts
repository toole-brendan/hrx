import React from 'react';
import { MaintenanceItem } from "@/lib/maintenanceData";
interface MaintenancePropertyRowProps {
    item: MaintenanceItem;
    onViewDetails: (item: MaintenanceItem) => void;
    onStartMaintenance: (item: MaintenanceItem) => void;
    onCompleteMaintenance: (item: MaintenanceItem) => void;
}
export declare const MaintenancePropertyRow: React.FC<MaintenancePropertyRowProps>;
export {};
