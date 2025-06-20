import React from 'react';
interface StatusBadgeProps {
    status: 'operational' | 'maintenance' | 'non-operational' | 'pending' | 'approved' | 'rejected' | 'in-transit' | 'delivered' | 'completed' | 'cancelled';
    className?: string;
    size?: 'sm' | 'md' | 'lg';
}
export declare const StatusBadge: React.FC<StatusBadgeProps>;
export {};
