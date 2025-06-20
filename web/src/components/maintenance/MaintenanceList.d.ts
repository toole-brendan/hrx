import React from 'react';
import { MaintenanceItem } from "@/lib/maintenanceData";
interface MaintenanceListProps {
    items: MaintenanceItem[];
    searchTerm: string;
    setSearchTerm: (term: string) => void;
    filterCategory: string;
    setFilterCategory: (category: string) => void;
    filterStatus: string;
    setFilterStatus: (status: string) => void;
    filterPriority: string;
    setFilterPriority: (priority: string) => void;
    onViewDetails: (item: MaintenanceItem) => void;
    onStartMaintenance: (item: MaintenanceItem) => void;
    onCompleteMaintenance: (item: MaintenanceItem) => void;
    onResetFilters: () => void;
    sortConfig: {
        field: keyof MaintenanceItem | 'none';
        order: 'asc' | 'desc';
    };
    onSort: (field: keyof MaintenanceItem | 'none') => void;
}
export declare const MaintenanceList: React.FC<MaintenanceListProps>;
export {};
