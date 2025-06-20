import React from 'react';
interface MaintenanceStatusBadgeProps {
    status: string;
    size?: 'default' | 'sm' | 'lg';
}
export declare const MaintenanceStatusBadge: React.FC<MaintenanceStatusBadgeProps>;
interface MaintenancePriorityBadgeProps {
    priority: string;
    size?: 'default' | 'sm' | 'lg';
}
export declare const MaintenancePriorityBadge: React.FC<MaintenancePriorityBadgeProps>;
export {};
