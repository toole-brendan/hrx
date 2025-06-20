import React from 'react';
interface StatusBadgeProps {
    status: "pending" | "approved" | "rejected" | "active" | "transferred";
    className?: string;
}
declare const StatusBadge: React.FC<StatusBadgeProps>;
export default StatusBadge;
