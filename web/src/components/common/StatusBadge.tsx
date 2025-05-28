import React from 'react';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

interface StatusBadgeProps {
  status: "pending" | "approved" | "rejected" | "active" | "transferred";
  className?: string;
}

const StatusBadge: React.FC<StatusBadgeProps> = ({ status, className }) => {
  const statusConfig = {
    pending: {
      label: 'Pending',
      classes: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-400'
    },
    approved: {
      label: 'Approved',
      classes: 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400'
    },
    rejected: {
      label: 'Rejected',
      classes: 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400'
    },
    active: {
      label: 'Active',
      classes: 'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400'
    },
    transferred: {
      label: 'Transferred',
      classes: 'bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-400'
    }
  };

  const config = statusConfig[status];

  return (
    <Badge 
      variant="outline"
      className={cn(config.classes, className)}
    >
      {config.label}
    </Badge>
  );
};

export default StatusBadge;